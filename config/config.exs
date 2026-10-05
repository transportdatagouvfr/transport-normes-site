import Config

# Source repositories of the published profiles, and which versions of them to publish,
# as fully qualified git refs: the releases (tags, whitelisted manually) and the main
# work-in-progress branch.
#
# Each ref must exist: `mix site.fetch` (run in CI) fails otherwise.
#
# Later, this list could be modified dynamically (e.g. adding a contributor's pull request
# ref) to render a preview of a PR made on a source repository.
config :site_de_normes,
  sources: [
    %{
      id: "netex-fr",
      name: "NeTEx FR",
      url: "https://github.com/etalab/transport-profil-netex-fr",
      refs: ["refs/heads/v2.5-wip", "refs/tags/v2.4.0", "refs/tags/v2.3"]
    },
    %{
      id: "siri-fr",
      name: "SIRI FR",
      url: "https://github.com/etalab/transport-profil-siri-fr",
      refs: ["refs/heads/v2.0-wip", "refs/tags/v1.8.0", "refs/tags/v1.7"]
    }
  ]
