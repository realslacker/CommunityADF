#Requires -Version 5.1

enum ADFStringFormat {
    Text
    Markdown
    HTML
}

# MARK: ## BASE CLASSES ##


enum ADFAttributeAction {
    Error
    Allow
    Skip
}


# MARK: ADFAttributeInfo Class
# Utility class to define allowed attributes on ADF nodes,
class ADFAttributeInfo {
    [string] $Name
    [Type] $Type = [object]
    [Type] $ReturnType = [object]
    [scriptblock] $Transform
    [bool] $Required = $false

    ADFAttributeInfo() {}

    ADFAttributeInfo( [string] $Name ) {
        $this.Name        = $Name
    }

    ADFAttributeInfo( [string] $Name, [bool] $Required ) {
        $this.Name        = $Name
        $this.Required    = $Required
    }

    ADFAttributeInfo( [string] $Name, [Type] $Type ) {
        $this.Name        = $Name
        $this.Type        = $Type
        $this.ReturnType  = $Type
    }

    ADFAttributeInfo( [string] $Name, [Type] $Type, [bool] $Required ) {
        $this.Name        = $Name
        $this.Type        = $Type
        $this.ReturnType  = $Type
        $this.Required    = $Required
    }

    ADFAttributeInfo( [string] $Name, [Type] $Type, [Type] $ReturnType ) {
        $this.Name        = $Name
        $this.Type        = $Type
        $this.ReturnType  = $ReturnType
    }

    ADFAttributeInfo( [string] $Name, [Type] $Type, [Type] $ReturnType, [bool] $Required ) {
        $this.Name        = $Name
        $this.Type        = $Type
        $this.ReturnType  = $ReturnType
        $this.Required    = $Required
    }

    ADFAttributeInfo( [string] $Name, [Type] $Type, [Type] $ReturnType, [scriptblock] $Transform ) {
        $this.Name        = $Name
        $this.Type        = $Type
        $this.ReturnType  = $ReturnType
        $this.Transform   = $Transform
    }

    ADFAttributeInfo( [string] $Name, [Type] $Type, [Type] $ReturnType, [scriptblock] $Transform, [bool] $Required ) {
        $this.Name        = $Name
        $this.Type        = $Type
        $this.ReturnType  = $ReturnType
        $this.Transform   = $Transform
        $this.Required    = $Required
    }

    [void] SetValue( [hashtable] $Hashtable, [object] $Value ) {

        Write-Debug ( 'Setting attribute "{0}" to value: {1}' -f $this.Name, ( $Value | Out-String ) )

        # check for null or empty value
        # if it's required we throw, if not we just skip
        if ( [string]::IsNullOrEmpty($Value) ) {
            if ( $this.Required ) {
                $ExceptionMessage = 'Attribute "{0}" is required but no value was provided.' -f $this.Name
                throw [System.ArgumentNullException]::new( $this.Name, $ExceptionMessage )
            }
            return
        }

        # check for expectd type and throw an error if not
        if ( $Value -isnot $this.Type ) {
            $ExceptionMessage = 'Attribute "{0}" expects a value of type "{1}", but got a value of type "{2}".' -f $this.Name, $this.Type.FullName, $Value.GetType().FullName
            throw [System.ArgumentException]::new( $ExceptionMessage, $this.Name )
        }
        
        # if a transform scriptblock is defined, use it to transform the value before setting it
        if ( $this.Transform -is [scriptblock] ) {
            Write-Debug ( 'Transforming value for attribute "{0}" using the defined transform scriptblock.' -f $this.Name )
            $Value = $Value | ForEach-Object $this.Transform
        }

        # finally set the value in the hashtable, casting to the return type
        $Hashtable[$this.Name] = $Value -as $this.ReturnType

    }

}


# MARK: ADFMark Class
# Base class for ADF node markers, which are used to annotate AST nodes with ADF-specific information.
class ADFMark {

    ADFMark() {
        Write-Debug ( 'Creating mark of type "{0}".' -f $this.type )
    }

    [void] AddAttribute( [string] $Name, [object] $Value ) {

        Write-Debug ( 'Adding attribute "{0}" to mark "{1}" with value: {2}' -f $Name, $this.type, ( $Value | Out-String ) )

        # if the class doesn't define any allowwed attributes, then it shouldn't allow setting any attributes
        if ( -not $this::AllowedAttributes ) {
            $ExceptionMessage = 'Mark of type "{0}" does not allow any attributes, but attempted to set attribute "{1}".' -f $this.type, $Name
            throw [System.ArgumentException]::new( $ExceptionMessage, $Name )
        }

        # check if the attribute is defined in the class's AllowedAttributes and get the corresponding ADFAttributeInfo object
        $AttributeInfo = $this::AllowedAttributes | Where-Object { $_.Name -eq $Name }

        # if no matching attribute is found, throw an error
        if ( -not $AttributeInfo ) {
            $ExceptionMessage = 'Mark of type "{0}" does not allow an attribute named "{1}".' -f $this.type, $Name
            throw [System.ArgumentException]::new( $ExceptionMessage, $Name )
        }

        # use the ADFAttributeInfo object to set the value, which will perform type checking and transformation as needed
        $AttributeInfo.SetValue( $this.attrs, $Value )

    }

    hidden static [string] GetTypeName( [ADFMark] $Mark ) {
        return $Mark.GetType().Name -replace '^ADF' -replace 'Mark$' | ForEach-Object { $_.Substring( 0, 1 ).ToLower() + $_.Substring( 1 ) }
    }

    [string] ApplyMarkdown( [string] $Text ) {
        return $Text
    }

}


# MARK: ADFNode Class
# base class for ADF nodes, which represent elements of the ADF structure and are annotated with ADFMarks.
class ADFNode {

    ADFNode() {
        Write-Debug ( 'Creating node of type "{0}".' -f $this.type )
    }

    [void] AddAttribute( [string] $Name, [object] $Value ) {

        Write-Debug ( 'Adding attribute "{0}" to mark "{1}" with value: {2}' -f $Name, $this.type, ( $Value | Out-String ) )

        # if the class doesn't define any allowwed attributes, then it shouldn't allow setting any attributes
        if ( -not $this::AllowedAttributes ) {
            $ExceptionMessage = 'Node of type "{0}" does not allow any attributes, but attempted to set attribute "{1}".' -f $this.type, $Name
            throw [System.ArgumentException]::new( $ExceptionMessage, $Name )
        }

        # check if the attribute is defined in the class's AllowedAttributes and get the corresponding ADFAttributeInfo object
        $AttributeInfo = $this::AllowedAttributes | Where-Object { $_.Name -eq $Name }

        # if no matching attribute is found, throw an error
        if ( -not $AttributeInfo ) {
            $ExceptionMessage = 'Node of type "{0}" does not allow an attribute named "{1}".' -f $this.type, $Name
            throw [System.ArgumentException]::new( $ExceptionMessage, $Name )
        }

        # use the ADFAttributeInfo object to set the value, which will perform type checking and transformation as needed
        $AttributeInfo.SetValue( $this.attrs, $Value )

    }

    [void] AddMark( [ADFMark] $Mark ) {

        Write-Debug ( 'Adding mark of type "{0}" to node of type "{1}".' -f $Mark.type, $this.type )

        # if the class doesn't define any allowed marks, then it shouldn't allow adding any marks
        if ( -not $this::AllowedMarks ) {
            $ExceptionMessage = 'Node of type "{0}" does not allow any marks, but attempted to add mark of type "{1}".' -f $this.type, $Mark.type
            throw [System.ArgumentException]::new( $ExceptionMessage, 'Mark' )
        }

        # check if the mark's type is in the class's AllowedMarks
        if ( -not ( $this::AllowedMarks -contains $Mark.type ) ) {
            $ExceptionMessage = 'Node of type "{0}" does not allow marks of type "{1}".' -f $this.type, $Mark.type
            throw [System.ArgumentException]::new( $ExceptionMessage, 'Mark' )
        }

        # if validation passes, add the mark to the node's list of marks
        $this.marks.Add( $Mark )

    }

    hidden static [string] GetTypeName( [ADFNode] $Node ) {
        return $Node.GetType().Name -replace '^ADF' | ForEach-Object { $_.Substring( 0, 1 ).ToLower() + $_.Substring( 1 ) }
    }

    [void] AddChild( [ADFNode] $ChildNode ) {

        Write-Debug ( 'Adding child node of type "{0}" to parent node of type "{1}".' -f $ChildNode.type, $this.type )

        # if the class doesn't define any allowed child node types, then it shouldn't allow adding any child nodes
        if ( -not $this::AllowedChildren ) {
            $ExceptionMessage = 'Node of type "{0}" does not allow any child nodes, but attempted to add child node of type "{1}".' -f $this.type, $ChildNode.type
            throw [System.ArgumentException]::new( $ExceptionMessage, 'ChildNode' )
        }

        # check if the child node's type is in the class's AllowedChildren
        if ( -not ( $this::AllowedChildren -contains $ChildNode.type ) ) {
            $ExceptionMessage = 'Node of type "{0}" does not allow child nodes of type "{1}".' -f $this.type, $ChildNode.type
            throw [System.ArgumentException]::new( $ExceptionMessage, 'ChildNode' )
        }

        # if validation passes, add the child node to the parent node's list of child nodes
        $this.content.Add( $ChildNode )

    }

    [string] ToMarkdown() {
        if ( $this.Text ) {
            return $this.Text
        } else {
            return ''
        }
    }

}


# MARK: ADFInlineNode Class
# Base class for ADF inline nodes, which represent inline elements of the ADF structure and are annotated with ADFMarks.
class ADFInlineNode : ADFNode {
    ADFInlineNode() : base() {}
}


# MARK: ADFBlockNode Class
# Base class for ADF block nodes, which represent block-level elements of the ADF structure and are annotated with ADFMarks.
class ADFBlockNode : ADFNode {
    ADFBlockNode() : base() {}
}


# MARK: ## MARKS ##


