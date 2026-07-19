Import-Module "$PSScriptRoot\..\src\CommunityADF.psd1" -Force

Write-Host 'Heading Example' -ForegroundColor Cyan

ADFDoc {
    ADFHeading -Level H1 {
        ADFText 'Welcome to CommunityADF'
    }
    ADFParagraph {
        ADFText 'This is an example of a heading in an ADF document.'
    }
    ADFHeading -Level H2 {
        ADFText 'Getting Started'
    }
    ADFParagraph {
        ADFText 'To get started, you can use the provided cmdlets to create various ADF elements.'
    }
} | ConvertTo-Json -Depth 100
