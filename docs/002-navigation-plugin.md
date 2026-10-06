# 002: Navigation Plugin

## What to build

An MDEx AST transform plugin (`SiteDeNormes.Transforms.Navigation`) that processes heading nodes in the markdown tree and:

1. **Auto-generates anchor IDs** from heading text content, attaching them to each heading node so internal anchor links work.
2. **Extracts a TOC tree structure** from all headings (preserving nesting/hierarchy), storing it in document assigns for the layout template to render.

The plugin is attached during `build_page/3` in `SiteDeNormes`, before rendering. It runs first in the pipeline (navigation structural changes, then DSFR styling).

Tests exercise the public API: given markdown with headings, assert the output assigns contain correct IDs and a properly nested TOC structure. Use `MDEx.to_html!/2` with plugins to exercise the full pipeline and assert on resulting HTML strings. Follow existing test patterns from `test/site_de_normes/front_matter_test.exs`. Note: "sections" in this project refer to directories of norm content (each containing an `index.md`), not headings within a document. Section-level navigation between pages is handled separately.

## Acceptance criteria

- [x] Plugin module at `lib/site_de_normes/transforms/navigation.ex` with `attach/1` function
- [x] Heading IDs are auto-generated deterministically from text content (no random or timestamp-based IDs)
- [x] TOC tree is stored in document assigns as a nested structure preserving heading hierarchy
- [x] Plugin integrates into the build pipeline — `SiteDeNormes.build_page/3` calls `Navigation.attach(document)` before `MDEx.to_html!/2`
- [x] Unit tests verify heading ID generation and TOC tree extraction from sample markdown

## Blocked by

None - can start immediately