# MARK: Add-ADFMark Function
function Add-ADFMark {
    [CmdletBinding( PositionalBinding = $false )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [Parameter( Mandatory = $true )]
        [ADFMark] $Mark,
        [switch] $PassThru
    )

    process {
        try {
            $Node.AddMark( $Mark )
        } catch {
            Write-Error $_
        }
        if ( $PassThru ) {
            Write-Output $Node
        }
    }
}


# MARK: ADFAlignment Enum
enum ADFAlignment {
    Center
    End
}


# MARK: ADFAlignmentMark Class
# Represents an alignment mark in the ADF structure. This mark can be applied to Heading and Paragraph nodes to specify text alignment.
class ADFAlignmentMark : ADFMark {

    [string] $type = 'alignment'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'align', [ADFAlignment], [string], { $_.ToString().ToLower() }, $true ) # required
    )

    ADFAlignmentMark( [ADFAlignment] $Align ) : base() {
        $this.AddAttribute( 'align', $Align )
    }

}


# MARK: Get-ADFAlignmentMark Function
function Get-ADFAlignmentMark {
    [CmdletBinding( PositionalBinding = $false )]
    param(
        [Parameter( Mandatory = $true )]
        [ADFAlignment] $Align
    )

    [ADFAlignmentMark]::new( $Align )
}


# MARK:ADFAnnotationType Enum
enum ADFAnnotationType {
    InlineComment
}


# MARK: ADFAnnotationMark Class
# Represents an annotation mark in the ADF structure. This mark can be applied to text elements to provide additional information or context, such as comments or notes.
class ADFAnnotationMark : ADFMark {

    [string] $type = 'annotation'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'id', [string], $true ) # required, unique identifier for the annotation
        [ADFAttributeInfo]::new( 'annotationType', [ADFAnnotationType], [string], { $_.ToString()[0].ToLower() + $_.ToString().Substring(1) }, $true ) # required, type of annotation (e.g., inlineComment)
    )

    ADFAnnotationMark( [string] $Id, [ADFAnnotationType] $AnnotationType ) : base() {
        $this.AddAttribute( 'id', $Id )
        $this.AddAttribute( 'annotationType', $AnnotationType )
    }

}


# MARK: Get-ADFAnnotationMark Function
function Get-ADFAnnotationMark {
    [CmdletBinding( PositionalBinding = $false )]
    param(
        [Parameter( Mandatory = $true )]
        [string] $Id,
        [ADFAnnotationType] $AnnotationType = [ADFAnnotationType]::InlineComment
    )

    [ADFAnnotationMark]::new( $Id, $AnnotationType )
}


# MARK: Add-ADFAnnotationMark Function
function Add-ADFAnnotationMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFAnnotation' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [Parameter( Mandatory = $true )]
        [string] $Id,
        [ADFAnnotationType] $AnnotationType = [ADFAnnotationType]::InlineComment,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFAnnotationMark -Id $Id -AnnotationType $AnnotationType
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: Add-ADFAlignmentMark Function
function Add-ADFAlignmentMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFAlignment' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [Parameter( Mandatory = $true )]
        [ADFAlignment] $Align,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFAlignmentMark -Align $Align
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFBackgroundColorMark Class
# Represents a background color mark in the ADF structure. This mark can be applied to text and media elements to specify a background color.
class ADFBackgroundColorMark : ADFMark {

    [string] $type = 'backgroundColor'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'color', [string], $true )   # required, background color value in hex format (e.g., #FFFFFF for white)
    )

    ADFBackgroundColorMark( [string] $Color ) : base() {
        $this.AddAttribute( 'color', $Color )
    }

}


# MARK: Get-ADFBackgroundColorMark Function
function Get-ADFBackgroundColorMark {
    [CmdletBinding( PositionalBinding = $false )]
    param(
        [Parameter( Mandatory = $true )]
        [ValidateScript({
            if ( $_ -notmatch '^#[0-9a-fA-F]{6}$' ) {
                throw [System.ArgumentException]::new( 'Color must be a valid hex color code in the format #RRGGBB.', 'Color' )
            }
            $true
        })]
        [string] $Color
    )

    [ADFBackgroundColorMark]::new( $Color )
}


# MARK: Add-ADFBackgroundColorMark Function
function Add-ADFBackgroundColorMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFBackgroundColor' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [Parameter( Mandatory = $true )]
        [ValidateScript({
            if ( $_ -notmatch '^#[0-9a-fA-F]{6}$' ) {
                throw [System.ArgumentException]::new( 'Color must be a valid hex color code in the format #RRGGBB.', 'Color' )
            }
            $true
        })]
        [string] $Color,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFBackgroundColorMark -Color $Color
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFBorderMark Class
# Represents a border mark in the ADF structure. This mark can be applied to block-level elements to specify a border style.
class ADFBorderMark : ADFMark {

    [string] $type = 'border'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'size', [int], $true )       # required, border size in pixels
        [ADFAttributeInfo]::new( 'color', [string], $true )   # optional, border color in hex format (e.g., #000000 for black)
    )

    ADFBorderMark( [int] $Size, [string] $Color ) : base() {
        $this.AddAttribute( 'size', $Size )
        $this.AddAttribute( 'color', $Color )
    }

}


# MARK: Get-ADFBorderMark Function
function Get-ADFBorderMark {
    [CmdletBinding( PositionalBinding = $false )]
    param(
        [Parameter( Mandatory = $true )]
        [ValidateRange( 1, 3 )]
        [int] $Size,
        [Parameter( Mandatory = $false )]
        [ValidateScript({
            if ( $_ -and $_ -notmatch '^#[0-9a-fA-F]{8}$|^#[0-9a-fA-F]{6}$' ) {
                throw [System.ArgumentException]::new( 'Color must be a valid hex color code in the format #RRGGBBAA or #RRGGBB.', 'Color' )
            }
            $true
        })]
        [string] $Color
    )

    [ADFBorderMark]::new( $Size, $Color )
}


# MARK: Add-ADFBorderMark Function
function Add-ADFBorderMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFBorder' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [Parameter( Mandatory = $true )]
        [ValidateRange( 1, 3 )]
        [int] $Size,
        [Parameter( Mandatory = $false )]
        [ValidateScript({
            if ( $_ -and $_ -notmatch '^#[0-9a-fA-F]{8}$|^#[0-9a-fA-F]{6}$' ) {
                throw [System.ArgumentException]::new( 'Color must be a valid hex color code in the format #RRGGBBAA or #RRGGBB.', 'Color' )
            }
            $true
        })]
        [string] $Color,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFBorderMark -Size $Size -Color $Color
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFCodeMark Class
# Represents a code mark in the ADF structure. This mark can be applied to text elements to indicate that the text is code and should be rendered in a monospace font.
class ADFCodeMark : ADFMark {

    [string] $type = 'code'

    ADFCodeMark() : base() {}

}


# MARK: Get-ADFCodeMark Function
function Get-ADFCodeMark {
    [CmdletBinding( PositionalBinding = $false )]
    param()

    [ADFCodeMark]::new()
}


# MARK: Add-ADFCodeMark Function
function Add-ADFCodeMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFCode' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFCodeMark
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFEmMark Class
# Represents an emphasis mark in the ADF structure. This mark can be applied to text elements to indicate that the text should be emphasized, typically rendered in italics.
class ADFEmMark : ADFMark {

    [string] $type = 'em'

    ADFEmMark() : base() {}

}


# MARK: Get-ADFEmMark Function
function Get-ADFEmMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'Get-ADFItalicMark' )]
    param()

    [ADFEmMark]::new()
}


# MARK: Add-ADFEmMark Function
function Add-ADFEmMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFEm', 'ADFItalic', 'Add-ADFItalicMark' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFEmMark
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFIndentationMark Class
# Represents an indentation mark in the ADF structure. This mark can be applied to block-level elements to indicate that the element should be indented.
class ADFIndentationMark : ADFMark {

    [string] $type = 'indentation'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'level', [int], $true )   # required, indentation level (e.g., 1 for first level of indentation)
    )

    ADFIndentationMark( [int] $Level ) : base() {
        $this.AddAttribute( 'level', $Level )
    }

}


# MARK: Get-ADFIndentationMark Function
function Get-ADFIndentationMark {
    [CmdletBinding( PositionalBinding = $false )]
    param(
        [Parameter( Mandatory = $true )]
        [ValidateRange( 1, 6 )]
        [int] $Level
    )

    [ADFIndentationMark]::new( $Level )
}


# MARK: Add-ADFIndentationMark Function
function Add-ADFIndentationMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFIndent' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [Parameter( Mandatory = $true )]
        [ValidateRange( 1, 6 )]
        [int] $Level,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFIndentationMark -Level $Level
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFLinkMark Class
# Represents a link mark in the ADF structure. This mark can be applied to text elements to indicate that the text is a hyperlink and should be rendered as such.
class ADFLinkMark : ADFMark {

    [string] $type = 'link'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'href', [uri], [string], $true ) # required, URL that the link points to
        [ADFAttributeInfo]::new( 'title', [string] )              # optional, title attribute for the link, typically displayed as a tooltip on hover
        [ADFAttributeInfo]::new( 'id', [string] )                 # optional, unique identifier for the link, can be used for tracking or referencing the link within the document
        [ADFAttributeInfo]::new( 'collection', [string] )         # optional, collection or category that the link belongs to, can be used for organizing links within the document
        [ADFAttributeInfo]::new( 'occurrenceKey', [string] )      # optional, unique key for tracking occurrences of the link, useful for analytics or link management purposes
    )

    ADFLinkMark( [uri] $Href, [string] $Title, [string] $Id, [string] $Collection, [string] $OccurrenceKey ) : base() {
        $this.AddAttribute( 'href', $Href )
        $this.AddAttribute( 'title', $Title )
        $this.AddAttribute( 'id', $Id )
        $this.AddAttribute( 'collection', $Collection )
        $this.AddAttribute( 'occurrenceKey', $OccurrenceKey )
    }

    [string] ApplyMarkdown( [string] $Text ) {
        if ( $this.attrs['title'] ) {
            return '[{0}]({1} "{2}")' -f $Text, $this.attrs['href'], $this.attrs['title']
        } else {
            return '[{0}]({1})' -f $Text, $this.attrs['href']
        }
    }

}


