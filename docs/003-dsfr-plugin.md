# 003: DSFR Plugin

## What to build

An MDEx AST transform plugin (`SiteDeNormes.Transforms.Dsfr`) that wraps markdown elements in DSFR-compliant HTML classes. The plugin runs second in the pipeline (after Navigation), transforming content-level structure before rendering.

Transforms include:
- **Tables**: Wrap `<table>` elements with a `<div class="fr-table">` wrapper so they render with DSFR styling
- **Code blocks**: Use mdex's built-in syntect highlighter to add syntax highlighting to fenced code blocks (XSD types, XML examples, etc.)
- **Blockquotes**: Convert `<blockquote>` elements into DSFR callouts (`<div class="fr-callout">`)

The plugin is attached during `build_page/4` in `SiteDeNormes`, after the Navigation plugin. It uses `MDEx.Document.update_nodes/3` or `MDEx.traverse_and_update/2` to transform the tree.

Tests verify each transform independently — given specific markdown snippets, assert the rendered HTML contains expected DSFR classes and structure. Follow existing test patterns from `test/site_de_normes/front_matter_test.exs`.

## Acceptance criteria

- [ ] Plugin module at `lib/site_de_normes/transforms/dsfr.ex` with `attach/1` function
- [ ] Markdown tables are wrapped in `<div class="fr-table">` wrappers
- [ ] Fenced code blocks receive syntax highlighting via mdex's built-in syntect highlighter
- [ ] Blockquotes are converted to DSFR callout divs (`<div class="fr-callout">`)
- [ ] Plugin integrates into the build pipeline — `SiteDeNormes.build_page/4` calls `Dsfr.attach(document)` after Navigation, before `MDEx.to_html!/2`
- [ ] Unit tests verify each transform independently with sample markdown snippets

## Blocked by

None - can start immediately
