Import-Module "$PSScriptRoot\..\src\CommunityADF.psd1" -Force

Write-Host 'Basic Code Block Example' -ForegroundColor Cyan

ADFDoc {
    ADFCodeBlock -Language PowerShell {
        ADFText 'Write-Host "Hello from CommunityADF"'
    }
} | ConvertTo-Json -Depth 100