# MARK: Get-ADFLinkMark Function
function Get-ADFLinkMark {
    [CmdletBinding( PositionalBinding = $false )]
    param(
        [Parameter( Mandatory = $true )]
        [uri] $Href,
        [string] $Title,
        [string] $Id,
        [string] $Collection,
        [string] $OccurrenceKey
    )

    [ADFLinkMark]::new( $Href, $Title, $Id, $Collection, $OccurrenceKey )
}


# MARK: Add-ADFLinkMark Function
function Add-ADFLinkMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFLink' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [Parameter( Mandatory = $true )]
        [uri] $Href,
        [string] $Title,
        [string] $Id,
        [string] $Collection,
        [string] $OccurrenceKey,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFLinkMark -Href $Href -Title $Title -Id $Id -Collection $Collection -OccurrenceKey $OccurrenceKey
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFStrikeMark Class
# Represents a strike-through mark in the ADF structure. This mark can be applied to text elements to indicate that the text should be rendered with a line through it, typically used to indicate deleted or irrelevant text.
class ADFStrikeMark : ADFMark {

    [string] $type = 'strike'

    ADFStrikeMark() : base() {}

}


# MARK: Get-ADFStrikeMark Function
function Get-ADFStrikeMark {
    [CmdletBinding( PositionalBinding = $false )]
    param()

    [ADFStrikeMark]::new()
}


# MARK: Add-ADFStrikeMark Function
function Add-ADFStrikeMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFStrike' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFStrikeMark
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFStrongMark Class
# Represents a strong emphasis mark in the ADF structure. This mark can be applied to text elements to indicate that the text should be strongly emphasized, typically rendered in bold.
class ADFStrongMark : ADFMark {

    [string] $type = 'strong'

    ADFStrongMark() : base() {}

}


# MARK: Get-ADFStrongMark Function
function Get-ADFStrongMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'Get-ADFBoldMark' )]
    param()

    [ADFStrongMark]::new()
}


# MARK: Add-ADFStrongMark Function
function Add-ADFStrongMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFStrong', 'ADFBold', 'Add-ADFBoldMark' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFStrongMark
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFSubsupMarkType Enum
# Enum to represent the allowed types for subsup marks in the ADF structure.
enum ADFSubsupMarkType {
    Subscript
    Superscript
}


# MARK: ADFSubSupMark Class
# Represents a subscript or superscript mark in the ADF structure. This mark can be applied to text elements to indicate that the text should be rendered as subscript or superscript, depending on the specified type.
class ADFSubsupMark : ADFMark {
    
    [string] $type = 'subsup'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'type', [ADFSubsupMarkType], [string], { $_.ToString().Substring(0,3).ToLower() }, $true ) # required
    )

    ADFSubsupMark( [ADFSubsupMarkType] $Type ) : base() {
        $this.AddAttribute( 'type', $Type )
    }

}


# MARK: Get-ADFSubsupMark Function
function Get-ADFSubsupMark {
    [CmdletBinding( PositionalBinding = $false )]
    param(
        [Parameter( Mandatory = $true )]
        [ADFSubsupMarkType] $Type
    )

    [ADFSubsupMark]::new( $Type )
}


# MARK: Add-ADFSubsupMark Function
function Add-ADFSubsupMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFSubSup' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [Parameter( Mandatory = $true )]
        [ADFSubsupMarkType] $Type,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFSubsupMark -Type $Type
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFTextColorMark Class
# Represents a text color mark in the ADF structure. This mark can be applied to text elements to specify a text color.
class ADFTextColorMark : ADFMark {

    [string] $type = 'textColor'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'color', [string], $true )   # required, text color value in hex format (e.g., #000000 for black)
    )

    ADFTextColorMark( [string] $Color ) : base() {
        $this.AddAttribute( 'color', $Color )
    }

}


# MARK: Get-ADFTextColorMark Function
function Get-ADFTextColorMark {
    [CmdletBinding( PositionalBinding = $false )]
    param(
        [Parameter( Mandatory = $true )]
        [string] $Color
    )

    [ADFTextColorMark]::new( $Color )
}


# MARK: Add-ADFTextColorMark Function
function Add-ADFTextColorMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFTextColor' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [Parameter( Mandatory = $true )]
        [string] $Color,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFTextColorMark -Color $Color
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ADFUnderlineMark Class
# Represents an underline mark in the ADF structure. This mark can be applied to text elements to indicate that the text should be rendered with an underline.
class ADFUnderlineMark : ADFMark {

    [string] $type = 'underline'

    ADFUnderlineMark() : base() {}

}


# MARK: Get-ADFUnderlineMark Function
function Get-ADFUnderlineMark {
    [CmdletBinding( PositionalBinding = $false )]
    param()

    [ADFUnderlineMark]::new()
}


# MARK: Add-ADFUnderlineMark Function
function Add-ADFUnderlineMark {
    [CmdletBinding( PositionalBinding = $false )]
    [Alias( 'ADFUnderline' )]
    param(
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [ADFNode] $Node,
        [switch] $PassThru
    )

    process {
        $Mark = Get-ADFUnderlineMark
        $Node | Add-ADFMark -Mark $Mark -PassThru:$PassThru
    }
}


# MARK: ## ROOT NODE ##


# MARK: ADFDoc Class
# Root node of the ADF structure, representing an entire ADF document.
class ADFDoc : ADFNode {

    [string] $type = 'doc'
    [int] $version = 1
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'blockquote', 'bulletList', 'codeBlock', 'expand', 'heading',
        'mediaGroup', 'mediaSingle', 'orderedList', 'panel', 'paragraph',
        'rule', 'table'
    )

    ADFDoc( [int] $Version ) : base() {
        $this.version = $Version
    }

}


# MARK: ADFDoc Function
function New-ADFDoc {
    <#
    .SYNOPSIS
        Creates an ADF document root node.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the document node.
    .PARAMETER Version
        The version of the ADF document.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFDoc] )]
    [Alias( 'ADFDoc' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [string] $Version = '1'
    )
    
    $Node = [ADFDoc]::new( $Version )
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ## TOP LEVEL NODES ##


# MARK: ADFBlockquote Class
# Represents a blockquote element in the ADF structure.
class ADFBlockquote : ADFBlockNode {

    [string] $type = 'blockquote'
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'paragraph', 'bulletList', 'orderedList', 'codeBlock', 'mediaGroup', 'mediaSingle'
    )

    ADFBlockquote() : base() {}

}


# MARK: ADFBlockquote Function
function New-ADFBlockquote {
    <#
    .SYNOPSIS
        Creates an ADF blockquote node.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the blockquote node.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFBlockquote] )]
    [Alias( 'ADFBlockquote' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content
    )
    
    $Node = [ADFBlockquote]::new()
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFBulletList Class
# Represents a bullet list element in the ADF structure.
class ADFBulletList : ADFBlockNode {

    [string] $type = 'bulletList'
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'listItem'
    )

    ADFBulletList() : base() {}

}


# MARK: ADFBulletList Function
function New-ADFBulletList {
    <#
    .SYNOPSIS
        Creates an ADF bullet list node.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the bullet list node.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFBulletList] )]
    [Alias( 'ADFBulletList' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content
    )
    
    $Node = [ADFBulletList]::new()
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFCodeBlockLanguage Enum
# Enum to represent the allowed languages for code blocks in the ADF structure.
# See: https://github.com/react-syntax-highlighter/react-syntax-highlighter/blob/master/AVAILABLE_LANGUAGES_PRISM.MD
enum ADFCodeBlockLanguage {
    abap
    abnf
    actionscript
    ada
    agda
    al
    antlr4
    apacheconf
    apex
    apl
    applescript
    aql
    arduino
    arff
    armasm
    arturo
    asciidoc
    asm6502
    asmatmel
    aspnet
    autohotkey
    autoit
    avisynth
    avroIdl # (avro-idl)
    awk
    bash
    basic
    batch
    bbcode
    bbj
    bicep
    birb
    bison
    bnf
    bqn
    brainfuck
    brightscript
    bro
    bsl
    c
    cfscript
    chaiscript
    cil
    cilkc
    cilkcpp
    clike
    clojure
    cmake
    cobol
    coffeescript
    concurnas
    cooklang
    coq
    cpp
    crystal
    csharp
    cshtml
    csp
    cssExtras # (css-extras)
    css
    csv
    cue
    cypher
    d
    dart
    dataweave
    dax
    dhall
    diff
    django
    dnsZoneFile # (dns-zone-file)
    docker
    dot
    ebnf
    editorconfig
    eiffel
    ejs
    elixir
    elm
    erb
    erlang
    etlua
    excelFormula # (excel-formula)
    factor
    falselang # (false)
    firestoreSecurityRules # (firestore-security-rules)
    flow
    fortran
    fsharp
    ftl
    gap
    gcode
    gdscript
    gedcom
    gettext
    gherkin
    git
    glsl
    gml
    gn
    goModule # (go-module)
    go
    gradle
    graphql
    groovy
    haml
    handlebars
    haskell
    haxe
    hcl
    hlsl
    hoon
    hpkp
    hsts
    http
    ichigojam
    icon
    icuMessageFormat # (icu-message-format)
    idris
    iecst
    ignore
    inform7
    ini
    io
    j
    java
    javadoc
    javadoclike
    javascript
    javastacktrace
    jexl
    jolie
    jq
    jsExtras # (js-extras)
    jsTemplates # (js-templates)
    jsdoc
    json
    json5
    jsonp
    jsstacktrace
    jsx
    julia
    keepalived
    keyman
    kotlin
    kumir
    kusto
    latex
    latte
    less
    lilypond
    linkerScript # (linker-script)
    liquid
    lisp
    livescript
    llvm
    log
    lolcode
    lua
    magma
    makefile
    markdown
    markupTemplating # (markup-templating)
    markup
    mata
    matlab
    maxscript
    mel
    mermaid
    metafont
    mizar
    mongodb
    monkey
    moonscript
    n1ql
    n4js
    nand2tetrisHdl # (nand2tetris-hdl)
    naniscript
    nasm
    neon
    nevod
    nginx
    nim
    nix
    none
    nsis
    objectivec
    ocaml
    odin
    opencl
    openqasm
    oz
    parigp
    parser
    pascal
    pascaligo
    pcaxis
    peoplecode
    perl
    phpExtras # (php-extras)
    php
    phpdoc
    plantUml # (plant-uml)
    plsql
    powerquery
    powershell
    processing
    prolog
    promql
    properties
    protobuf
    psl
    pug
    puppet
    pure
    purebasic
    purescript
    python
    q
    qml
    qore
    qsharp
    r
    racket
    reason
    regex
    rego
    renpy
    rescript
    rest
    rip
    roboconf
    robotframework
    ruby
    rust
    sas
    sass
    scala
    scheme
    scss
    shellSession # (shell-session)
    smali
    smalltalk
    smarty
    sml
    solidity
    solutionFile # (solution-file)
    soy
    sparql
    splunkSpl # (splunk-spl)
    sqf
    sql
    squirrel
    stan
    stata
    stylus
    supercollider
    swift
    systemd
    t4Cs # (t4-cs)
    t4Templating # (t4-templating)
    t4Vb # (t4-vb)
    tap
    tcl
    text
    textile
    toml
    tremor
    tsx
    tt2
    turtle
    twig
    typescript
    typoscript
    unrealscript
    uorazor
    uri
    v
    vala
    vbnet
    velocity
    verilog
    vhdl
    vim
    visualBasic # (visual-basic)
    warpscript
    wasm
    webIdl # (web-idl)
    wgsl
    wiki
    wolfram
    wren
    xeora
    xmlDoc # (xml-doc)
    xojo
    xquery
    yaml
    yang
    zig
}


# MARK: ADFCodeBlock Class
# Represents a code block element in the ADF structure.
class ADFCodeBlock : ADFBlockNode {

    [string] $type = 'codeBlock'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'text'
    )

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'language', [ADFCodeBlockLanguage], [string] )
    )

    ADFCodeBlock( [ADFCodeBlockLanguage] $Language ) : base() {
        $this.AddAttribute( 'language', $Language )
    }

}


