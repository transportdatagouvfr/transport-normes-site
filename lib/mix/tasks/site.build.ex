defmodule Mix.Tasks.Site.Build do
  @shortdoc "Builds the static site into _site/"
  use Mix.Task

  @output_dir "_site"

  @impl Mix.Task
  def run(_args) do
    SiteDeNormes.build(@output_dir)
    Mix.shell().info("Site built in #{@output_dir}/")
  end
end
