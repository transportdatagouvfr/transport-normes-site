defmodule SiteDeNormes.DSFR do
  @moduledoc "DSFR (Design System de l'État Français) components."
  use Phoenix.Component

  # ── Table of Contents ──────────────────────────────────────────────────

  @doc "Renders the DSFR summary navigation for a page's table of contents."
  attr :tree, :list, default: [], doc: "Nested heading tree from MDEx."
  attr :title, :string, default: "Table des matières", doc: "Title of the TOC nav."

  def table_of_content(assigns) do
    ~H"""
    <nav
      :if={@tree && @tree != []}
      class="fr-summary fr-container fr-my-6w"
      role="navigation"
      aria-labelledby="fr-summary-title"
    >
      <h2 class="fr-summary__title" id="fr-summary-title">{@title}</h2>
      <.entries entries={@tree} />
    </nav>
    """
  end

  attr :entries, :list, required: true

  defp entries(assigns) do
    ~H"""
    <ol :if={@entries != []}>
      <.entry :for={heading <- @entries} {heading} />
    </ol>
    """
  end

  attr :id, :string, required: true
  attr :text, :string, required: true
  attr :children, :list, default: []

  defp entry(assigns) do
    ~H"""
    <a class="fr-summary__link" href={"##{@id}"}>{@text}</a>
    <.entries :if={@children} entries={@children} />
    """
  end
end
