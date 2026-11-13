Import-Module "$PSScriptRoot\..\src\CommunityADF\CommunityADF.psd1" -Force

Write-Host 'Basic Bullet List Example' -ForegroundColor Cyan

ADFDoc {
    ADFBulletList {
        ADFListItem {
            ADFParagraph {
                ADFText 'First item'
            }
        }
        ADFListItem {
            ADFParagraph {
                ADFText 'Second item'
            }
        }
        ADFListItem {
            ADFParagraph {
                ADFText 'Third item'
            }
        }
    }
} | ConvertTo-Json -Depth 100
