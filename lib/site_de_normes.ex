defmodule SiteDeNormes do
  @moduledoc """
  Static site generator. Writes plain files to an output directory.
  """

  def build(output_dir) do
    File.rm_rf!(output_dir)
    File.mkdir_p!(output_dir)
    File.write!(Path.join(output_dir, "index.html"), index_html())
    File.write!(Path.join(output_dir, "robots.txt"), robots_txt())
  end

  defp robots_txt do
    """
    User-agent: *
    Disallow: /
    """
  end

  defp index_html do
    SiteDeNormes.Layouts.render_page(%{
      title: "Accueil",
      root: "",
      content: "<h1>Site en construction</h1>"
    })
  end
end