# MARK: ADFCodeBlock Function
function New-ADFCodeBlock {
    <#
    .SYNOPSIS
        Creates an ADF code block node.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the code block node.
    .PARAMETER Language
        The programming language of the code block content, used for syntax highlighting.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFCodeBlock] )]
    [Alias( 'ADFCodeBlock' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [ADFCodeBlockLanguage] $Language = [ADFCodeBlockLanguage]::none
    )
    
    $Node = [ADFCodeBlock]::new( $Language )
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# ADFExpand Class
# Represents an expand element in the ADF structure.
class ADFExpand : ADFBlockNode {

    [string] $type = 'expand'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFNode]] $content = @()
    [System.Collections.Generic.List[ADFMark]] $marks = @()

    hidden static [string[]] $AllowedChildren = @(
        'bulletList', 'blockquote', 'codeBlock', 'heading', 'mediaGroup', 'mediaSingle',
        'orderedList', 'panel', 'paragraph', 'rule', 'table', 'multiBodiedExtension',
        'extensionFrame', 'nestedExpand'
    )

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'title', [string], $true )
    )

    hidden static [string[]] $AllowedMarks = @(
        'code', 'em', 'link', 'strike', 'strong', 'subsup', 'textColor',
        'underline'
    )

    ADFExpand( [string] $Title ) : base() {
        $this.AddAttribute( 'title', $Title )
    }

}


# MARK: ADFExpand Function
function New-ADFExpand {
    <#
    .SYNOPSIS
        Creates an ADF expand node.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the expand node.
    .PARAMETER Title
        The title of the expand node, displayed as the clickable text that expands or collapses the content.
    #>
    [CmdletBinding( PositionalBinding = $false, DefaultParameterSetName = 'Default' )]
    [OutputType( [ADFExpand] )]
    [Alias( 'ADFExpand' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [string] $Title
    )
    
    $Node = [ADFExpand]::new( $Title )
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFHeadingLevel Enum
# Enum to represent the allowed levels for heading elements in the ADF structure.
enum ADFHeadingLevel {
    H1 = 1
    H2 = 2
    H3 = 3
    H4 = 4
    H5 = 5
    H6 = 6
}


# MARK: ADFHeading Class
# Represents a heading element in the ADF structure.
class ADFHeading : ADFBlockNode {

    [string] $type = 'heading'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFNode]] $content = @()
    [System.Collections.Generic.List[ADFMark]] $marks = @()

    hidden static [string[]] $AllowedChildren = @(
        'date', 'emoji', 'hardBreak', 'inlineCard', 'mention', 'status', 'text', 'mediaInline'
    )

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'level', [ADFHeadingLevel], [int] )
    )

    hidden static [string[]] $AllowedMarks = @(
        'alignment'
        'indentation'
    )

    ADFHeading( [ADFHeadingLevel] $Level ) : base() {
        $this.AddAttribute( 'level', $Level )
    }

}


# MARK: ADFHeading Function
function New-ADFHeading {
    <#
    .SYNOPSIS
        Creates an ADF heading node.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the heading node.
    .PARAMETER Level
        The level of the heading, typically an integer from 1 to 6, where 1 represents the highest level (largest text) and 6 represents the lowest level (smallest text).
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFHeading] )]
    [Alias( 'ADFHeading' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [Parameter( Mandatory )]
        [ADFHeadingLevel] $Level,
        [ADFAlignment] $Align,
        [ValidateRange( 1, 6 )]
        [int] $IndentationLevel
    )
    
    $Node = [ADFHeading]::new( $Level )
    if ( $Align ) {
        $Node | Add-ADFAlignmentMark -Align $Align
    }
    if ( $IndentationLevel ) {
        $Node | Add-ADFIndentationMark -Level $IndentationLevel
    }
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFMediaGroup Class
# Represents a media group element in the ADF structure.
class ADFMediaGroup : ADFBlockNode {

    [string] $type = 'mediaGroup'
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'media'
    )

    ADFMediaGroup() : base() {}

}


# MARK: ADFMediaGroup Function
function New-ADFMediaGroup {
    <#
    .SYNOPSIS
        Creates an ADF media group node, which can contain multiple media items.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the media group node. Typically, these will be ADFMedia nodes representing individual media items within the group.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFMediaGroup] )]
    [Alias( 'ADFMediaGroup' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content
    )
    
    $Node = [ADFMediaGroup]::new()
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFMediaSingleLayout Enum
# Enum to represent the allowed layouts for media single elements in the ADF structure.
enum ADFMediaSingleLayout {
    WrapLeft   # wrap-left
    Center     # center
    WrapRight  # wrap-right
    Wide       # wide
    FullWidth  # full-width
    AlignStart # align-start
    AlignEnd   # align-end
}


# MARK: ADFMediaSingleWidthType Enum
# Enum to represent the allowed width types for media single elements in the ADF structure.
enum ADFMediaSingleWidthType {
    Undefined
    Pixel
    Percentage
}


# MARK: ADFMediaSingle Class
# Represents a media single element in the ADF structure.
class ADFMediaSingle : ADFBlockNode {

    [string] $type = 'mediaSingle'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'media'
    )

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'layout', [ADFMediaSingleLayout], [string], { ( $_.ToString() -creplace '(?<=[a-z])(?=[A-Z])', '-' ).ToLower() } ) # required
        [ADFAttributeInfo]::new( 'width', [double] )
        [ADFAttributeInfo]::new( 'widthType', [ADFMediaSingleWidthType], [string], { $_.ToString().ToLower() } )
    )

    ADFMediaSingle( [ADFMediaSingleLayout] $Layout, [double] $Width, [ADFMediaSingleWidthType] $WidthType ) : base() {
        $this.AddAttribute( 'layout', $Layout )
        $this.AddAttribute( 'width', $Width )
        $this.AddAttribute( 'widthType', $WidthType )
    }

}


# MARK: ADFMediaSingle Function
function New-ADFMediaSingle {
    <#
    .SYNOPSIS
        Creates an ADF media single node, which represents a single media item with specific layout and optional width settings.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the media single node. Typically, this will be a single ADFMedia node representing the media item.
    .PARAMETER Layout
        The layout of the media single, which determines how the media item is displayed within the document. Common layout options include 'center', 'wrap-left', 'wrap-right', and 'wide'.
    #>
    [CmdletBinding( PositionalBinding = $false, DefaultParameterSetName = 'Default' )]
    [OutputType( [ADFMediaSingle] )]
    [Alias( 'ADFMediaSingle' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [Parameter( Mandatory )]
        [ADFMediaSingleLayout] $Layout = [ADFMediaSingleLayout]::Center,
        [Parameter( ParameterSetName = 'WithWidth', Mandatory )]
        [double] $Width = 0,
        [Parameter( ParameterSetName = 'WithWidth', Mandatory )]
        [ADFMediaSingleWidthType] $WidthType = [ADFMediaSingleWidthType]::Percentage
    )

    $Node = [ADFMediaSingle]::new( $Layout, $Width, $WidthType )
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFOrdereList Class
# Represents an ordered list element in the ADF structure.
class ADFOrderedList : ADFBlockNode {

    [string] $type = 'orderedList'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'listItem'
    )

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'order', [int] )
    )

    ADFOrderedList() : base() {}

    ADFOrderedList( [int] $Order ) : base() {
        $this.AddAttribute( 'order', $Order )
    }

}


