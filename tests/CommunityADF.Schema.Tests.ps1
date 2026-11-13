#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    Validates that documents produced by CommunityADF conform to the official ADF JSON schema.

    Schema source: https://unpkg.com/@atlaskit/adf-schema@57.7.41/dist/json-schema/v1/full.json
    A copy is stored in tests/schema so the tests run offline and against a pinned version.

    Run with: Invoke-Pester ./tests -Output Detailed
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute( 'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Variables assigned in BeforeDiscovery are consumed by -ForEach.' )]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute( 'PSAvoidUsingCmdletAliases', '', Justification = 'Tests exercise the ADF* alias DSL, which is the documented usage.' )]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute( 'PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helpers only build in-memory objects.' )]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute( 'PSReviewUnusedParameter', '', Justification = 'Parameters are used inside nested scriptblocks.' )]
param()

BeforeDiscovery {
    Import-Module ( Join-Path $PSScriptRoot '..\src\CommunityADF\CommunityADF.psd1' ) -Force

    function Get-ParameterEnumName {
        param( [string] $Command, [string] $Parameter )
        [enum]::GetNames( ( Get-Command $Command ).Parameters[$Parameter].ParameterType )
    }

    $AlignValues            = Get-ParameterEnumName 'New-ADFParagraph'   'Align'
    $HeadingLevels          = Get-ParameterEnumName 'New-ADFHeading'     'Level'
    $PanelTypes             = Get-ParameterEnumName 'New-ADFPanel'       'Type'
    $TableLayouts           = Get-ParameterEnumName 'New-ADFTable'       'Layout'
    $TableDisplayModes      = Get-ParameterEnumName 'New-ADFTable'       'DisplayMode'
    $MediaSingleLayouts     = Get-ParameterEnumName 'New-ADFMediaSingle' 'Layout'
    $MediaTypes             = Get-ParameterEnumName 'New-ADFMedia'       'Type'
    $MentionAccessLevels    = Get-ParameterEnumName 'New-ADFMention'     'AccessLevel'
    $MentionUserTypes       = Get-ParameterEnumName 'New-ADFMention'     'UserType'
    $StatusColors           = Get-ParameterEnumName 'New-ADFStatus'      'Color'
    $ExampleScripts         = Get-ChildItem -Path ( Join-Path $PSScriptRoot '..\examples' ) -Filter '*.ps1' |
        ForEach-Object { @{ Name = $_.BaseName; Path = $_.FullName } }
    $SubsupTypes            = Get-ParameterEnumName 'New-ADFText'        'SubsupType'
    $AnnotationTypes        = Get-ParameterEnumName 'Add-ADFAnnotationMark' 'AnnotationType'
}

