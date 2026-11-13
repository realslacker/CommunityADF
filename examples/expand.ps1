Import-Module "$PSScriptRoot\..\src\CommunityADF\CommunityADF.psd1" -Force

Write-Host 'Basic Expand Example' -ForegroundColor Cyan

ADFDoc {
    ADFExpand -Title 'More details' {
        ADFParagraph {
            ADFText 'This content is hidden until the user expands the section.'
        }
    }
} | ConvertTo-Json -Depth 100
