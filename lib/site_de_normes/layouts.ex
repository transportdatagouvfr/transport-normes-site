defmodule SiteDeNormes.Layouts do
  @moduledoc "HEEx layouts of the site."
  use Phoenix.Component

  embed_templates "layouts/*"

  def render_page(assigns), do: assigns |> page() |> to_html()
  def render_index(assigns), do: assigns |> index() |> to_html()

  defp to_html(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
end