BeforeAll {
    Import-Module ( Join-Path $PSScriptRoot '..\src\CommunityADF\CommunityADF.psd1' ) -Force

    # The ADF schema declares draft-04, which Test-Json (JsonSchema.Net) does not support. The schema
    # does not use any draft-04-only keywords (e.g. boolean exclusiveMinimum), so declaring it as
    # draft-07 validates identically.
    $SchemaPath = Join-Path $PSScriptRoot 'schema\adf-schema-57.7.41-full.json'
    $script:AdfSchema = ( Get-Content -Path $SchemaPath -Raw ) -replace
        [regex]::Escape( 'http://json-schema.org/draft-04/schema#' ), 'http://json-schema.org/draft-07/schema#'

    function Test-ADFSchema {
        param( [Parameter( Mandatory )] [string] $Json )
        $IsValid = Test-Json -Json $Json -Schema $script:AdfSchema -ErrorAction SilentlyContinue
        [pscustomobject]@{
            IsValid = $IsValid
            Errors  = if ( $IsValid ) { @() } else { @( Get-ADFSchemaDiagnostic -Json $Json ) }
        }
    }

    # Test-Json reports no reasons for failures, and whole-document evaluation is dominated by noise
    # from anyOf branches for unrelated node types. Instead, each node/mark is validated against just
    # the definitions for its own "type", and the deepest failing nodes are reported. Uses the
    # JsonSchema.Net library that Test-Json loads. Best-effort only: never affects the verdict.
    function Get-ADFSchemaDiagnostic {
        param( [Parameter( Mandatory )] [string] $Json )
        try {
            if ( -not $script:AdfDefinitionsByType ) {
                $script:AdfSchemaTable = $script:AdfSchema | ConvertFrom-Json -AsHashtable -Depth 100
                $script:AdfDefinitionSchemas = @{}
                $script:AdfDefinitionsByType = @{}
                foreach ( $Name in $script:AdfSchemaTable.definitions.Keys ) {
                    foreach ( $Type in $script:AdfSchemaTable.definitions[$Name].properties.type.enum ) {
                        $script:AdfDefinitionsByType[$Type] += @( $Name )
                    }
                }
            }
            $Failures = [System.Collections.Generic.List[object]]::new()
            $null = Find-ADFSchemaFailure -Value ( $Json | ConvertFrom-Json -AsHashtable -Depth 100 ) -Location '' -IsNode $true -Failures $Failures
            if ( -not $Failures.Count ) {
                return '(every node is individually valid; check that each node type is allowed by its parent)'
            }
            foreach ( $Failure in $Failures ) {
                "{0} ({1}):" -f $( if ( $Failure.Location ) { $Failure.Location } else { '/' } ), $Failure.Type
                $Failure.Messages | ForEach-Object { "    $_" }
            }
        }
        catch {
            "(diagnostics unavailable: $($_.Exception.Message))"
        }
    }

    # Recursively finds nodes/marks that fail validation while all of their descendants pass.
    # Returns $true if a failure was recorded in the subtree.
    function Find-ADFSchemaFailure {
        param( $Value, [string] $Location, [bool] $IsNode, [System.Collections.Generic.List[object]] $Failures )
        $ChildFailed = $false
        if ( $Value -is [System.Collections.IDictionary] ) {
            foreach ( $Key in $Value.Keys ) {
                # Only members of "content" and "marks" are nodes; attrs may also have a "type" key.
                $ChildIsNode = $Key -in 'content', 'marks'
                if ( Find-ADFSchemaFailure -Value $Value[$Key] -Location "$Location/$Key" -IsNode $ChildIsNode -Failures $Failures ) { $ChildFailed = $true }
            }
            if ( $IsNode -and -not $ChildFailed ) {
                $Messages = Test-ADFSchemaNode -Node $Value
                if ( $null -ne $Messages ) {
                    $Failures.Add( [pscustomobject]@{ Location = $Location; Type = $Value['type']; Messages = $Messages } )
                    return $true
                }
            }
        }
        elseif ( $Value -is [System.Collections.IList] ) {
            for ( $i = 0; $i -lt $Value.Count; $i++ ) {
                if ( Find-ADFSchemaFailure -Value $Value[$i] -Location "$Location/$i" -IsNode $IsNode -Failures $Failures ) { $ChildFailed = $true }
            }
        }
        return $ChildFailed
    }

    # Returns $null if the node matches any definition for its type, otherwise the error messages
    # from the closest-matching definition.
    function Test-ADFSchemaNode {
        param( [System.Collections.IDictionary] $Node )
        $Definitions = $script:AdfDefinitionsByType[[string] $Node['type']]
        if ( -not $Definitions ) { return , @( "Unknown node or mark type '$($Node['type'])'." ) }

        $NodeJson = [System.Text.Json.Nodes.JsonNode]::Parse( ( $Node | ConvertTo-Json -Depth 100 -Compress ) )
        $Options = [Json.Schema.EvaluationOptions]::new()
        $Options.OutputFormat = [Json.Schema.OutputFormat]::List
        $Best = $null
        foreach ( $Definition in $Definitions ) {
            if ( -not $script:AdfDefinitionSchemas.ContainsKey( $Definition ) ) {
                $script:AdfSchemaTable['$ref'] = "#/definitions/$Definition"
                $script:AdfDefinitionSchemas[$Definition] = [Json.Schema.JsonSchema]::FromText( ( $script:AdfSchemaTable | ConvertTo-Json -Depth 100 -Compress ) )
            }
            $Result = $script:AdfDefinitionSchemas[$Definition].Evaluate( $NodeJson, $Options )
            if ( $Result.IsValid ) { return $null }

            $Messages = @(
                foreach ( $Detail in $Result.Details ) {
                    foreach ( $Message in $Detail.Errors.Values ) {
                        [pscustomobject]@{ Location = $Detail.InstanceLocation.ToString(); Message = $Message }
                    }
                }
            )
            # Prefer concrete messages over the generic ones emitted by additionalProperties: false.
            $Specific = @( $Messages | Where-Object Message -NotLike '*false schema*' )
            if ( $Specific ) { $Messages = $Specific }
            $Messages = @( $Messages | ForEach-Object { '{0}: {1}' -f $( if ( $_.Location ) { $_.Location } else { '/' } ), $_.Message } | Select-Object -Unique )
            if ( -not $Best -or $Messages.Count -lt $Best.Count ) { $Best = $Messages }
        }
        return , @( $Best | Select-Object -First 5 )
    }

    # Accepts an ADF node (serialized here) or an already-serialized JSON string.
    function Assert-ADFSchema {
        param( [Parameter( Mandatory, ValueFromPipeline )] $Document )
        process {
            $Json = if ( $Document -is [string] ) { $Document } else { $Document | ConvertTo-Json -Depth 100 }
            $Result = Test-ADFSchema -Json $Json
            $Result.IsValid | Should -BeTrue -Because ( "the output should conform to the ADF schema.`nErrors:`n{0}`nJSON:`n{1}" -f ( $Result.Errors -join "`n" ), $Json )
        }
    }

    # Wraps inline content in a minimal doc > paragraph so it can be validated at the document root.
    function New-InlineTestDoc {
        param( [Parameter( Mandatory, Position = 0 )] [scriptblock] $Content )
        ADFDoc { ADFParagraph $Content }
    }

    # Minimal valid media child for mediaSingle / mediaGroup.
    function New-TestMedia {
        ADFMedia -Id 'abc-123' -Type File -Collection 'test-collection'
    }
}