# MARK: ADFOrderedList Function
function New-ADFOrderedList {
    <#
    .SYNOPSIS
        Creates an ADF ordered list node.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the ordered list node.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFOrderedList] )]
    [Alias( 'ADFOrderedList' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [Alias( 'Start' )]
        [int] $Order = 1
    )
    
    $Node = if ( $PSBoundParameters.ContainsKey('Order') ) { [ADFOrderedList]::new( $Order ) } else { [ADFOrderedList]::new() }
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFPanelType Enum
# Enum to represent the allowed types for panel elements in the ADF structure.
enum ADFPanelType {
    Info
    Note
    Success
    Warning
    Error
}


# MARK: ADFPanel Class
# Represents a panel element in the ADF structure.
class ADFPanel : ADFBlockNode {

    [string] $type = 'panel'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'bulletList', 'heading', 'orderedList', 'paragraph'
    )

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'panelType', [ADFPanelType], [string], { $_.ToString().ToLower() } ) # required
    )

    ADFPanel( [ADFPanelType] $PanelType ) : base() {
        $this.AddAttribute( 'panelType', $PanelType )
    }

}


# MARK: ADFPanel Function
function New-ADFPanel {
    <#
    .SYNOPSIS
        Creates an ADF panel node, which is a container element used to group related content together within a visually distinct panel.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the panel node.
    .PARAMETER Type
        The type of panel, which determines the visual styling and semantics of the panel. Common types include 'info', 'note', 'tip', 'success', 'warning', and 'error'.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFPanel] )]
    [Alias( 'ADFPanel' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [Parameter( Mandatory )]
        [ADFPanelType] $Type
    )
    
    $Node = [ADFPanel]::new( $Type )
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFParagraph Class
# Represents a paragraph element in the ADF structure.
class ADFParagraph : ADFBlockNode {

    [string] $type = 'paragraph'
    [System.Collections.Generic.List[ADFNode]] $content = @()
    [System.Collections.Generic.List[ADFMark]] $marks = @()

    hidden static [string[]] $AllowedChildren = @(
        'date', 'emoji', 'hardBreak', 'inlineCard', 'mention', 'status', 'text', 'mediaInline'
    )

    hidden static [string[]] $AllowedMarks = @(
        'alignment'
        'indentation'
    )

    ADFParagraph() : base() {}

}


# MARK: ADFParagraph Function
function New-ADFParagraph {
    <#
    .SYNOPSIS
        Creates an ADF paragraph node, which is a fundamental block-level element used to structure and format text content within the document.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the paragraph node. Typically, these will be ADFText nodes representing individual pieces of text within the paragraph, but can also include other inline elements such as ADFMention or ADFStatus.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFParagraph] )]
    [Alias( 'ADFParagraph' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [ADFAlignment] $Align,
        [ValidateRange( 1, 6 )]
        [int] $IndentationLevel
    )
    
    $Node = [ADFParagraph]::new()
    if ( $Align ) {
        $Node | Add-ADFAlignmentMark -Align $Align
    }
    if ( $IndentationLevel ) {
        $Node | Add-ADFIndentationMark -Level $IndentationLevel
    }
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFRule Class
# Represents a rule element in the ADF structure.
class ADFRule : ADFBlockNode {

    [string] $type = 'rule'

    ADFRule() : base() {}

}


# MARK: ADFRule Function
function New-ADFRule {
    <#
    .SYNOPSIS
        Creates an ADF rule node, which represents a thematic break or horizontal rule used to visually separate content within the document.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFRule] )]
    [Alias( 'ADFRule' )]
    param()
    
    return [ADFRule]::new()

}


# MARK: ADFTableLayout Enum
# Enum to represent the allowed layouts for table elements in the ADF structure.
enum ADFTableLayout {
    Wide
    FullWidth
    Center
    AlignEnd
    AlignStart
    Default
}


# MARK: ADFTableDisplayMode Enum
# Enum to represent the allowed display modes for table elements in the ADF structure.
enum ADFTableDisplayMode {
    Default
    Fixed
}


# MARK: ADFTable Class
# Represents a table element in the ADF structure.
class ADFTable : ADFBlockNode {

    [string] $type = 'table'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'tableRow'
    )

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'displayMode', [ADFTableDisplayMode], [string], { $_.ToString().ToLower() } )
        [ADFAttributeInfo]::new( 'layout', [ADFTableLayout], [string], { $_.ToString() -creplace '(?<=[a-z])(?=[A-Z])', '-' | ForEach-Object ToLower } )
        [ADFAttributeInfo]::new( 'width', [UInt32] )
        [ADFAttributeInfo]::new( 'isNumberColumnEnabled', [bool], [bool] )
    )

    ADFTable() : base() {}

    ADFTable( [ADFTableDisplayMode] $DisplayMode ) : base() {
        $this.AddAttribute( 'displayMode', $DisplayMode )
    }

    ADFTable( [ADFTableLayout] $Layout ) : base() {
        $this.AddAttribute( 'layout', $Layout )
    }

    ADFTable( [ADFTableDisplayMode] $DisplayMode, [ADFTableLayout] $Layout ) : base() {
        $this.AddAttribute( 'displayMode', $DisplayMode )
        $this.AddAttribute( 'layout', $Layout )
    }

    ADFTable( [ADFTableDisplayMode] $DisplayMode, [ADFTableLayout] $Layout, [UInt32] $Width ) : base() {
        $this.AddAttribute( 'displayMode', $DisplayMode )
        $this.AddAttribute( 'layout', $Layout )
        $this.AddAttribute( 'width', $Width )
    }

    ADFTable( [ADFTableDisplayMode] $DisplayMode, [ADFTableLayout] $Layout, [UInt32] $Width, [bool] $IsNumberColumnEnabled ) : base() {
        $this.AddAttribute( 'displayMode', $DisplayMode )
        $this.AddAttribute( 'layout', $Layout )
        $this.AddAttribute( 'width', $Width )
        $this.AddAttribute( 'isNumberColumnEnabled', $IsNumberColumnEnabled )
    }

}


# MARK: ADFTable Function
function New-ADFTable {
    <#
    .SYNOPSIS
        Creates an ADF table node, which is a block-level element used to organize and display tabular data within the document.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the table node. Typically, these will be ADFTableRow nodes representing individual rows within the table, which in turn contain ADFTableCell nodes for each cell within the row.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFTable] )]
    [Alias( 'ADFTable' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [ADFTableDisplayMode] $DisplayMode,
        [ADFTableLayout] $Layout,
        [UInt32] $Width,
        [switch] $IsNumberColumnEnabled
    )
    
    $Node = [ADFTable]::new()
    if ( $PSBoundParameters.ContainsKey('DisplayMode') ) { $Node.AddAttribute( 'displayMode', $DisplayMode ) }
    if ( $PSBoundParameters.ContainsKey('Layout') ) { $Node.AddAttribute( 'layout', $Layout ) }
    if ( $PSBoundParameters.ContainsKey('Width') ) { $Node.AddAttribute( 'width', $Width ) }
    if ( $IsNumberColumnEnabled ) { $Node.AddAttribute( 'isNumberColumnEnabled', $true ) }
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ## CHILD BLOCK NODES ##


# MARK: ADFListItem Class
# Represents a list item element in the ADF structure, which can be a child of bullet list or ordered list elements.
class ADFListItem : ADFBlockNode {

    [string] $type = 'listItem'
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'bulletList', 'codeBlock', 'mediaSingle', 'orderedList', 'paragraph'
    )

    ADFListItem() : base() {}

}


# MARK: ADFListItem Function
function New-ADFListItem {
    <#
    .SYNOPSIS
        Creates an ADF list item node.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the list item node.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFListItem] )]
    [Alias( 'ADFListItem' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content
    )
    
    $Node = [ADFListItem]::new()
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFMediaType Enum
# Enum to represent the allowed types for media elements in the ADF structure.
enum ADFMediaType {
    File
    Link
}


# MARK: ADFMedia Class
# Represents a media element in the ADF structure, which can be a child of media group or media single elements.
class ADFMedia : ADFBlockNode {

    [string] $type = 'media'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFMark]] $marks = @()

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'id', [string] )                                                 # required
        [ADFAttributeInfo]::new( 'type', [ADFMediaType], [string], { $_.ToString().ToLower() } )  # required
        [ADFAttributeInfo]::new( 'collection', [string] )                                         # required
        [ADFAttributeInfo]::new( 'width', [UInt32] )                                                # required inside mediaSingle, ignored inside mediaGroup
        [ADFAttributeInfo]::new( 'height', [UInt32] )                                               # required inside mediaSingle, ignored inside mediaGroup
        [ADFAttributeInfo]::new( 'occurrenceKey', [string] )                                      # required for deletion
    )

    hidden static [string[]] $AllowedMarks = @(
        'annotation', 'border', 'link'
    )

    ADFMedia( [string] $Id, [ADFMediaType] $Type, [string] $Collection ) : base() {
        $this.AddAttribute( 'id', $Id )
        $this.AddAttribute( 'type', $Type )
        $this.AddAttribute( 'collection', $Collection )
    }
    
    ADFMedia( [string] $Id, [ADFMediaType] $Type, [string] $Collection, [UInt32] $Width, [UInt32] $Height ) : base() {
        $this.AddAttribute( 'id', $Id )
        $this.AddAttribute( 'type', $Type )
        $this.AddAttribute( 'collection', $Collection )
        $this.AddAttribute( 'width', $Width )
        $this.AddAttribute( 'height', $Height )
    }

    ADFMedia( [string] $Id, [ADFMediaType] $Type, [string] $Collection, [string] $OccurrenceKey ) : base() {
        $this.AddAttribute( 'id', $Id )
        $this.AddAttribute( 'type', $Type )
        $this.AddAttribute( 'collection', $Collection )
        $this.AddAttribute( 'occurrenceKey', $OccurrenceKey )
    }

    ADFMedia( [string] $Id, [ADFMediaType] $Type, [string] $Collection, [string] $OccurrenceKey, [UInt32] $Width, [UInt32] $Height ) : base() {
        $this.AddAttribute( 'id', $Id )
        $this.AddAttribute( 'type', $Type )
        $this.AddAttribute( 'collection', $Collection )
        $this.AddAttribute( 'occurrenceKey', $OccurrenceKey )
        $this.AddAttribute( 'width', $Width )
        $this.AddAttribute( 'height', $Height )
    }

}


