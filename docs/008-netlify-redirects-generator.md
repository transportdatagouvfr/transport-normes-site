# 008: Netlify Redirects Generator

## What to build

During `build/3`, auto-generate a Netlify `_redirects` file that maps current-version aliasing URLs to their actual paths. For example, `/netex/arrets/` should redirect (301) to `/netex/v2.4.0/arrets/index.html`.

The redirect rules are derived from the config's `:current` refs. For each norm with a `:current` version, generate a wildcard rule:
```
/netex/* /netex/v2.4.0/:splat 301
```

This ensures current-version URLs always resolve correctly without needing to know version numbers. The `_redirects` file is written to the output directory (`_site/`) alongside the generated HTML files, where Netlify reads it during deployment.

## Acceptance criteria

- [ ] `build/3` generates a `_redirects` file in the output directory
- [ ] Redirect rules are derived from config's `:current` version refs
- [ ] Each norm with a `:current` version gets a wildcard 301 rule (`/{norm}/* /{norm}/{version}/:splat 301`)
- [ ] Rules use correct version numbers from the current ref
- [ ] Generated `_redirects` file follows Netlify redirect syntax

## Blocked by

- #007 (Version Types and Edit Links — provides `:current` type classification in config)
