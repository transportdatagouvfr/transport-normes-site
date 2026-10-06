# 004: TOC Sidebar Layout

## What to build

Update the page layout template (`lib/site_de_normes/layouts/page.html.heex`) to render a table of contents sidebar for section pages. The sidebar consumes the TOC tree data produced by the Navigation plugin (available in document assigns).

**Desktop**: A sticky TOC sidebar on the right side of the content area, showing all headings with nesting preserved (indented/subclassed hierarchy). The active heading (corresponding to the current viewport position) is highlighted.

**Mobile**: A collapsible TOC that appears inline within the content flow rather than as a persistent sidebar. It should be toggleable — hidden by default, expandable via a button.

The layout template receives assigns from `SiteDeNormes.build_page/3`: title, content (already DSFR-transformed HTML), TOC data from the Navigation plugin, and other metadata. The chrome renders using these assigns and injects `@content` as raw HTML via `Phoenix.HTML.raw(@content)`.

This is a HITL task because the visual design of the sidebar (styling, positioning, mobile behavior) should be reviewed against the wireframes in the legacy repo (`/home/frederic/git/betagouv/transport-normes-site/`) before merging.

## Acceptance criteria

- [ ] Desktop sticky TOC sidebar renders on section pages with nested heading hierarchy
- [ ] Active heading is highlighted based on scroll position (via CSS or minimal JS)
- [ ] Mobile collapsible inline TOC replaces the sidebar on narrow screens
- [ ] Layout template updated to pass TOC data from Navigation plugin assigns to the sidebar component
- [ ] DSFR styling applied consistently with existing layout chrome

## Blocked by

- #002 (Navigation Plugin — provides TOC tree data)
