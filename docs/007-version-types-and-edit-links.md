# 007: Version Types and Edit Links

## What to build

Version type classification in the config and corresponding UI changes. Each ref in `config/config.exs` is explicitly typed as `:current`, `:old`, or `:wip`. This drives badge rendering, edit link visibility, and version selector ordering.

**Config**: Add a `type` field to each source's ref configuration. Example:
```elixir
sources: [
  %{
    id: "netex-fr",
    name: "NeTEx FR",
    url: "https://github.com/etalab/transport-profil-netex-fr",
    refs: [
      %{ref: "refs/tags/v2.4.0", type: :current},
      %{ref: "refs/tags/v2.3.0", type: :old},
      %{ref: "refs/heads/v2.5-wip", type: :wip}
    ]
  }
]
```

**UI changes**:
- **Version badges**: `:current` → green badge, `:wip` → blue badge, `:old` → no badge (or neutral)
- **Edit link visibility**: Show "Proposer une modification" link for `:current` and `:wip` versions only. The link points to the appropriate branch/PR URL on GitHub. Do not show edit links for `:old` (sealed) versions.
- **Version selector ordering**: Present versions in the dropdown as current first, then WIP, then old versions.

This is a HITL task because the badge colors and edit link styling should be reviewed against DSFR conventions and the wireframes in the legacy repo before merging.

## Acceptance criteria

- [ ] Config schema supports `type` field per ref (`:current`, `:old`, `:wip`)
- [ ] Version badges render with correct colors derived from type (green for current, blue for WIP)
- [ ] "Proposer une modification" link appears for `:current` and `:wip` versions only
- [ ] Edit link points to the correct GitHub branch/PR URL for the version
- [ ] Edit link does not appear for `:old` (sealed) versions
- [ ] Version selector dropdown orders versions: current first, then WIP, then old

## Blocked by

None - can start immediately
