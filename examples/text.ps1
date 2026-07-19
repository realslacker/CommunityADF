Import-Module "$PSScriptRoot\..\src\CommunityADF.psd1" -Force

Write-Host 'Text Mark Examples' -ForegroundColor Cyan

Write-Host 'Basic styling marks' -ForegroundColor DarkCyan
ADFDoc {
    ADFParagraph {
        ADFText -Text 'This is ' 
        ADFText -Text 'strong' -Strong
        ADFText -Text ', ' 
        ADFText -Text 'emphasized' -Em
        ADFText -Text ', ' 
        ADFText -Text 'underlined' -Underline
        ADFText -Text ', and ' 
        ADFText -Text 'struck through' -Strike
        ADFText -Text '.'
    }
} | ConvertTo-Json -Depth 100

Write-Host 'Code, color, and combined formatting' -ForegroundColor DarkCyan
ADFDoc {
    ADFParagraph {
        ADFText -Text 'Run: ' 
        ADFText -Text 'Get-Process' -Code -TextColor '#0078D4'
        ADFText -Text ' to inspect running services.'
    }
} | ConvertTo-Json -Depth 100

Write-Host 'Link and subscript/superscript' -ForegroundColor DarkCyan
ADFDoc {
    ADFParagraph {
        ADFText -Text 'The value is ' 
        ADFText -Text '10' -SubsupType Superscript
        ADFText -Text ' and ' 
        ADFText -Text 'H2O' -SubsupType Subscript
        ADFText -Text ', with a ' 
        ADFText -Text 'documentation link' -LinkHref 'https://learn.microsoft.com/powershell' -LinkTitle 'PowerShell docs'
        ADFText -Text '.'
    }
} | ConvertTo-Json -Depth 100

Write-Host 'Multiple marks on one text node' -ForegroundColor DarkCyan
ADFDoc {
    ADFParagraph {
        ADFText -Text 'This text is bold, colored, and linked.' -Strong -TextColor '#C50F1F' -LinkHref 'https://github.com' -LinkTitle 'GitHub' -LinkId 'github-link'
    }
} | ConvertTo-Json -Depth 100
