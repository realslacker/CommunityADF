Import-Module "$PSScriptRoot\..\src\CommunityADF.psd1" -Force

Write-Host 'Basic Panel Example' -ForegroundColor Cyan

ADFDoc {
    ADFPanel -Type Info {
        ADFParagraph {
            ADFText 'This is an informational panel.'
        }
    }
} | ConvertTo-Json -Depth 100