# MARK: ADFMedia Function
function New-ADFMedia {
    <#
    .SYNOPSIS
        Creates an ADF media node.
    .PARAMETER Id
        Unique identifier of the media entity, used for referencing and tracking the media within the document.
    .PARAMETER Type
        The type of media, such as file or link, which determines how the media should be rendered and interacted with in the document.
    .PARAMETER Collection
        Optional collection or category that the media belongs to, can be used for organizing media within the document.
    .PARAMETER Width
        Optional width of the media in pixels, required when the media is a single item (mediaSingle) to ensure proper rendering and layout.
    .PARAMETER Height
        Optional height of the media in pixels, required when the media is a single item (mediaSingle) to ensure proper rendering and layout.
    .PARAMETER OccurrenceKey
        Optional unique key for tracking occurrences of the media, useful for analytics or media management purposes, especially when handling deletions or updates to the media.
    #>
    [CmdletBinding( PositionalBinding = $false, DefaultParameterSetName = 'Default' )]
    [OutputType( [ADFMedia] )]
    [Alias( 'ADFMedia' )]
    param(
        [Parameter( Mandatory )]
        [string] $Id,
        [Parameter( Mandatory )]
        [ADFMediaType] $Type,
        [Parameter( Mandatory )]
        [string] $Collection,
        [UInt32] $Width,
        [UInt32] $Height,
        [string] $OccurrenceKey,
        [Parameter( ParameterSetName = 'Link', Mandatory )]
        [uri] $LinkHref,
        [Parameter( ParameterSetName = 'Link' )]
        [string] $LinkTitle,
        [Parameter( ParameterSetName = 'Link' )]
        [string] $LinkId,
        [Parameter( ParameterSetName = 'Link' )]
        [string] $LinkCollection,
        [Parameter( ParameterSetName = 'Link' )]
        [string] $LinkOccurrenceKey
    )

    $Node = [ADFMedia]::new( $Id, $Type, $Collection )
    if ( $PSBoundParameters.ContainsKey('Width') ) { $Node.AddAttribute( 'width', $Width ) }
    if ( $PSBoundParameters.ContainsKey('Height') ) { $Node.AddAttribute( 'height', $Height ) }
    if ( $PSBoundParameters.ContainsKey('OccurrenceKey') ) { $Node.AddAttribute( 'occurrenceKey', $OccurrenceKey ) }
    if ( $PSBoundParameters.ContainsKey('LinkHref') ) {
        $LinkMark = [ADFLinkMark]::new( $LinkHref )
        if ( $PSBoundParameters.ContainsKey('LinkTitle') ) { $LinkMark.AddAttribute( 'title', $LinkTitle ) }
        if ( $PSBoundParameters.ContainsKey('LinkId') ) { $LinkMark.AddAttribute( 'id', $LinkId ) }
        if ( $PSBoundParameters.ContainsKey('LinkCollection') ) { $LinkMark.AddAttribute( 'collection', $LinkCollection ) }
        if ( $PSBoundParameters.ContainsKey('LinkOccurrenceKey') ) { $LinkMark.AddAttribute( 'occurrenceKey', $LinkOccurrenceKey ) }
        $Node.AddMark( $LinkMark )
    }
    return $Node

}


# MARK: ADFNestedExpand Class
# Represents a nested expand element in the ADF structure, which can be a child of an expand element.
class ADFNestedExpand : ADFExpand {

    [string] $type = 'nestedExpand'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'paragraph', 'heading', 'mediaGroup', 'mediaSingle'
    )

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'title', [string] )
    )

    ADFNestedExpand() : base() {}

    ADFNestedExpand( [string] $Title ) : base() {
        $this.AddAttribute( 'title', $Title )
    }

}


# MARK: ADFNestedExpand Function
function New-ADFNestedExpand {
    <#
    .SYNOPSIS
        Creates an ADF nested expand node, which is a specialized type of expand node that can be nested within other expand nodes to create multi-level expandable content.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the nested expand node
    .PARAMETER Title
        The title of the nested expand node, displayed as the clickable text that expands or collapses the content of the nested expand. This allows for better organization and readability when dealing with complex or lengthy content that can be expanded or collapsed by the user.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFNestedExpand] )]
    [Alias( 'ADFNestedExpand' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [string] $Title
    )

    $Node = if ( $PSBoundParameters.ContainsKey('Title') ) { [ADFNestedExpand]::new( $Title ) } else { [ADFNestedExpand]::new() }
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK ADFTableCell Class
# Represents a table cell element in the ADF structure, which can be a child of a table row element.
class ADFTableCell : ADFBlockNode {

    [string] $type = 'tableCell'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'blockquote', 'bulletList', 'codeBlock', 'heading', 'mediaGroup', 'nestedExpand',
        'orderedList', 'panel', 'paragraph', 'rule'
    )

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'background', [string] )
        [ADFAttributeInfo]::new( 'colspan', [UInt32] )
        [ADFAttributeInfo]::new( 'colwidth', [UInt32[]] )
        [ADFAttributeInfo]::new( 'rowspan', [UInt32] )
    )

    ADFTableCell() : base() {}

    ADFTableCell( [string] $Background, [UInt32] $Colspan, [UInt32[]] $Colwidth, [UInt32] $Rowspan ) : base() {
        $this.AddAttribute( 'background', $Background )
        $this.AddAttribute( 'colspan', $Colspan )
        $this.AddAttribute( 'colwidth', $Colwidth )
        $this.AddAttribute( 'rowspan', $Rowspan )
    }

}


# MARK: ADFTableCell Function
function New-ADFTableCell {
    <#
    .SYNOPSIS
        Creates an ADF table cell node, which represents an individual cell within a table row in the ADF structure.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the table cell node. This can include various block-level elements such as paragraphs, headings, lists, and media groups to structure the content within the cell.
    .PARAMETER Background
        Optional background color for the table cell, specified as a string (e.g., hex code or color name), which can be used to visually differentiate cells within the table.
    .PARAMETER Colspan
        Optional number of columns that the cell should span across, allowing for the creation of merged cells that extend horizontally across multiple columns in the table.
    .PARAMETER Colwidth
        Optional array of widths for each column that the cell spans across, specified in pixels or percentages, which can be used to control the layout and appearance of the table.
    .PARAMETER Rowspan
        Optional number of rows that the cell should span across, allowing for the creation of merged cells that extend vertically across multiple rows in the table.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFTableCell] )]
    [Alias( 'ADFTableCell' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [string] $Background,
        [UInt32] $Colspan,
        [UInt32[]] $Colwidth,
        [UInt32] $Rowspan
    )

    $Node = [ADFTableCell]::new()
    if ( $PSBoundParameters.ContainsKey('Background') ) { $Node.AddAttribute( 'background', $Background ) }
    if ( $PSBoundParameters.ContainsKey('Colspan') ) { $Node.AddAttribute( 'colspan', $Colspan ) }
    if ( $PSBoundParameters.ContainsKey('Colwidth') ) { $Node.AddAttribute( 'colwidth', $Colwidth ) }
    if ( $PSBoundParameters.ContainsKey('Rowspan') ) { $Node.AddAttribute( 'rowspan', $Rowspan ) }
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}

# MARK: ADFTableHeader Class
# Represents a table header cell element in the ADF structure, which can be a child of a table row element.
class ADFTableHeader : ADFTableCell {

    [string] $type = 'tableHeader'
    [hashtable] $attrs = @{}
    [System.Collections.Generic.List[ADFNode]] $content = @()

    ADFTableHeader() : base() {}

    ADFTableHeader( [string] $Background, [UInt32] $Colspan, [UInt32[]] $Colwidth, [UInt32] $Rowspan ) : base( $Background, $Colspan, $Colwidth, $Rowspan ) {}

}


# MARK: ADFTableHeader Function
function New-ADFTableHeader {
    <#
    .SYNOPSIS
        Creates an ADF table header cell node, which represents a header cell within a table row in the ADF structure, typically used to define column headers or row headers in a table.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the table header cell node. This can include various block-level elements such as paragraphs, headings, lists, and media groups to structure the content within the header cell.
    .PARAMETER Background
        Optional background color for the table header cell, specified as a string (e.g., hex code or color name), which can be used to visually differentiate header cells from regular cells within the table.
    .PARAMETER Colspan
        Optional number of columns that the header cell should span across, allowing for the creation of merged header cells that extend horizontally across multiple columns in the table.
    .PARAMETER Colwidth
        Optional array of widths for each column that the header cell spans across, specified in pixels or percentages, which can be used to control the layout and appearance of the table.
    .PARAMETER Rowspan
        Optional number of rows that the header cell should span across, allowing for the creation of merged header cells that extend vertically across multiple rows in the table.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFTableHeader] )]
    [Alias( 'ADFTableHeader' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content,
        [string] $Background,
        [UInt32] $Colspan,
        [UInt32[]] $Colwidth,
        [UInt32] $Rowspan
    )

    $Node = [ADFTableHeader]::new()
    if ( $PSBoundParameters.ContainsKey('Background') ) { $Node.AddAttribute( 'background', $Background ) }
    if ( $PSBoundParameters.ContainsKey('Colspan') ) { $Node.AddAttribute( 'colspan', $Colspan ) }
    if ( $PSBoundParameters.ContainsKey('Colwidth') ) { $Node.AddAttribute( 'colwidth', $Colwidth ) }
    if ( $PSBoundParameters.ContainsKey('Rowspan') ) { $Node.AddAttribute( 'rowspan', $Rowspan ) }
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ADFTableRow Class
# Represents a table row element in the ADF structure, which can be a child of a table element and can contain table cell and table header elements.
class ADFTableRow : ADFBlockNode {

    [string] $type = 'tableRow'
    [System.Collections.Generic.List[ADFNode]] $content = @()

    hidden static [string[]] $AllowedChildren = @(
        'tableCell', 'tableHeader'
    )

    ADFTableRow() : base() {}

}


# MARK: ADFTableRow Function
function New-ADFTableRow {
    <#
    .SYNOPSIS
        Creates an ADF table row node, which represents a single row within a table in the ADF structure.
    .PARAMETER Content
        Scriptblock whose output ADFNode objects will be added as children of the table row node. Typically, these will be ADFTableCell and ADFTableHeader nodes representing individual cells within the row, which can contain various block-level elements to structure the content within each cell.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFTableRow] )]
    [Alias( 'ADFTableRow' )]
    param(
        [Parameter( Position = 0 )]
        [scriptblock] $Content
    )

    $Node = [ADFTableRow]::new()
    if ( $Content ) {
        & $Content | ForEach-Object { $Node.AddChild( $_ ) }
    }
    return $Node

}


