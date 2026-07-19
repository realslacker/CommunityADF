Import-Module "$PSScriptRoot\..\src\CommunityADF.psd1" -Force

Write-Host 'Basic Blockquote Example' -ForegroundColor Cyan

ADFDoc {
    ADFBlockQuote {
        ADFParagraph {
            ADFText 'This is a blockquote.'
        }
    }
} | ConvertTo-Json -Depth 100

Write-Host 'Blockquote with Bullet List Example' -ForegroundColor Cyan

ADFDoc {
    ADFBlockQuote {
        ADFParagraph {
            ADFText 'This is a blockquote with a bullet list.'
        }
        ADFBulletList {
            ADFListItem {
                ADFParagraph {
                    ADFText 'Bullet 1'
                }
            }
            ADFListItem {
                ADFParagraph {
                    ADFText 'Bullet 2'
                }
            }
        }
    }
} | ConvertTo-Json -Depth 100