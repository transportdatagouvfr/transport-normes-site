# 005: Section Index Bar

## What to build

A horizontal section index bar that displays all sections (pages) for the current norm and version. It appears below the top navigation bar on section pages, with the active section highlighted.

Sections in this project are directories of norm content (each containing an `index.md`), not headings within a document. The list of sections per version is already available from `SiteDeNormes.build_version/3` as `%{path: ..., href: ...}` tuples.

**Desktop**: A horizontal scrollable bar showing section names (e.g., "Arrêts", "Horaires", "Réseaux", "Tarifs", etc.) as links. The currently viewed section is visually distinguished.

**Mobile**: A "Sections" dropdown in the top bar instead of a horizontal scroll, since narrow screens can't accommodate the full index bar.

The section list data comes from `SiteDeNormes.build_version/3`, which already produces a list of pages (`%{path: ..., href: ...}`) for each version. This list is available in the source metadata (`source.versions[].pages`) and should be passed to the layout template as part of the page assigns.

This is a HITL task because the visual design (styling, positioning, dropdown behavior) should be reviewed against the wireframes in the legacy repo (`/home/frederic/git/betagouv/transport-normes-site/`) before merging.

## Acceptance criteria

- [ ] Horizontal section index bar renders below top navigation on desktop
- [ ] Active section is visually highlighted in the index bar
- [ ] Mobile dropdown replaces horizontal bar on narrow screens
- [ ] Section links navigate to the correct section pages (`/{norm}/{version}/{section}/`)
- [ ] Layout template updated to pass section list data (from `build_version/3` page list) to the index bar component

## Blocked by

- #004 (TOC Sidebar Layout — layout infrastructure)
- #006 (Prev/Next Navigation — shares section list data pattern)
