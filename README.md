# normes.transport.data.gouv.fr v2

Future v2 de [normes.transport.data.gouv.fr](https://normes.transport.data.gouv.fr) (en construction) : un site statique généré en Elixir à partir des profils France [NeTEx](https://github.com/etalab/transport-profil-netex-fr) et [SIRI](https://github.com/etalab/transport-profil-siri-fr).

## Installation

Les versions d'Elixir et d'Erlang sont fixées dans `.tool-versions`, à installer avec [mise](https://mise.jdx.dev) :

```sh
mise install
mix deps.get
```

## Tâches mix

```sh
mix site.fetch   # récupère les sources dans _sources/ (versions listées dans config/config.exs)
mix site.build   # génère le site dans _site/ (nécessite site.fetch)
mix test
```

Le site généré s'ouvre directement dans un navigateur : `open _site/index.html`.