# MARK: ## INLINE NODES ##


# MARK: ADFDate Class
# Represents a date element in the ADF structure, which can be a child of paragraph or heading elements.
class ADFDate : ADFInlineNode {

    [string] $type = 'date'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'timestamp', [DateTime], [Int64], { [System.DateTimeOffset]::new( $_ ).ToUnixTimeSeconds() } )
    )

    ADFDate() : base() {}

    ADFDate( [DateTime] $Timestamp ) : base() {
        $this.AddAttribute( 'timestamp', $Timestamp )
    }

}


# MARK: ADFDate Function
function New-ADFDate {
    <#
    .SYNOPSIS
        Creates an ADF date node.
    .PARAMETER Timestamp
        The date and time value to be represented by the date node.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFDate] )]
    [Alias( 'ADFDate' )]
    param(
        [DateTime] $Timestamp
    )
    
    return [ADFDate]::new( $Timestamp )

}


# MARK: ADFEmoji Class
# Represents an emoji element in the ADF structure, which can be a child of paragraph or heading elements.
class ADFEmoji : ADFInlineNode {

    [string] $type = 'emoji'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'shortName', [string] )   # required
        [ADFAttributeInfo]::new( 'id', [string] )          # optional, service ID of the emoji
        [ADFAttributeInfo]::new( 'text', [string] )        # optional, fallback text to display if the emoji cannot be rendered, defaults to the shortName
    )

    ADFEmoji( [string] $ShortName ) : base() {
        $this.AddAttribute( 'shortName', $ShortName )
    }

    ADFEmoji( [string] $ShortName, [string] $Text ) : base() {
        $this.AddAttribute( 'shortName', $ShortName )
        $this.AddAttribute( 'text', $Text )
    }
    
    ADFEmoji( [string] $ShortName, [string] $Text, [string] $Id ) : base() {
        $this.AddAttribute( 'shortName', $ShortName )
        $this.AddAttribute( 'text', $Text )
        $this.AddAttribute( 'id', $Id )
    }

}


# MARK: ADFEmoji Function
function New-ADFEmoji {
    <#
    .SYNOPSIS
        Creates an ADF emoji node.
    .PARAMETER ShortName
        The short name of the emoji, typically in the format :emoji_name: (e.g., :smile:).
    .PARAMETER Text
        Optional text to display for the emoji, used as a fallback if the emoji cannot be rendered. Defaults to the short name if not provided.
    .PARAMETER Id
        Optional service ID of the emoji, used for tracking or referencing the emoji within the document.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFEmoji] )]
    [Alias( 'ADFEmoji' )]
    param(
        [Parameter( Mandatory )]
        [string] $ShortName,
        [string] $Text,
        [string] $Id
    )
    
    if ( $PSBoundParameters.ContainsKey('Id') -and $PSBoundParameters.ContainsKey('Text') ) {
        return [ADFEmoji]::new( $ShortName, $Text, $Id )
    }
    elseif ( $PSBoundParameters.ContainsKey('Text') ) {
        return [ADFEmoji]::new( $ShortName, $Text )
    }
    else {
        return [ADFEmoji]::new( $ShortName )
    }

}


# MARK: ADFHardBreak Class
# Represents a hard break element in the ADF structure, which can be a child of paragraph or heading elements.
class ADFHardBreak : ADFInlineNode {

    [string] $type = 'hardBreak'

    # NOTE: Technically the hardBreak supports a text attribute, but it only allows the default value '\n'
    # NOTE: so it is not implemented here, as it is not useful for any practical purpose.
    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @()

    ADFHardBreak() : base() {}

}


# MARK: ADFHardBreak Function
function New-ADFHardBreak {
    <#
    .SYNOPSIS
        Creates an ADF hard break node.
    .PARAMETER Text
        Optional text to display for the hard break, used as a fallback if the hard break cannot be rendered. Defaults to a newline character if not provided.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFHardBreak] )]
    [Alias( 'ADFHardBreak' )]
    param()

    return [ADFHardBreak]::new()

}


# MARK: ADFInlineCard Class
# Represents an inline card element in the ADF structure, which can be a child of paragraph or heading elements.
class ADFInlineCard : ADFInlineNode {

    [string] $type = 'inlineCard'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'url', [uri], [string] )
        [ADFAttributeInfo]::new( 'data', [string], [object], { ConvertFrom-Json -InputObject $_ -Depth 5 -ErrorAction Stop } ) # JSONLD representation
    )

    ADFInlineCard( [uri] $Url ) : base() {
        $this.AddAttribute( 'url', $Url )
    }

    ADFInlineCard( [string] $Data ) : base() {
        $this.AddAttribute( 'data', $Data )
    }

}


# MARK: ADFInlineCard Function
function New-ADFInlineCard {
    <#
    .SYNOPSIS
        Creates an ADF inline card node.
    .PARAMETER Url
        The URL that the inline card points to, making the card clickable and directing users to the specified URL when clicked.
    .PARAMETER Data
        JSONLD representation of the data to be displayed in the inline card, allowing for rich content and metadata to be included in the card.
    #>
    [CmdletBinding( PositionalBinding = $false, DefaultParameterSetName = 'Url' )]
    [OutputType( [ADFInlineCard] )]
    [Alias( 'ADFInlineCard' )]
    param(
        [Parameter( ParameterSetName = 'Url', Mandatory )]
        [uri] $Url,
        [Parameter( ParameterSetName = 'Data', Mandatory )]
        [string] $Data
    )
    
    $Node = if ( $PSBoundParameters.ContainsKey('Url') ) { [ADFInlineCard]::new( $Url ) } else { [ADFInlineCard]::new( $Data ) }
    return $Node

}


# MARK: ADFMentionAccessLevel Enum
# Enum to represent the allowed access levels for mention elements in the ADF structure.
enum ADFMentionAccessLevel {
    None
    Site
    Application
    Container
}


# MARK: ADFMentionUserType Enum
# Enum to represent the allowed user types for mention elements in the ADF structure.
enum ADFMentionUserType {
    Default
    Special
    App
}


# MARK: ADFMention Class
# Represents a mention element in the ADF structure, which can be a child of paragraph or heading elements.
class ADFMention : ADFInlineNode {

    [string] $type = 'mention'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'id', [string] )                                                                 # required, unique identifier of the mentioned entity
        [ADFAttributeInfo]::new( 'text', [string] )                                                               # optional, text to display for the mention, defaults to the id
        [ADFAttributeInfo]::new( 'accessLevel', [ADFMentionAccessLevel], [string], { $_.ToString().ToUpper() } )  # optional, access level of the mentioned entity
        [ADFAttributeInfo]::new( 'userType', [ADFMentionUserType], [string], { $_.ToString().ToUpper() } )        # optional, user type of the mentioned entity
    )

    ADFMention( [string] $Id ) : base() {
        $this.AddAttribute( 'id', $Id )
    }

    ADFMention( [string] $Id, [string] $Text ) : base() {
        $this.AddAttribute( 'id', $Id )
        $this.AddAttribute( 'text', $Text )
    }

    ADFMention( [string] $Id, [string] $Text, [ADFMentionAccessLevel] $AccessLevel, [ADFMentionUserType] $UserType ) : base() {
        $this.AddAttribute( 'id', $Id )
        $this.AddAttribute( 'text', $Text )
        $this.AddAttribute( 'accessLevel', $AccessLevel )
        $this.AddAttribute( 'userType', $UserType )
    }

}


# MARK: ADFMention Function
function New-ADFMention {
    <#
    .SYNOPSIS
        Creates an ADF mention node.
    .PARAMETER Id
        Unique identifier of the mentioned entity, used for referencing and tracking the mention within the document.
    .PARAMETER Text
        Optional text to display for the mention, used as a fallback if the mention cannot be rendered. Defaults to the id if not provided.
    .PARAMETER AccessLevel
        Optional access level of the mentioned entity, which can be used to control visibility or permissions related to the mention. Defaults to None if not provided.
    .PARAMETER UserType
        Optional user type of the mentioned entity, which can be used to categorize mentions based on user roles or types. Defaults to Default if not provided.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFMention] )]
    [Alias( 'ADFMention' )]
    param(
        [Parameter( Mandatory )]
        [string] $Id,
        [string] $Text,
        [ADFMentionAccessLevel] $AccessLevel,
        [ADFMentionUserType] $UserType
    )

    $Node = [ADFMention]::new( $Id )
    if ( $PSBoundParameters.ContainsKey('Text') ) { $Node.AddAttribute( 'text', $Text ) }
    if ( $PSBoundParameters.ContainsKey('AccessLevel') ) { $Node.AddAttribute( 'accessLevel', $AccessLevel ) }
    if ( $PSBoundParameters.ContainsKey('UserType') ) { $Node.AddAttribute( 'userType', $UserType ) }
    return $Node

}


# MARK: ADFStatusColor Enum
# Enum to represent the allowed colors for status elements in the ADF structure.
enum ADFStatusColor {
    Neutral
    Purple
    Blue
    Red
    Yellow
    Green
}


# MARK: ADFStatus Class
# Represents a status element in the ADF structure, which can be a child of paragraph or heading elements.
class ADFStatus : ADFInlineNode {

    [string] $type = 'status'
    [hashtable] $attrs = @{}

    hidden static [ADFAttributeInfo[]] $AllowedAttributes = @(
        [ADFAttributeInfo]::new( 'text', [string] )                                                               # required, text to display for the status
        [ADFAttributeInfo]::new( 'color', [ADFStatusColor], [string], { $_.ToString().ToLower() } )               # required, color of the status, defaults to Neutral
    )

