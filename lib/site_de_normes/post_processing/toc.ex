defmodule SiteDeNormes.PostProcessing.ToC do
  @moduledoc """
  Extracts a table of contents from rendered HTML using Floki.

  Parses the output of `MDEx.to_html!/1`, extracts only h1 and h2 headings
  with their anchor IDs, and builds a nested structure where h2 entries
  are children of the most recent preceding h1.

  ## Example

      iex> SiteDeNormes.PostProcessing.ToC.extract("<h1>Hello</h1><h2>World</h2>")
      [%{id: "hello", text: "Hello", children: [%{id: "world", text: "World"}]}]
  """

  @doc """
  Extracts a TOC tree from rendered HTML.

  Only h1 and h2 headings are included. h3+ are ignored. Orphaned h2s
  (those appearing before any h1) are also ignored.

  ## Parameters

    * `html` — the rendered HTML string from `MDEx.to_html!/1`

  ## Returns

  A list of maps, each representing an h1 entry:

      [
        %{
          id: "section-1",
          text: "Section 1",
          children: [
            %{id: "subsection", text: "Sub section"}
          ]
        }
      ]
  """
  @spec extract(String.t()) :: list(map())
  def extract(html) do
    html
    |> Floki.parse_document()
    |> elem(1)
    |> Floki.find("h1, h2")
    |> Enum.map(&extract_heading/1)
    |> nest_headings()
  end

  defp extract_heading({tag, _attrs, _children} = element) do
    level =
      case tag do
        "h1" -> :h1
        "h2" -> :h2
      end

    %{id: Floki.attribute(element, "id") |> List.first(), text: Floki.text(element), level: level}
    |> maybe_add_children(level)
  end

  defp maybe_add_children(map, _level), do: Map.put(map, :children, [])

  # ── Nesting Logic ──────────────────────────────────────────────────────

  # Takes a flat list of h1/h2 entries and nests h2s under their
  # most recent preceding h1. Orphaned h2s (before any h1) are dropped.
  defp nest_headings(headings) do
    {roots, children_map, _} =
      Enum.reduce(headings, {[], %{}, nil}, fn
        %{level: :h1} = h, {acc, children_map, _parent} ->
          new_root = %{id: h.id, text: h.text, children: []}
          {[new_root | acc], Map.put(children_map, h.id, []), h}

        %{level: :h2} = h, {acc, children_map, parent} when is_map(parent) ->
          updated_children =
            Map.update!(
              children_map,
              parent.id,
              &(&1 ++ [%{id: h.id, text: h.text, children: []}])
            )

          {acc, updated_children, parent}

        %{level: :h2}, {acc, children_map, _parent} ->
          # Orphaned h2 — drop it
          {acc, children_map, nil}
      end)

    Enum.reverse(roots)
    |> Enum.map(fn root ->
      %{root | children: Map.get(children_map, root.id, [])}
    end)
  end
end