Describe 'Schema validator sanity checks' {

    It 'accepts a minimal valid document' {
        ( Test-ADFSchema -Json '{"version":1,"type":"doc","content":[]}' ).IsValid | Should -BeTrue
    }

    It 'rejects an unknown node type' {
        ( Test-ADFSchema -Json '{"version":1,"type":"doc","content":[{"type":"bogus"}]}' ).IsValid | Should -BeFalse
    }

    It 'rejects an invalid attribute value' {
        ( Test-ADFSchema -Json '{"version":1,"type":"doc","content":[{"type":"heading","attrs":{"level":7}}]}' ).IsValid | Should -BeFalse
    }
}

Describe 'Document node' {

    It 'empty doc conforms' {
        ADFDoc {} | Assert-ADFSchema
    }

    It 'doc with a single paragraph conforms' {
        ADFDoc { ADFParagraph { ADFText 'Hello' } } | Assert-ADFSchema
    }
}

Describe 'Block nodes' {

    Context 'paragraph' {

        It 'empty paragraph conforms' {
            ADFDoc { ADFParagraph } | Assert-ADFSchema
        }

        It 'paragraph with LocalId conforms' {
            ADFDoc { ADFParagraph -LocalId 'p-1' { ADFText 'x' } } | Assert-ADFSchema
        }

        It 'paragraph with -Align <_> conforms' -ForEach $AlignValues {
            ADFDoc { ADFParagraph -Align $_ { ADFText 'x' } } | Assert-ADFSchema
        }

        It 'paragraph with -IndentationLevel <_> conforms' -ForEach ( 1..6 ) {
            ADFDoc { ADFParagraph -IndentationLevel $_ { ADFText 'x' } } | Assert-ADFSchema
        }
    }

    Context 'heading' {

        It 'heading level <_> conforms' -ForEach $HeadingLevels {
            ADFDoc { ADFHeading -Level $_ { ADFText 'Title' } } | Assert-ADFSchema
        }

        It 'heading with -Align <_> conforms' -ForEach $AlignValues {
            ADFDoc { ADFHeading -Level H2 -Align $_ { ADFText 'Title' } } | Assert-ADFSchema
        }

        It 'heading with indentation conforms' {
            ADFDoc { ADFHeading -Level H2 -IndentationLevel 2 { ADFText 'Title' } } | Assert-ADFSchema
        }

        It 'heading with LocalId conforms' {
            ADFDoc { ADFHeading -Level H1 -LocalId 'h-1' { ADFText 'Title' } } | Assert-ADFSchema
        }
    }

    Context 'blockquote' {

        It 'blockquote with paragraph conforms' {
            ADFDoc { ADFBlockquote { ADFParagraph { ADFText 'Quote' } } } | Assert-ADFSchema
        }

        It 'blockquote with LocalId conforms' {
            ADFDoc { ADFBlockquote -LocalId 'bq-1' { ADFParagraph { ADFText 'Quote' } } } | Assert-ADFSchema
        }
    }

    Context 'lists' {

        It 'bullet list conforms' {
            ADFDoc {
                ADFBulletList {
                    ADFListItem { ADFParagraph { ADFText 'One' } }
                    ADFListItem { ADFParagraph { ADFText 'Two' } }
                }
            } | Assert-ADFSchema
        }

        It 'ordered list conforms' {
            ADFDoc {
                ADFOrderedList {
                    ADFListItem { ADFParagraph { ADFText 'One' } }
                }
            } | Assert-ADFSchema
        }

        It 'ordered list with -Order conforms' {
            ADFDoc {
                ADFOrderedList -Order 3 {
                    ADFListItem { ADFParagraph { ADFText 'Three' } }
                }
            } | Assert-ADFSchema
        }

        It 'nested lists conform' {
            ADFDoc {
                ADFBulletList {
                    ADFListItem {
                        ADFParagraph { ADFText 'Parent' }
                        ADFOrderedList {
                            ADFListItem { ADFParagraph { ADFText 'Child' } }
                        }
                    }
                }
            } | Assert-ADFSchema
        }

        It 'list item containing a code block conforms' {
            ADFDoc {
                ADFBulletList {
                    ADFListItem {
                        ADFParagraph { ADFText 'Run:' }
                        ADFCodeBlock -Language powershell { ADFText 'Get-Process' }
                    }
                }
            } | Assert-ADFSchema
        }

        It 'lists and list items with LocalId conform' {
            ADFDoc {
                ADFBulletList -LocalId 'bl-1' {
                    ADFListItem -LocalId 'li-1' { ADFParagraph { ADFText 'One' } }
                }
                ADFOrderedList -LocalId 'ol-1' {
                    ADFListItem -LocalId 'li-2' { ADFParagraph { ADFText 'One' } }
                }
            } | Assert-ADFSchema
        }
    }

    Context 'codeBlock' {

        It 'code block without language conforms' {
            ADFDoc { ADFCodeBlock { ADFText 'code' } } | Assert-ADFSchema
        }

        It 'empty code block conforms' {
            ADFDoc { ADFCodeBlock } | Assert-ADFSchema
        }

        It 'code block with LocalId conforms' {
            ADFDoc { ADFCodeBlock -LocalId 'cb-1' { ADFText 'code' } } | Assert-ADFSchema
        }

        It 'code blocks for every supported language conform' {
            $Languages = [enum]::GetNames( ( Get-Command New-ADFCodeBlock ).Parameters['Language'].ParameterType )
            ADFDoc {
                foreach ( $Language in $Languages ) {
                    ADFCodeBlock -Language $Language { ADFText 'x' }
                }
            } | Assert-ADFSchema
        }
    }

    Context 'expand and nestedExpand' {

        It 'expand with title conforms' {
            ADFDoc { ADFExpand -Title 'More' { ADFParagraph { ADFText 'Hidden' } } } | Assert-ADFSchema
        }

        It 'expand without title conforms' {
            ADFDoc { ADFExpand { ADFParagraph { ADFText 'Hidden' } } } | Assert-ADFSchema
        }

        It 'expand with LocalId conforms' {
            ADFDoc { ADFExpand -Title 'More' -LocalId 'ex-1' { ADFParagraph { ADFText 'Hidden' } } } | Assert-ADFSchema
        }

        It 'nestedExpand inside expand conforms' {
            ADFDoc {
                ADFExpand -Title 'Outer' {
                    ADFNestedExpand -Title 'Inner' { ADFParagraph { ADFText 'Hidden' } }
                }
            } | Assert-ADFSchema
        }

        It 'nestedExpand inside a table cell conforms' {
            ADFDoc {
                ADFTable {
                    ADFTableRow {
                        ADFTableCell {
                            ADFNestedExpand -Title 'Inner' -LocalId 'ne-1' { ADFParagraph { ADFText 'Hidden' } }
                        }
                    }
                }
            } | Assert-ADFSchema
        }
    }

    Context 'panel' {

        It 'panel of type <_> conforms' -ForEach $PanelTypes {
            ADFDoc { ADFPanel -Type $_ { ADFParagraph { ADFText 'Note' } } } | Assert-ADFSchema
        }

        It 'panel with LocalId conforms' {
            ADFDoc { ADFPanel -Type Info -LocalId 'pn-1' { ADFParagraph { ADFText 'Note' } } } | Assert-ADFSchema
        }
    }

    Context 'rule' {

        It 'rule conforms' {
            ADFDoc { ADFRule } | Assert-ADFSchema
        }

        It 'rule with LocalId conforms' {
            ADFDoc { ADFRule -LocalId 'r-1' } | Assert-ADFSchema
        }
    }

    Context 'table' {

        It 'basic table with header and cell rows conforms' {
            ADFDoc {
                ADFTable {
                    ADFTableRow {
                        ADFTableHeader { ADFParagraph { ADFText 'Name' } }
                        ADFTableHeader { ADFParagraph { ADFText 'Role' } }
                    }
                    ADFTableRow {
                        ADFTableCell { ADFParagraph { ADFText 'Alice' } }
                        ADFTableCell { ADFParagraph { ADFText 'Developer' } }
                    }
                }
            } | Assert-ADFSchema
        }

        It 'table with -Layout <_> conforms' -ForEach $TableLayouts {
            ADFDoc {
                ADFTable -Layout $_ { ADFTableRow { ADFTableCell { ADFParagraph { ADFText 'x' } } } }
            } | Assert-ADFSchema
        }

        It 'table with -DisplayMode <_> conforms' -ForEach $TableDisplayModes {
            ADFDoc {
                ADFTable -DisplayMode $_ { ADFTableRow { ADFTableCell { ADFParagraph { ADFText 'x' } } } }
            } | Assert-ADFSchema
        }

        It 'table with width, number column, and LocalId conforms' {
            ADFDoc {
                ADFTable -Width 760 -IsNumberColumnEnabled -LocalId 'tbl-1' {
                    ADFTableRow { ADFTableCell { ADFParagraph { ADFText 'x' } } }
                }
            } | Assert-ADFSchema
        }

        It 'table cells and headers with attributes conform' {
            ADFDoc {
                ADFTable {
                    ADFTableRow {
                        ADFTableHeader -Background '#DEEBFF' -Colspan 2 -Colwidth 100, 200 { ADFParagraph { ADFText 'Wide header' } }
                    }
                    ADFTableRow {
                        ADFTableCell -Rowspan 1 -Colwidth 100 -Background '#FFFFFF' { ADFParagraph { ADFText 'a' } }
                        ADFTableCell -Colspan 1 -Colwidth 200 { ADFParagraph { ADFText 'b' } }
                    }
                }
            } | Assert-ADFSchema
        }
    }

    Context 'media' {

        It 'mediaSingle with -Layout <_> conforms' -ForEach $MediaSingleLayouts {
            ADFDoc { ADFMediaSingle -Layout $_ { New-TestMedia } } | Assert-ADFSchema
        }

        It 'mediaSingle with percentage width conforms' {
            ADFDoc { ADFMediaSingle -Layout Center -Width 50 -WidthType Percentage { New-TestMedia } } | Assert-ADFSchema
        }

        It 'mediaSingle with pixel width conforms' {
            ADFDoc { ADFMediaSingle -Layout Center -Width 400 -WidthType Pixel { New-TestMedia } } | Assert-ADFSchema
        }

        It 'mediaSingle with LocalId conforms' {
            ADFDoc { ADFMediaSingle -Layout Center -LocalId 'ms-1' { New-TestMedia } } | Assert-ADFSchema
        }

        It 'mediaGroup conforms' {
            ADFDoc { ADFMediaGroup { New-TestMedia; New-TestMedia } } | Assert-ADFSchema
        }

        It 'media of type <_> conforms' -ForEach $MediaTypes {
            ADFDoc { ADFMediaGroup { ADFMedia -Id 'abc-123' -Type $_ -Collection 'test-collection' } } | Assert-ADFSchema
        }

        It 'media with dimensions, occurrence key, and LocalId conforms' {
            ADFDoc {
                ADFMediaSingle -Layout Center {
                    ADFMedia -Id 'abc-123' -Type File -Collection 'c' -Width 800 -Height 600 -OccurrenceKey 'occ-1' -LocalId 'm-1'
                }
            } | Assert-ADFSchema
        }

        It 'media with a link mark conforms' {
            ADFDoc {
                ADFMediaSingle -Layout Center {
                    ADFMedia -Id 'abc-123' -Type File -Collection 'c' -LinkHref 'https://example.com/image' -LinkTitle 'Example'
                }
            } | Assert-ADFSchema
        }

        It 'media with a border mark conforms' {
            ADFDoc {
                ADFMediaSingle -Layout Center {
                    New-TestMedia | ADFBorder -Size 2 -Color '#091E4224' -PassThru
                }
            } | Assert-ADFSchema
        }
    }

    Context 'taskList' {

        It 'task list with items conforms' {
            ADFDoc {
                ADFTaskList -LocalId 'tl-1' {
                    ADFTaskItem -State TODO -LocalId 'ti-1' { ADFText 'Pending' }
                    ADFTaskItem -State DONE -LocalId 'ti-2' { ADFText 'Finished' }
                }
            } | Assert-ADFSchema
        }

        It 'task list without LocalId conforms (LocalId is generated)' {
            ADFDoc {
                ADFTaskList {
                    ADFTaskItem -State TODO { ADFText 'Pending' }
                }
            } | Assert-ADFSchema
        }

        It 'task item with inline nodes conforms' {
            ADFDoc {
                ADFTaskList {
                    ADFTaskItem -State TODO {
                        ADFMention -Id 'user-1'
                        ADFText ' due '
                        ADFDate -Timestamp '2024-01-15'
                    }
                }
            } | Assert-ADFSchema
        }

        It 'nested task list conforms' {
            ADFDoc {
                ADFTaskList {
                    ADFTaskItem -State TODO { ADFText 'Parent' }
                    ADFTaskList { ADFTaskItem -State DONE { ADFText 'Child' } }
                }
            } | Assert-ADFSchema
        }

        It 'task list inside <_> conforms' -ForEach 'listItem', 'panel', 'expand', 'nestedExpand', 'tableCell', 'tableHeader' {
            $TaskList = { ADFTaskList { ADFTaskItem -State TODO { ADFText 'Task' } } }
            $Document = switch ( $_ ) {
                'listItem'     { ADFDoc { ADFBulletList { ADFListItem { ADFParagraph { ADFText 'x' }; & $TaskList } } } }
                'panel'        { ADFDoc { ADFPanel -Type Info $TaskList } }
                'expand'       { ADFDoc { ADFExpand -Title 'x' $TaskList } }
                'nestedExpand' { ADFDoc { ADFExpand -Title 'x' { ADFNestedExpand -Title 'y' $TaskList } } }
                'tableCell'    { ADFDoc { ADFTable { ADFTableRow { ADFTableCell $TaskList } } } }
                'tableHeader'  { ADFDoc { ADFTable { ADFTableRow { ADFTableHeader $TaskList } } } }
            }
            $Document | Assert-ADFSchema
        }
    }
}

