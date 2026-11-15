defmodule SiteDeNormes.DSFR do
  @moduledoc "DSFR (Design System de l'État Français) components."
  use Phoenix.Component

  # ── Breadcrumb ─────────────────────────────────────────────────────────

  @doc "Renders the DSFR breadcrumb, the last link being the current page."
  attr :links, :list, default: nil, doc: "`{label, href}` from the home page to the current page."
  slot :inner_block, doc: "Shown after the current page."

  def breadcrumb(assigns) do
    ~H"""
    <nav :if={@links} class="fr-breadcrumb" role="navigation" aria-label="vous êtes ici :">
      <button class="fr-breadcrumb__button" aria-expanded="false" aria-controls="breadcrumb">
        Voir le fil d’Ariane
      </button>
      <div class="fr-collapse" id="breadcrumb">
        <ol class="fr-breadcrumb__list">
          <li :for={{{label, href}, index} <- Enum.with_index(@links, 1)}>
            <a :if={index < length(@links)} class="fr-breadcrumb__link" href={href}>{label}</a>
            <a :if={index == length(@links)} class="fr-breadcrumb__link" aria-current="page">
              {label}
            </a>
            <span :if={index == length(@links) && @inner_block != []} class="fr-breadcrumb__after">
              {render_slot(@inner_block)}
            </span>
          </li>
        </ol>
      </div>
    </nav>
    """
  end

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
