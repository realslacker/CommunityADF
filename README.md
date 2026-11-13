# CommunityADF

CommunityADF is a PowerShell DSL for building Atlassian Document Format (ADF) JSON documents. It gives you a fluent, object-oriented way to compose rich text, headings, paragraphs, lists, tables, panels, and other document content in PowerShell.

## Features

- Build ADF documents with PowerShell functions and classes
- Compose structured content with a friendly DSL
- Produce JSON compatible with Atlassian document rendering tools
- Includes examples for common document patterns
- Designed for PowerShell 5.1+

## Repository layout

- `src/CommunityADF.psd1` - module manifest
- `src/CommunityADF.psm1` - module implementation
- `examples/` - sample PowerShell scripts demonstrating usage
- `tests/` - test area

## Installation

From the repository root:

```powershell
Import-Module .\src\CommunityADF\CommunityADF.psd1 -Force
```

If you want to load the module from elsewhere, use the module path directly:

```powershell
Import-Module "C:\path\to\CommunityADF\src\CommunityADF\CommunityADF.psd1" -Force
```

## Quick start

```powershell
Import-Module .\src\CommunityADF\CommunityADF.psd1 -Force

ADFDoc {
    ADFParagraph {
        ADFText -Text 'Hello from ' 
        ADFText -Text 'CommunityADF' -Strong
        ADFText -Text '!'
    }
} | ConvertTo-Json -Depth 100
```

This produces ADF JSON similar to:

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [
        { "type": "text", "text": "Hello from " },
        { "type": "text", "text": "CommunityADF", "marks": [{ "type": "strong" }] },
        { "type": "text", "text": "!" }
      ]
    }
  ]
}
```

## Common patterns

The `examples/` folder contains working samples for:

- text formatting
- headings
- paragraphs
- block quotes
- bullets and numbered lists
- code blocks
- expand/collapse panels
- tables

Examples can be run directly with PowerShell:

```powershell
. .\examples\text.ps1
```

## Example: styled text

```powershell
ADFDoc {
    ADFParagraph {
        ADFText -Text 'Run: ' -Strong -TextColor '#0078D4'
        ADFText -Text 'Get-Process' -Code
        ADFText -Text ' to inspect running services.'
    }
} | ConvertTo-Json -Depth 100
```

## Notes

This module is intended for building ADF payloads for Atlassian ecosystem integrations and document generation workflows. It emphasizes a readable PowerShell-first DSL while producing standards-based JSON.

## License

This project is currently distributed under the repository's default license terms. See the repository for additional licensing details.