Describe 'Inline nodes' {

    It 'plain text conforms' {
        New-InlineTestDoc { ADFText 'Hello' } | Assert-ADFSchema
    }

    It 'date conforms' {
        New-InlineTestDoc { ADFDate -Timestamp ( [datetime]'2024-01-15' ) } | Assert-ADFSchema
    }

    It 'date with LocalId conforms' {
        New-InlineTestDoc { ADFDate -Timestamp ( [datetime]'2024-01-15' ) -LocalId 'd-1' } | Assert-ADFSchema
    }

    It 'date timestamp is midnight UTC of the calendar date, in milliseconds, as a string (<Kind>)' -ForEach @(
        @{ Kind = 'DateTime Unspecified'; Value = [datetime]::new( 2024, 1, 15, 0, 0, 0, [DateTimeKind]::Unspecified ) }
        @{ Kind = 'DateTime Local';       Value = [datetime]::new( 2024, 1, 15, 0, 0, 0, [DateTimeKind]::Local ) }
        @{ Kind = 'DateTime Utc';         Value = [datetime]::new( 2024, 1, 15, 0, 0, 0, [DateTimeKind]::Utc ) }
        @{ Kind = 'DateTime late Local';  Value = [datetime]::new( 2024, 1, 15, 23, 59, 59, [DateTimeKind]::Local ) }
        @{ Kind = 'DateTimeOffset +14:00'; Value = [DateTimeOffset]::new( 2024, 1, 15, 0, 0, 0, [TimeSpan]::FromHours( 14 ) ) }
        @{ Kind = 'DateTimeOffset -12:00'; Value = [DateTimeOffset]::new( 2024, 1, 15, 23, 59, 59, [TimeSpan]::FromHours( -12 ) ) }
        @{ Kind = 'string date only';     Value = '2024-01-15' }
        @{ Kind = 'string Z';             Value = '2024-01-15T00:00:00Z' }
        @{ Kind = 'string late Z';        Value = '2024-01-15T23:59:59Z' }
        @{ Kind = 'string +14:00';        Value = '2024-01-15T00:00:00+14:00' }
        @{ Kind = 'string -12:00';        Value = '2024-01-15T23:59:59-12:00' }
    ) {
        ( ADFDate -Timestamp $Value ).attrs.timestamp | Should -BeExactly '1705276800000'
    }

    It 'date round-trips through Get-ADFDocumentNode -ExtractText' {
        $Document = ADFDoc { ADFParagraph { ADFDate -Timestamp ( [datetime]'2024-01-15 23:30' ) } }
        ( Get-ADFDocumentNode -RootNode $Document -ExtractText ) -join '' | Should -Match '2024-01-15'
    }

    It 'date -Timestamp is mandatory' {
        ( Get-Command New-ADFDate ).Parameters['Timestamp'].Attributes.Where( { $_ -is [System.Management.Automation.ParameterAttribute] } ).Mandatory | Should -BeTrue
    }

    It 'emoji with short name only conforms' {
        New-InlineTestDoc { ADFEmoji -ShortName ':smile:' } | Assert-ADFSchema
    }

    It 'emoji with text, id, and LocalId conforms' {
        New-InlineTestDoc { ADFEmoji -ShortName ':smile:' -Text ([char]::ConvertFromUtf32(0x1F604)) -Id '1f604' -LocalId 'e-1' } | Assert-ADFSchema
    }

    It 'hardBreak conforms' {
        New-InlineTestDoc { ADFText 'Line 1'; ADFHardBreak; ADFText 'Line 2' } | Assert-ADFSchema
    }

    It 'hardBreak with LocalId conforms' {
        New-InlineTestDoc { ADFText 'Line 1'; ADFHardBreak -LocalId 'hb-1'; ADFText 'Line 2' } | Assert-ADFSchema
    }

    It 'inlineCard with url conforms' {
        New-InlineTestDoc { ADFInlineCard -Url 'https://example.com/page' } | Assert-ADFSchema
    }

    It 'inlineCard with JSON-LD data conforms' {
        $Data = '{"@type":"Document","name":"Example","url":"https://example.com"}'
        New-InlineTestDoc { ADFInlineCard -Data $Data -LocalId 'ic-1' } | Assert-ADFSchema
    }

    It 'mention conforms' {
        New-InlineTestDoc { ADFMention -Id 'user-1' -Text '@User' } | Assert-ADFSchema
    }

    It 'mention with -AccessLevel <_> conforms' -ForEach $MentionAccessLevels {
        New-InlineTestDoc { ADFMention -Id 'user-1' -AccessLevel $_ } | Assert-ADFSchema
    }

    It 'mention with -UserType <_> conforms' -ForEach $MentionUserTypes {
        New-InlineTestDoc { ADFMention -Id 'user-1' -UserType $_ } | Assert-ADFSchema
    }

    It 'mention with LocalId conforms' {
        New-InlineTestDoc { ADFMention -Id 'user-1' -LocalId 'mn-1' } | Assert-ADFSchema
    }

    It 'status with -Color <_> conforms' -ForEach $StatusColors {
        New-InlineTestDoc { ADFStatus -Text 'In progress' -Color $_ } | Assert-ADFSchema
    }

    It 'status without color conforms' {
        New-InlineTestDoc { ADFStatus -Text 'In progress' } | Assert-ADFSchema
    }

    It 'status with LocalId conforms' {
        New-InlineTestDoc { ADFStatus -Text 'Done' -Color Green -LocalId 's-1' } | Assert-ADFSchema
    }
}

