import Config

# Source repositories of the published profiles, and which versions of them to publish:
# the releases (git tags, whitelisted manually) and the main work-in-progress branch.
#
# Later, this list could be modified dynamically (e.g. adding a contributor's pull request
# ref) to render a preview of a PR made on a source repository.
config :site_de_normes,
  sources: [
    %{
      id: "netex-fr",
      name: "NeTEx FR",
      url: "https://github.com/etalab/transport-profil-netex-fr",
      releases: ["v2.4.0", "v2.3"],
      wip: "v2.5-wip"
    },
    %{
      id: "siri-fr",
      name: "SIRI FR",
      url: "https://github.com/etalab/transport-profil-siri-fr",
      releases: ["v1.8.0", "v1.7"],
      wip: "v2.0-wip"
    }
  ]
