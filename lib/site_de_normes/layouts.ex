defmodule SiteDeNormes.Layouts do
  @moduledoc "HEEx layouts of the site."
  use Phoenix.Component

  alias SiteDeNormes.DSFR

  embed_templates "layouts/*"

  def render_page(assigns), do: assigns |> page() |> to_html()
  def render_index(assigns), do: assigns |> index() |> to_html()
  def render_profile(assigns), do: assigns |> profile() |> to_html()
  def render_unplaced(assigns), do: assigns |> unplaced() |> to_html()

  @doc "Warns that the extra content is a draft."
  def beta_alert(assigns) do
    ~H"""
    <div class="fr-alert fr-alert--warning fr-alert--sm fr-mb-4w">
      <p>
        <strong>Version bêta.</strong>
        Ce contenu est en cours de rédaction : son texte et son organisation sont
        susceptibles d'évoluer.
      </p>
    </div>
    """
  end

  defp to_html(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
end
