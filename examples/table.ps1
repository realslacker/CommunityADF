Import-Module "$PSScriptRoot\..\src\CommunityADF.psd1" -Force

Write-Host 'Basic Table Example' -ForegroundColor Cyan

ADFDoc {
    ADFTable -DisplayMode Default -Layout Center -Width 600 {
        ADFTableRow {
            ADFTableHeader {
                ADFParagraph {
                    ADFText 'Name'
                }
            }
            ADFTableHeader {
                ADFParagraph {
                    ADFText 'Role'
                }
            }
        }
        ADFTableRow {
            ADFTableCell {
                ADFParagraph {
                    ADFText 'Alice'
                }
            }
            ADFTableCell {
                ADFParagraph {
                    ADFText 'Developer'
                }
            }
        }
        ADFTableRow {
            ADFTableCell {
                ADFParagraph {
                    ADFText 'Bob'
                }
            }
            ADFTableCell {
                ADFParagraph {
                    ADFText 'Designer'
                }
            }
        }
    }
} | ConvertTo-Json -Depth 100