    ADFStatus( [string] $Text ) : base() {
        $this.AddAttribute( 'text', $Text )
        $this.AddAttribute( 'color', [ADFStatusColor]::Neutral )
    }

    ADFStatus( [string] $Text, [ADFStatusColor] $Color ) : base() {
        $this.AddAttribute( 'text', $Text )
        $this.AddAttribute( 'color', $Color )
    }

}


# MARK: ADFStatus Function
function New-ADFStatus {
    <#
    .SYNOPSIS
        Creates an ADF status node, which is an inline element used to display a status or label with specific text and color.
    .PARAMETER Text
        The text to display for the status, which provides a description or label for the status being represented.
    .PARAMETER Color
        The color of the status, which can be used to visually differentiate between different statuses. Common color options include 'neutral', 'purple', 'blue', 'red', 'yellow', and 'green'.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    [OutputType( [ADFStatus] )]
    [Alias( 'ADFStatus' )]
    param(
        [Parameter( Mandatory )]
        [string] $Text,
        [ADFStatusColor] $Color = [ADFStatusColor]::Neutral
    )
    
    return [ADFStatus]::new( $Text, $Color )

}


# MARK: ADFText Class
# Represents a text element in the ADF structure, which can be a child of paragraph or heading elements.
class ADFText : ADFInlineNode {

    [string] $type = 'text'
    [string] $text = ''
    [System.Collections.Generic.List[ADFMark]] $marks = @()

    hidden static [string[]] $AllowedMarks = @(
        'annotation', 'backgroundColor', 'code', 'em', 'link', 'strike',
        'strong', 'subsup', 'textColor', 'underline'
    )

    ADFText( [object] $Object ) : base() {
        $this.Text = $Object
    }

}


# MARK: ADFText Function
function New-ADFText {
    <#
    .SYNOPSIS
        Creates an ADF text node, which represents a piece of text content within a paragraph or heading in the ADF structure.
    .PARAMETER Text
        The text content to be represented by the ADF text node. This can be a string or any object that can be converted to a string, such as numbers or other data types.
    #>
    [CmdletBinding( PositionalBinding = $false,  DefaultParameterSetName = 'Default' )]
    [OutputType( [ADFText] )]
    [Alias( 'ADFText' )]
    param(
        [Parameter( Position = 0, Mandatory )]
        [object] $Text,
        [switch] $Code,
        [switch] $Em,
        [switch] $Strike,
        [switch] $Strong,
        [ADFSubsupMarkType] $SubsupType,
        [string] $TextColor,
        [switch] $Underline,
        [Parameter( ParameterSetName = 'Link', Mandatory )]
        [uri] $LinkHref,
        [Parameter( ParameterSetName = 'Link' )]
        [string] $LinkTitle,
        [Parameter( ParameterSetName = 'Link' )]
        [string] $LinkId,
        [Parameter( ParameterSetName = 'Link' )]
        [string] $LinkCollection,
        [Parameter( ParameterSetName = 'Link' )]
        [string] $LinkOccurrenceKey
    )

    $Node = [ADFText]::new( $Text )
    if ( $Code ) { $Node.AddMark( [ADFCodeMark]::new() ) }
    if ( $Em ) { $Node.AddMark( [ADFEmMark]::new() ) }
    if ( $Strike ) { $Node.AddMark( [ADFStrikeMark]::new() ) }
    if ( $Strong ) { $Node.AddMark( [ADFStrongMark]::new() ) }
    if ( $SubsupType ) { $Node.AddMark( [ADFSubSupMark]::new( $SubsupType ) ) }
    if ( $TextColor ) { $Node.AddMark( [ADFTextColorMark]::new( $TextColor ) ) }
    if ( $Underline ) { $Node.AddMark( [ADFUnderlineMark]::new() ) }
    if ( $PSBoundParameters.ContainsKey('LinkHref') ) {
        $LinkMark = [ADFLinkMark]::new( $LinkHref )
        if ( $PSBoundParameters.ContainsKey('LinkTitle') ) { $LinkMark.AddAttribute( 'title', $LinkTitle ) }
        if ( $PSBoundParameters.ContainsKey('LinkId') ) { $LinkMark.AddAttribute( 'id', $LinkId ) }
        if ( $PSBoundParameters.ContainsKey('LinkCollection') ) { $LinkMark.AddAttribute( 'collection', $LinkCollection ) }
        if ( $PSBoundParameters.ContainsKey('LinkOccurrenceKey') ) { $LinkMark.AddAttribute( 'occurrenceKey', $LinkOccurrenceKey ) }
        $Node.AddMark( $LinkMark )
    }
    
    return $Node

}



# MARK: Get-ADFDocumentNode Function
function Get-ADFDocumentNode {
    <#
    .SYNOPSIS
        Retrieves nodes from an ADF document structure.
    .DESCRIPTION
        This function extracts nodes from an ADF structure and returns them. It crawls the document tree and
        collects all nodes of the given type. It can optionally return the text elements of the nodes
        instead of the full node objects.
    .PARAMETER RootNode
        The root node of the ADF document from which to start the search. This should be an object of type ADFNode.
    .PARAMETER NodeType
        The type of nodes to retrieve from the ADF document. This should be a string representing the node type.
    .PARAMETER MaxDepth
        An optional parameter that specifies the maximum depth to which the function should search for nodes. If not
        specified, the function will search through the entire document tree.
    .PARAMETER ExtractText
        A switch parameter that, when specified, indicates that only the text content of the nodes should be
        returned, rather than the full node objects.
    #>
    [CmdletBinding( PositionalBinding = $false )]
    param(
        [Parameter( Mandatory, ValueFromPipeline )]
        [ADFNode] $RootNode,
        [ValidateSet( 'doc', 'paragraph', 'heading', 'mediaGroup', 'mediaSingle', 'table', 'tableRow', 'tableCell', 'tableHeader', 'expand', 'nestedExpand', 'inlineCard', 'mention', 'status', 'text' )]
        [string] $NodeType = 'doc',
        [UInt32] $MaxDepth,
        [switch] $ExtractText
    )

    process {

        # initialize the queue for breadth-first traversal
        $queue = [System.Collections.Generic.Queue[pscustomobject]]@()

        # enqueue the root node with depth 0
        $queue.Enqueue([pscustomobject]@{ Node = $RootNode; Depth = 0; InMatch = $false })

        while ($queue.Count -gt 0) {

            $current = $queue.Dequeue()
            $node    = $current.Node
            $depth   = $current.Depth
            $inMatch = $current.InMatch

            $isMatch = $node.type -eq $NodeType
            $inMatch = $inMatch -or $isMatch

            if ( -not $ExtractText ) {

                # default behavior: return the node object if it matches the type
                if ( $isMatch ) {
                    Write-Output $node
                }

            } else {

                # if ExtractText is specified, return the text content of the node if it matches the type
                if ( $inMatch -and $node -is [ADFInlineNode] ) {

                    # date nodes
                    if ( $node -is [ADFDate] ) {
                        Write-Output [System.DateTimeOffset]::FromUnixTimeSeconds($node.attrs.timestamp).LocalDateTime.ToString('yyyy-MM-dd')
                    }

                    # emoji nodes
                    if ( $node -is [ADFEmoji] ) {
                        Write-Output $node.attrs.text
                    }

                    # hardBreak nodes
                    if ( $node -is [ADFHardBreak] ) {
                        Write-Output "`n"
                    }

                    # inlineCard nodes
                    if ( $node -is [ADFInlineCard] ) {
                        Write-Output $node.attrs.url
                    }

                    # mention nodes
                    if ( $node -is [ADFMention] ) {
                        if ( $node.attrs.text ) {
                            Write-Output $node.attrs.text
                        } else {
                            Write-Output $node.attrs.id
                        }
                    }

                    # status nodes
                    if ( $node -is [ADFStatus] ) {
                        Write-Output $node.attrs.text
                    }

                    # text nodes
                    if ( $node -is [ADFText] ) {
                        $nodeText = $node.text
                        # process formatting marks in the order they are applied, wrapping the text with the appropriate markdown syntax
                        foreach ( $mark in $node.marks ) {
                            switch ( $mark.type ) {
                                'code'           { $nodeText = '`{0}`' -f $nodeText }
                                'em'             { $nodeText = '_{0}_' -f $nodeText }
                                'strike'         { $nodeText = '~~{0}~~' -f $nodeText }
                                'strong'         { $nodeText = '**{0}**' -f $nodeText }
                                'subsup'         {
                                    if ( $mark.attrs.type -eq 'sub' ) {
                                        $nodeText = '~{0}~' -f $nodeText
                                    } else {
                                        $nodeText = '^{0}^' -f $nodeText
                                    }
                                }
                                'underline'      { $nodeText = '_{0}_' -f $nodeText }
                            }
                        }
                        # apply link mark last, so that it wraps around any other formatting
                        if ( $mark = $node.marks | Where-Object { $_.type -eq 'link' } ) {
                            if ( $mark.attrs.title ) {
                                $nodeText = "[{0}]({1} '{2}')" -f $nodeText, $mark.attrs.href, $mark.attrs.title
                            } else {
                                $nodeText = "[{0}]({1})" -f $nodeText, $mark.attrs.href
                            }
                        }
                        Write-Output $nodeText
                    }

                    # mediaInline nodes
                    if ( $node -is [ADFMedia] ) {
                        $format = '![{0}]({1})'
                        if ( $node.attrs.type -eq 'file' ) {
                            Write-Output ( $format -f $node.attrs.type, $node.attrs.id )
                        } elseif ( $node.attrs.type -eq 'link' ) {
                            Write-Output ( $format -f $node.attrs.type, $node.marks.attrs.url )
                        }
                    }

                }

            }

            # enqueue child nodes if the current depth is less than MaxDepth (if specified)
            if ( ( -not $MaxDepth -or $depth -lt $MaxDepth ) -and $node.content ) {
                foreach ( $child in $node.content ) {
                    $queue.Enqueue([pscustomobject]@{ Node = $child; Depth = $depth + 1; InMatch = $inMatch })
                }
            }

        }

    }

}