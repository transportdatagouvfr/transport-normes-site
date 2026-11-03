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
      <ol>
        <li :for={heading <- @tree}>
          <a class="fr-summary__link" href={"##{heading.id}"}>{heading.text}</a>
          <ol :if={heading.children && heading.children != []}>
            <li :for={child <- heading.children}>
              <a class="fr-summary__link" href={"##{child.id}"}>{child.text}</a>
            </li>
          </ol>
        </li>
      </ol>
    </nav>
    """
  end
end
