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
    """
    <!doctype html>
    <html lang="fr">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Site de normes</title>
      </head>
      <body>
        <h1>Hello world</h1>
      </body>
    </html>
    """
  end
end
