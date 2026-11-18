defmodule SiteDeNormes.PostProcessing.ToC do
  @moduledoc """
  Extracts a table of contents from rendered HTML using Floki.

  Parses the output of `MDEx.to_html!/1`, extracts only h1 and h2 headings
  with their anchor IDs, and builds a nested structure where h2 entries
  are children of the most recent preceding h1.

  Additionally detects `<div class="annexes">` boundaries to tag annex
  headings (`annex: true`), and recognizes "Bibliographie" headings for
  numbering suppression (`hide_numbering: true`).

  ## Example

      iex> SiteDeNormes.PostProcessing.ToC.extract(~s(<h1 id="hello">Hello</h1><h2 id="world">World</h2>))
      {[%{id: "hello", text: "Hello", children: [%{id: "world", text: "World", children: [], hide_numbering: false}], hide_numbering: false}], []}
  """

  @doc """
  Extracts a TOC tree and annex list from rendered HTML.

  Only h1 and h2 headings are included. h3+ are ignored. Orphaned h2s
  (those appearing before any h1) are also ignored.

  Headings inside `<div class="annexes">` are separated into the second
  element of the returned tuple, so CSS rules can target each group independently.

  ## Parameters

    * `html` — the rendered HTML string from `MDEx.to_html!/1`

  ## Returns

  A two-element tuple `{tree, annexes}` where each is a list of maps:

      {
        [
          %{
            id: "section-1",
            text: "Section 1",
            children: [
              %{id: "subsection", text: "Sub section", children: []}
            ],
            hide_numbering: false
          }
        ],
        [
          %{
            id: "annex-a",
            text: "Annexe A",
            children: [],
            hide_numbering: false
          }
        ]
      }
  """
  @spec extract(String.t()) :: {list(map()), list(map())}
  def extract(html) do
    html
    |> Floki.parse_document!()
    |> collect_headings(0)
    |> Enum.reduce([], &nest/2)
    |> Enum.reverse()
    |> Enum.map(fn heading ->
      %{heading | children: Enum.reverse(strip_level(heading.children))} |> Map.delete(:level)
    end)
    |> split_by_annex()
  end

  # ── Recursive Tree Walker ────────────────────────────────────────────────

  defp collect_headings(nodes, depth) when is_list(nodes) do
    Enum.flat_map(nodes, &collect_from_node(&1, depth))
  end

  # h1: collect heading with its text content
  defp collect_from_node({"h1", attrs, children}, depth) do
    [build_heading({"h1", attrs, children}, depth)]
  end

  # h2: collect heading with its text content
  defp collect_from_node({"h2", attrs, children}, depth) do
    [build_heading({"h2", attrs, children}, depth)]
  end

  # Any element with children: recurse into them (html, body, div, section, etc.)
  defp collect_from_node(node = {tag, _attrs, children}, depth)
       when is_binary(tag) and is_list(children) do
    new_depth =
      if tag == "div" and has_class?(node, "annexes") do
        depth + 1
      else
        depth
      end

    collect_headings(children, new_depth)
  end

  # Everything else: skip (text nodes, comments, etc.)
  defp collect_from_node(_, _depth), do: []

  # Checks if a Floki node has a specific class, handling space-separated class strings
  defp has_class?(node, class_name) do
    case Floki.attribute(node, "class") do
      [class_attr] when is_binary(class_attr) ->
        class_name in String.split(class_attr, ~r/\s+/)

      classes when is_list(classes) ->
        class_name in classes

      _ ->
        false
    end
  end

  # ── Heading Building ─────────────────────────────────────────────────────

  defp build_heading(element, depth) do
    text = Floki.text(element)
    tag = elem(element, 0)

    %{
      id: element |> Floki.attribute("id") |> List.first(),
      text: String.trim(text),
      children: [],
      level: if(tag == "h1", do: 1, else: 2),
      in_annexes: depth > 0,
      hide_numbering: String.trim(text) == "Bibliographie"
    }
  end

  # ── Nesting Logic ────────────────────────────────────────────────────────

  defp nest(%{level: 1} = h1, roots), do: [h1 | roots]

  defp nest(%{level: 2}, []), do: []

  defp nest(%{level: 2} = h2, [%{children: _} = parent | roots]),
    do: [%{parent | children: [h2 | parent.children]} | roots]

  # ── Cleanup ──────────────────────────────────────────────────────────────

  defp strip_level([]), do: []

  defp strip_level([%{level: _} = heading | rest]) do
    [
      %{heading | children: strip_level(heading.children)} |> Map.delete(:level)
      | strip_level(rest)
    ]
  end

  defp strip_level([other | rest]), do: [other | strip_level(rest)]

  # ── Split into tree vs annexes ───────────────────────────────────────────

  @spec split_by_annex(list(map())) :: {list(map()), list(map())}
  defp split_by_annex(headings) do
    {annexes, tree} = Enum.split_with(headings, &Map.get(&1, :in_annexes, false))
    {clean(tree), clean(annexes)}
  end

  @spec clean(list(map())) :: list(map())
  defp clean(headings) do
    Enum.map(headings, fn heading ->
      %{heading | children: clean_children(heading.children)} |> Map.delete(:in_annexes)
    end)
  end

  defp clean_children(children) do
    Enum.map(children, fn child ->
      %{child | children: clean_children(child.children)} |> Map.delete(:in_annexes)
    end)
  end
end
