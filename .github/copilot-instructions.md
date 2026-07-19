# Copilot Instructions for CommunityADF

## Project Context
- This repository is a PowerShell module project.
- Main module file: `src/CommunityADF.psm1`.
- Custom PSScriptAnalyzer rules are in `rules/`.
- Analyzer configuration is in `PSScriptAnalyzerSettings.psd1`.

## Coding Preferences
- Prefer clear, production-ready PowerShell over quick scripts.
- Use advanced functions with `[CmdletBinding()]` for exported commands.
- Follow approved PowerShell verb naming conventions.
- Use parameter validation attributes when appropriate.
- Include comment-based help for public functions (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`).
- Keep functions focused and composable; avoid large monolithic functions.

## Style and Safety
- Respect existing formatting and naming patterns in this repository.
- Avoid breaking public function signatures unless explicitly requested.
- Prefer non-destructive behavior by default.
- For commands that change state, support `-WhatIf` / `-Confirm` when appropriate.
- Handle errors with actionable messages and use terminating errors where failure should stop execution.

## Validation and Quality
- Align with rules in `PSScriptAnalyzerSettings.psd1` and custom rules in `rules/`.
- Prefer changes that pass PSScriptAnalyzer cleanly.
- When adding or refactoring logic, suggest or add tests where practical.

## Change Discipline
- Make minimal, targeted edits.
- Do not refactor unrelated code.
- Preserve backward compatibility unless a breaking change is explicitly requested.
- Document assumptions when requirements are ambiguous.
