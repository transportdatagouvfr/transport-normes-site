# 006: Prev/Next Navigation

## What to build

Previous and next section navigation links at the bottom of every section page. These allow visitors to follow the document structure sequentially (e.g., after reading "Arrêts", click "Next" to go to "Horaires").

The prev/next hints are derived from the ordered section list produced by `SiteDeNormes.build_version/3` (`%{path: ..., href: ...}` tuples). For each section page, compute the previous and next items in that list and render them as styled links with directional labels ("Précédent" / "Suivant" in French).

The layout template receives these assigns alongside existing content and renders them below `@content`. Only show prev when there is a predecessor, only show next when there is a successor (first/last sections show only one link).

## Acceptance criteria

- [ ] Prev and next navigation links render at the bottom of every section page
- [ ] Links point to the correct sibling section pages (`/{norm}/{version}/{section}/`)
- [ ] First section shows only "Next", last section shows only "Previous"
- [ ] Labels are in French ("Précédent" / "Suivant")
- [ ] Layout template updated to pass prev/next page data (derived from `build_version/3` page list) to the navigation component

## Blocked by

- #005 (Section Index Bar — shares section list data pattern)
