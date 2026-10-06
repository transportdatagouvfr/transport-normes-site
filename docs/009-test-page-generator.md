# 009: Test Page Generator Mix Task

## What to build

A new mix task (`mix test.page`) that generates `_site/test.html` — a visual regression page containing sample markdown snippets, one per transform, with all transforms applied. This is a developer tool for visually verifying changes in a browser without running the full build pipeline.

The test page renders:
- A section for each AST transform plugin (Navigation, DSFR) showing sample markdown and its rendered output
- Sample table rendering (to verify `fr-table` wrapping)
- Sample code blocks with various languages (XSD, XML, etc.) to verify syntax highlighting
- Sample blockquotes to verify callout conversion
- Sample headings at multiple levels to verify ID generation and TOC extraction

The task creates a minimal HEEx template or generates raw HTML directly. It is NOT part of CI — it's purely a developer tool for visual inspection.

## Acceptance criteria

- [ ] New mix task file at `lib/mix/tasks/test.page.ex`
- [ ] Task generates `_site/test.html` with sample markdown snippets
- [ ] Test page renders all transforms applied (Navigation + DSFR)
- [ ] Includes sample table, code blocks, blockquotes, and headings for visual inspection
- [ ] Task is independent of `mix site.fetch` — uses inline sample content, no git sources needed

## Blocked by

None - can start immediately
