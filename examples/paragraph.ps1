Import-Module "$PSScriptRoot\..\src\CommunityADF\CommunityADF.psd1" -Force

Write-Host 'Basic Paragraph Example' -ForegroundColor Cyan

ADFDoc {
    ADFParagraph {
        ADFText 'This is a simple paragraph in an ADF document.'
    }
} | ConvertTo-Json -Depth 100
