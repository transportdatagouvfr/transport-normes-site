defmodule SiteDeNormes.Layouts do
  @moduledoc "HEEx layouts of the site."
  use Phoenix.Component

  embed_templates "layouts/*"

  def render_page(assigns) do
    assigns |> page() |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
  end
end
