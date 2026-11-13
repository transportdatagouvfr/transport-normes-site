# normes.transport.data.gouv.fr v2

Future v2 de [normes.transport.data.gouv.fr](https://normes.transport.data.gouv.fr) (en construction) : un site statique généré en Elixir à partir des profils France [NeTEx](https://github.com/etalab/transport-profil-netex-fr) et [SIRI](https://github.com/etalab/transport-profil-siri-fr).

## Installation

Les versions d'Elixir et d'Erlang sont fixées dans `.tool-versions`, à installer avec [mise](https://mise.jdx.dev) :

```sh
mise install
mix deps.get
```

Il est également possible d'utiliser Nix :

```sh
nix develop
mix --version
```

## Tâches mix

```sh
mix site.fetch   # récupère les sources dans _sources/ (versions listées dans config/config.exs)
mix site.build   # génère le site dans _site/ (nécessite site.fetch)
mix test
```

Le site généré s'ouvre directement dans un navigateur : `open _site/index.html`.

## Déploiement (Netlify)

`bin/deploy` envoie `_site/` à Netlify : https://v2-beta-normes-transport-data-gouv-fr.netlify.app

`bin/deploy BRANCHE` crée à la place une preview, sans toucher à la production : https://BRANCHE--v2-beta-normes-transport-data-gouv-fr.netlify.app

La CI déploie `main` en production, et chaque autre branche de ce repository (le code du site, pas les dépôts de contenu) en preview (lien « View deployment » sur la PR).

Les secrets sont des secrets du repository : https://github.com/transportdatagouvfr/transport-normes-site/settings/secrets/actions

- `NETLIFY_SITE_ID` : « Project ID » du site Netlify
- `NETLIFY_AUTH_TOKEN` : personal access token Netlify, **avec une date d'expiration**. Une fois expiré, `bin/deploy` échoue avec « Netlify token rejected ». Il faut alors en créer un nouveau (https://app.netlify.com/user/applications#personal-access-tokens) et mettre à jour le secret.

En local, avec les deux variables exportées dans `.env` :

```sh
source .env && mix site.fetch && mix site.build && bin/deploy [BRANCHE]
```
