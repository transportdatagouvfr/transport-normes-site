# PRD: Static Site Generator for Normes des Données de Transport v2

## Problem Statement

The current site (https://normes.transport.data.gouv.fr) is built with Hugo and PaperMod, which doesn't give us control over the markdown-to-HTML transformation pipeline. The normative content from the NeTEx and SIRI France profiles renders as plain HTML without proper DSFR (Design System de l'État) styling — tables aren't wrapped in `fr-table`, headings lack IDs for navigation, there's no table of contents sidebar, no version selector, no section index bar, and no prev/next navigation.

We need a static site generator built in Elixir that converts markdown content from the norm repositories into fully DSFR-compliant HTML pages with proper navigation chrome (version selectors, TOC sidebar, section index), while keeping the build pipeline simple and testable.

## Solution

An Elixir-based static site generator (`SiteDeNormes`) that:
- Fetches norm source repositories via git (one bare clone per repo, checked out per version)
- Parses markdown into an AST using MDEx
- Transforms the AST through a composable plugin pipeline (navigation + DSFR styling)
- Renders pages using HEEx templates with DSFR layout chrome
- Outputs static HTML files to `_site/` for deployment on Netlify

The generator is invoked via two mix tasks: `mix site.fetch` (downloads source repos) and `mix site.build` (produces the static site).

## User Stories

1. As a site visitor, I want to land on a home page that presents governance context first, then shows norm cards (NeTEx, SIRI), so that I understand the regulatory framework before exploring technical specifications.
2. As a site visitor, I want to see which version of a norm is the current official one, marked with a green badge, so that I know I'm reading the authoritative specification.
3. As a site visitor, I want to switch between versions (current, old stable, WIP) using a dropdown in the top bar, so that I can compare specifications across versions or access older references.
4. As a site visitor, I want clean URLs like `/netex/arrets/` for the current version and `/netex/v2.3/arrets/` for specific versions, so that links are meaningful and bookmarkable.
5. As a site visitor, I want the current-version URL (`/netex/arrets/`) to automatically resolve to the latest official version via redirect, so that I always reach the authoritative content without needing to know version numbers.
6. As a site visitor browsing a section page on desktop, I want a horizontal section index bar below the top navigation showing all sections for the current norm and version, with the active section highlighted, so that I can quickly jump between sections.
7. As a site visitor browsing a section page on mobile, I want a "Sections" dropdown in the top bar instead of a horizontal scroll, so that navigation works well on narrow screens.
8. As a site visitor reading a section page on desktop, I want a sticky table of contents sidebar on the right showing all headings with nesting preserved, so that I can navigate within long specification pages.
9. As a site visitor reading a section page on mobile, I want a collapsible table of contents inline within the content flow, so that navigation is available without taking up screen space permanently.
10. As a site visitor, I want to see previous and next section navigation links at the bottom of every section page, so that I can follow the document structure sequentially.
11. As a site visitor viewing a current or WIP version, I want an "Proposer une modification" link that points to the appropriate branch on GitHub, so that I can contribute improvements directly.
12. As a site visitor viewing a sealed (old) version, I should not see an edit link, so that I understand this version is read-only.
13. As a site visitor, I want technical specification tables rendered with DSFR styling (`fr-table` class), so that they are visually consistent with the rest of the site and accessible.
14. As a site visitor, I want code blocks to be syntax-highlighted, so that XSD types, XML examples, and other technical content are readable.
15. As a site visitor, I want heading IDs auto-generated from text content, so that internal anchor links work correctly within pages.
16. As a site visitor, I want the front matter YAML block to be displayed as highlighted code in a DSFR callout for debugging purposes, so that I can understand page metadata.
17. As a site maintainer, I want to configure which norm versions are published via a simple config file with explicit version types (`:current`, `:old`, `:wip`), so that I can control what appears on the site without code changes.
18. As a site maintainer, I want the build tool to generate Netlify redirect rules automatically from the config, so that current-version aliasing works correctly without manual maintenance.
19. As a site maintainer, I want extra content (governance text, FAQ, guides) to live in a `content/` directory alongside the generator code, so that it's easy to maintain separately from the norm sources.
20. As a developer working on DSFR transforms, I want a dedicated test page generated by a mix task that renders sample markdown snippets with all transforms applied, so that I can visually verify changes in a browser without running the full build pipeline.
21. As a developer, I want each AST transform to be an independently testable plugin module, so that I can write focused unit tests and extend the pipeline without touching unrelated code.
22. As a CI system, I want `mix site.fetch` to fail if any configured ref doesn't exist, so that broken configuration (typos in tag names, deleted branches) is caught immediately rather than silently producing an incomplete site.
23. As a security-conscious maintainer, I want the build tool to reject commits containing symlinks, so that malicious or misconfigured repositories can't publish files outside their scope.

## Implementation Decisions

### Architecture: Build-Time Static Site Generator

The site generator runs entirely at build time. It produces plain static HTML files served by Netlify. No application server is needed. Elixir's role is purely as a build tool (analogous to Hugo or Jekyll).

### Plugin-Based AST Transformation Pipeline

Markdown is parsed into an AST via MDEx. Transformations are implemented as plugin modules, each with an `attach/2` function that registers pipeline steps. Steps use `MDEx.Document.update_nodes/3` or `MDEx.traverse_and_update/2` to transform the tree before rendering. Plugins are composed in order by passing them as a list to `MDEx.new(plugins: [...])`.

The pipeline order is: Navigation plugin first (structural changes like heading IDs), then DSFR plugin second (styling transformations).

### Two Transform Plugin Modules

**Navigation plugin**: Extracts heading text from the AST, auto-generates anchor IDs, builds a TOC tree structure, and stores it in document assigns for the layout template to render. Also handles section discovery per version.

**DSFR plugin**: Wraps markdown elements in DSFR classes — tables get `fr-table` wrapper, blockquotes become callouts, code blocks are highlighted (using mdex built-in syntect highlighter), and other content-level transformations are applied.

### Version Type Classification

Each ref in the config is explicitly typed as `:current`, `:old`, or `:wip`. This drives badge rendering (green/blue/amber), edit link visibility, and version selector ordering. The type is semantic, not presentational — colors are derived from types in the layout templates.

### URL Structure

Pages follow the pattern `{norm}/{version}/{page}/index.html`. Current-version aliasing (`/netex/arrets/` → `/netex/v2.4.0/arrets/index.html`) is handled by Netlify redirects, which are auto-generated during build from the config's `:current` refs.

### HEEx Layouts with Assigns

Page layouts are HEEx templates that receive assigns computed by the build tool: title, content (already DSFR-transformed HTML), norm name, version info, TOC data, section list, current section, prev/next navigation hints, and edit URL. The layout renders the chrome (header, nav bars, TOC sidebar, footer) using these assigns and injects `@content` as raw HTML.

### Extra Content

Non-norm content (governance, FAQ, guides) lives in a `content/` directory at the project root. These files go through the same pipeline but are not versioned. Their final placement (embedded in home page vs. dedicated pages) is to be determined as more content is added.

### FrontMatter Plugin

The existing FrontMatter plugin (which renders YAML front matter as highlighted code in a DSFR callout) is kept as-is. It's a debug feature that uses the same plugin pattern and Lumis for highlighting.

### Git Source Fetching

Each norm repository is cloned once as a bare repo. Each configured ref is checked out into its own directory using git worktrees. Symlink-containing commits are rejected during checkout. The existing `SiteDeNormes.Git` module handles this.

### Redirect Generation

During `build/3`, Netlify `_redirects` file(s) are generated from config. For each norm, a rule maps the norm's path to its current version: `/netex/* → /netex/v2.4.0/:splat 301`. This ensures current-version URLs always resolve correctly.

### Project Structure

```
lib/site_de_normes/
├── site_de_normes.ex           # Build orchestration (build/3)
├── front_matter.ex             # Front matter display plugin (existing)
├── git.ex                      # Git operations (existing)
├── layouts.ex                  # HEEx layout rendering (existing)
├── transforms/                 # New: AST transform plugins
│   ├── dsfr.ex                 # DSFR styling plugin
│   └── navigation.ex           # Navigation plugin (IDs, TOC)
└── test_page.ex                # Static test page generator

mix/tasks/
├── site.build.ex               # Existing build task
├── site.fetch.ex               # Existing fetch task
└── test.page.ex                # New: generates test.html
```

## Testing Decisions

### What Makes a Good Test

Tests should verify external behavior — given markdown input, produce expected HTML output. They should not depend on internal implementation details (which specific function was called, how the AST was traversed). Use `MDEx.to_html!/2` with plugins to exercise the full pipeline and assert on the resulting HTML string.

### Modules to Test

- **Navigation plugin**: Test heading ID generation, TOC tree extraction, section discovery. Verify that given markdown with headings, the output assigns contain correct IDs and a properly nested TOC structure.
- **DSFR plugin**: Test each transform independently — table wrapping, code block highlighting, callout conversion, etc. Given specific markdown snippets, assert the rendered HTML contains expected DSFR classes and structure.
- **FrontMatter plugin**: Test that YAML front matter is rendered as highlighted code in a callout div.
- **Build orchestration**: Test end-to-end that `build/3` produces correct file paths, redirect rules, and source metadata for each version.

### Prior Art

The existing test suite (`test/site_de_normes/front_matter_test.exs`, `test/site_de_normes/git_test.exs`) follows the same pattern — exercise a module's public API and assert on results. New tests will follow this convention. The `lazy_html` dependency is already in deps for `:test` environment, which can help with HTML assertions.

### Test Page

A dedicated `mix test.page` task generates `_site/test.html` containing sample markdown snippets (one per transform). This is a visual regression tool — developers open it in a browser to verify transforms look correct before committing changes. It complements automated tests by catching visual/styling issues that string assertions miss.

## Out of Scope

- Search functionality
- Diff highlighting between versions
- "What's new" changelog pages
- Guided paths or task-based navigation
- Per-norm governance text on norm home pages
- Editorial content sections
- Version tagging scheme and automated version discovery pipeline (the config is manually maintained)
- LiveView / interactive features (static HTML only)
- Dark mode beyond DSFR's built-in system preference detection
- Internationalization beyond French

## Further Notes

### Dependencies Already Present

The project already has these deps configured in `mix.exs`:
- `mdex ~> 0.14` — markdown parsing and AST manipulation
- `lumis ~> 0.10` + `lumis_wasm_yaml ~> 0.26` — syntax highlighting (used by FrontMatter plugin)
- `phoenix_live_view ~> 1.2` — for HEEx template rendering (though the output is static, not live)
- `lazy_html ~> 0.1` — HTML testing utilities

### CI Pipeline

The existing `.github/workflows/ci.yml` runs: `mix deps.get`, `mix format --check-formatted`, `mix compile`, `mix test`, `mix site.fetch`, and `mix site.build`. The fetch + build steps catch broken refs early. New mix tasks (`test.page`) are not part of CI — they're a developer tool.

### Legacy Site

The legacy Hugo-based site lives in `/home/frederic/git/betagouv/transport-normes-site/` (same directory name but different remote). It is not being modified — this new generator at `transportdatagouvfr/transport-normes-site` will replace it. Wireframes exist in the legacy repo showing the target DSFR-based design for home, norm home, and section pages.

### Norm Sources

Two norm repositories are configured:
- **NeTEx FR**: `https://github.com/etalab/transport-profil-netex-fr` — 7 sections (Arrêts, Horaires, Réseaux, Tarifs, Accessibilité, Parkings, Éléments communs)
- **SIRI FR**: `https://github.com/etalab/transport-profil-siri-fr` — sections to be defined when migrated

Each section is a directory containing an `index.md` file (the main content) plus optional media assets. The total NeTEx content is approximately 36,000 lines of markdown across 7 sections.
