defmodule Mix.Tasks.Site.Fetch do
  @shortdoc "Fetches the source repositories into _sources/"
  @moduledoc """
  Clones (or updates) each source repository configured in `config/config.exs`
  as a single bare clone in `_sources/`, then checks that each configured ref exists.

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
      # One clone per repository, all its versions are read from it
      dir = Path.join(@sources_dir, source.id <> ".git")
      Git.sync(source.url, dir)

      # Raises (failing the task, hence the CI) if a configured ref doesn't exist
      for ref <- source.refs do
        Mix.shell().info("#{source.name} #{ref} #{Git.commit_sha(dir, ref)}")
      end
    end
  end
end
