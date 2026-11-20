defmodule Mix.Tasks.Site.Fetch do
  @shortdoc "Fetches the source repositories into _sources/"
  @moduledoc """
  Clones (or updates) each source repository configured in `config/config.exs`
  as a single bare clone in `_sources/`, then writes the files of each configured
  ref to its own directory, named after the ref:

      _sources/netex-fr.git/                 # the clone
      _sources/netex-fr/heads/v2.5-wip/      # refs/heads/v2.5-wip
      _sources/netex-fr/tags/v2.4.0/         # refs/tags/v2.4.0

  The repository of the extra content is fetched the same way, for its only ref:

      _sources/extras.git/
      _sources/extras/heads/v1.0-wip/

  The task fails if a configured ref doesn't exist (typo in a tag name, branch renamed
  or deleted upstream...). This is by design: since it runs in CI, a broken
  configuration is caught right away, instead of silently publishing a site
  with a missing version.
  """
  use Mix.Task

  alias SiteDeNormes.Git

  @sources_dir "_sources"

  @impl Mix.Task
  def run(_args) do
    for source <- Application.fetch_env!(:site_de_normes, :sources) do
      fetch(source, source.refs)
    end

    extras = Application.fetch_env!(:site_de_normes, :extras)
    fetch(extras, [extras.ref])
  end

  defp fetch(source, refs) do
    # One clone per repository, all its versions are read from it
    repo = Path.join(@sources_dir, source.id <> ".git")
    Git.sync(source.url, repo)

    for ref <- refs do
      # Raises (failing the task, hence the CI) if a configured ref doesn't exist
      sha = Git.commit_sha(repo, ref)
      dir = Path.join(@sources_dir, SiteDeNormes.version_path(source, ref))
      Git.checkout_into(repo, sha, dir)
      Mix.shell().info("#{source.name} #{ref} #{sha} -> #{dir}")
    end
  end
end