Describe 'Text marks' {

    It 'text with -<_> conforms' -ForEach 'Strong', 'Em', 'Underline', 'Strike', 'Code' {
        $Switch = @{ $_ = $true }
        New-InlineTestDoc { ADFText 'x' @Switch } | Assert-ADFSchema
    }

    It 'text with -SubsupType <_> conforms' -ForEach $SubsupTypes {
        New-InlineTestDoc { ADFText 'x' -SubsupType $_ } | Assert-ADFSchema
    }

    It 'text with -TextColor conforms' {
        New-InlineTestDoc { ADFText 'x' -TextColor '#FF5630' } | Assert-ADFSchema
    }

    It 'text with a link conforms' {
        New-InlineTestDoc { ADFText 'x' -LinkHref 'https://example.com' } | Assert-ADFSchema
    }

    It 'text with a link with all link attributes conforms' {
        New-InlineTestDoc {
            ADFText 'x' -LinkHref 'https://example.com/path?q=1' -LinkTitle 'Example' -LinkId 'link-1' -LinkCollection 'col' -LinkOccurrenceKey 'occ'
        } | Assert-ADFSchema
    }

    It 'code text with a link conforms' {
        New-InlineTestDoc { ADFText 'Get-Process' -Code -LinkHref 'https://learn.microsoft.com/powershell' } | Assert-ADFSchema
    }

    It 'text with combined formatting marks conforms' {
        New-InlineTestDoc {
            ADFText 'x' -Strong -Em -Underline -Strike -TextColor '#C50F1F' -LinkHref 'https://github.com' -LinkTitle 'GitHub'
        } | Assert-ADFSchema
    }

    It 'text with a background color mark conforms' {
        New-InlineTestDoc { ADFText 'x' | ADFBackgroundColor -Color '#FFFF00' -PassThru } | Assert-ADFSchema
    }

    It 'text with an annotation mark of type <_> conforms' -ForEach $AnnotationTypes {
        New-InlineTestDoc { ADFText 'x' | ADFAnnotation -Id 'ann-1' -AnnotationType $_ -PassThru } | Assert-ADFSchema
    }

    It 'text with marks added via Add-ADF*Mark conforms' {
        New-InlineTestDoc {
            ADFText 'x' | ADFStrong -PassThru | ADFEm -PassThru | ADFUnderline -PassThru | ADFStrike -PassThru |
                ADFTextColor -Color '#0078D4' -PassThru | ADFLink -Href 'https://example.com' -PassThru
        } | Assert-ADFSchema
    }

    It 'text with code mark added via Add-ADFCodeMark conforms' {
        New-InlineTestDoc { ADFText 'x' | ADFCode -PassThru } | Assert-ADFSchema
    }

    It 'text with subsup mark added via Add-ADFSubsupMark conforms' {
        New-InlineTestDoc { ADFText 'x' | ADFSubSup -Type Superscript -PassThru } | Assert-ADFSchema
    }

    It 'text with -SubsupType <_> includes the subsup mark' -ForEach $SubsupTypes {
        $Node = ADFText 'x' -SubsupType $_
        $Node.marks.type | Should -Be 'subsup'
        $Node.marks[0].attrs.type | Should -Be @{ Subscript = 'sub'; Superscript = 'sup' }[$_]
    }
}

