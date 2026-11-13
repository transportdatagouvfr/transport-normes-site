defmodule SiteDeNormes.DSFR do
  @moduledoc "DSFR (Design System de l'État Français) components."
  use Phoenix.Component

  # ── Table of Contents ──────────────────────────────────────────────────

  @doc "Renders the DSFR summary navigation for a page's table of contents."
  attr :tree, :list, default: [], doc: "Standard headings extracted from the markdown."

  attr :annexes, :list,
    default: [],
    doc: "Annex headings extracted from inside div.annexes blocks."

  attr :title, :string, default: "Table des matières", doc: "Title of the TOC nav."

  def table_of_content(assigns) do
    ~H"""
    <nav
      :if={@tree && @tree != []}
      class="fr-summary fr-container fr-my-6w"
      role="navigation"
      aria-labelledby="fr-summary-title"
    >
      <.section id="fr-summary-title" title={@title} entries={@tree} />
      <.section
        :if={@annexes && @annexes != []}
        id="fr-summary-annexes-title"
        title="Annexes"
        entries={@annexes}
        class="annexes"
      />
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :entries, :list, required: true
  attr :class, :string, default: nil

  defp section(assigns) do
    ~H"""
    <h2 class="fr-summary__title" id={@id}>{@title}</h2>
    <.entries entries={@entries} class={assigns[:class]} />
    """
  end

  attr :entries, :list, required: true
  attr :class, :string, default: nil
  attr :level, :integer, default: 1

  defp entries(assigns) do
    ~H"""
    <ol :if={@entries != []} {entries_extra_args(@class)}>
      <.entry :for={heading <- @entries} {heading} level={@level} />
    </ol>
    """
  end

  defp entries_extra_args(class) do
    [] |> put_if(not is_nil(class), :class, class)
  end

  attr :id, :string, required: true
  attr :text, :string, required: true
  attr :children, :list, default: []
  attr :hide_numbering, :boolean, default: false
  attr :level, :integer, required: true

  defp entry(assigns) do
    ~H"""
    <li>
      <.entry_link {assigns} />
      <.entries :if={@children} entries={@children} level={@level + 1} />
    </li>
    """
  end

  defp entry_link(assigns) do
    ~H"""
    <a
      class="fr-summary__link"
      href={"##{@id}"}
      data-level={@level}
      {entry_link_extra_attrs(@hide_numbering)}
    >
      {@text}
    </a>
    """
  end

  defp entry_link_extra_attrs(hide_numbering?) do
    []
    |> put_if(hide_numbering?, :"data-hide-numbering", "true")
  end

  defp put_if(attrs, true, key, value), do: Keyword.put(attrs, key, value)
  defp put_if(attrs, false, _key, _value), do: attrs
end
