Import-Module "$PSScriptRoot\..\src\CommunityADF.psd1" -Force

Write-Host 'Basic Ordered List Example' -ForegroundColor Cyan

ADFDoc {
    ADFOrderedList -Order 1 {
        ADFListItem {
            ADFParagraph {
                ADFText 'Install the module'
            }
        }
        ADFListItem {
            ADFParagraph {
                ADFText 'Import the module'
            }
        }
        ADFListItem {
            ADFParagraph {
                ADFText 'Start building ADF documents'
            }
        }
    }
} | ConvertTo-Json -Depth 100