Describe 'Invalid mark combinations are rejected' {

    # The schema only allows the code mark alongside link and annotation marks, so these would
    # otherwise produce non-conforming output.
    It 'text with -Code and -<Name> throws' -ForEach @(
        @{ Name = 'Strong';     Splat = @{ Strong = $true } }
        @{ Name = 'Em';         Splat = @{ Em = $true } }
        @{ Name = 'Underline';  Splat = @{ Underline = $true } }
        @{ Name = 'Strike';     Splat = @{ Strike = $true } }
        @{ Name = 'SubsupType'; Splat = @{ SubsupType = 'Superscript' } }
        @{ Name = 'TextColor';  Splat = @{ TextColor = '#FF0000' } }
    ) {
        { ADFText 'x' -Code @Splat } | Should -Throw '*cannot be combined*'
    }

    # Add-ADF*Mark functions report failures as non-terminating errors.
    It 'adding a formatting mark to code text throws' {
        { ADFText 'x' -Code | ADFStrong -ErrorAction Stop } | Should -Throw '*cannot be combined*'
    }

    It 'adding a code mark to formatted text throws' {
        { ADFText 'x' | ADFBackgroundColor -Color '#FFFF00' -PassThru | ADFCode -ErrorAction Stop } | Should -Throw '*cannot be combined*'
    }

    It 'code text with link and annotation marks is allowed' {
        New-InlineTestDoc {
            ADFText 'x' -Code -LinkHref 'https://example.com' | ADFAnnotation -Id 'ann-1' -PassThru
        } | Assert-ADFSchema
    }
}

Describe 'Block marks' {

    It 'paragraph with alignment mark added via Add-ADFAlignmentMark conforms' {
        ADFDoc { ADFParagraph { ADFText 'x' } | ADFAlignment -Align Center -PassThru } | Assert-ADFSchema
    }

    It 'paragraph with indentation mark added via Add-ADFIndentationMark conforms' {
        ADFDoc { ADFParagraph { ADFText 'x' } | ADFIndent -Level 3 -PassThru } | Assert-ADFSchema
    }
}

Describe 'Composite document' {

    It 'a document using many node types together conforms' {
        ADFDoc {
            ADFHeading -Level H1 { ADFText 'Release notes' }
            ADFParagraph {
                ADFText 'Shipped by '
                ADFMention -Id 'user-1' -Text '@Dev'
                ADFText ' on '
                ADFDate -Timestamp '2024-01-15'
                ADFText ' '
                ADFStatus -Text 'Released' -Color Green
                ADFText ' '
                ADFEmoji -ShortName ':tada:'
            }
            ADFPanel -Type Info { ADFParagraph { ADFText 'Read before upgrading.' -Strong } }
            ADFBulletList {
                ADFListItem { ADFParagraph { ADFText 'See ' ; ADFText 'docs' -LinkHref 'https://example.com/docs' } }
            }
            ADFCodeBlock -Language powershell { ADFText 'Update-Module CommunityADF' }
            ADFRule
            ADFExpand -Title 'Details' {
                ADFParagraph { ADFText 'More details.' }
                ADFNestedExpand -Title 'Even more' { ADFParagraph { ADFText 'Deep.' } }
            }
            ADFTable -Layout Center {
                ADFTableRow { ADFTableHeader { ADFParagraph { ADFText 'Key' } } }
                ADFTableRow { ADFTableCell { ADFParagraph { ADFText 'Value' } } }
            }
            ADFBlockquote { ADFParagraph { ADFText 'Fin.' -Em } }
        } | Assert-ADFSchema
    }
}

# Runs last because each example re-imports the module with -Force.
Describe 'Example scripts' {

    It 'examples/<Name>.ps1 produces conforming output' -ForEach $ExampleScripts {
        $Outputs = @( & $Path 6> $null )
        $Outputs.Count | Should -BeGreaterThan 0 -Because 'each example should emit at least one ADF document'
        $Outputs | Assert-ADFSchema
    }
}
