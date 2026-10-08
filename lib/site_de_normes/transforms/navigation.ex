defmodule SiteDeNormes.Transforms.Navigation do
  @moduledoc """
  MDEx plugin that processes heading nodes in the markdown tree:

  - Auto-generates anchor IDs from heading text content using Comrak's GFM algorithm
  - Extracts a TOC tree structure preserving nesting/hierarchy

  Results are stored in document private fields for extraction before rendering.
  """

  alias MDEx.Document
  alias SiteDeNormes.Transforms.HeaderSlugifier

  @doc """
  Attaches navigation transforms to the document.

  Sets two private fields:
  - `:toc_tree` — nested TOC structure preserving heading hierarchy
  """
  @spec attach(Document.t()) :: Document.t()
  def attach(document) do
    document
    |> Document.put_extension_options(header_id_prefix: "")
    |> Document.append_steps(toc_and_sections: &extract_toc/1)
  end

  defp extract_toc(document) do
    {document, {_seen, headings}} =
      MDEx.traverse_and_update(document, {%{}, []}, &extract_heading/2)

    document
    |> Document.put_private(:toc_tree, build_toc_tree(Enum.reverse(headings)))
  end

  defp extract_heading(%MDEx.Heading{} = node, {seen_ids, headings}) do
    text = extract_text(node.nodes)
    {slug, seen_ids} = HeaderSlugifier.slugify(text, seen_ids)
    updated_node = Map.put(node, :id, slug)
    {updated_node, {seen_ids, [updated_node | headings]}}
  end

  defp extract_heading(node, acc), do: {node, acc}

  @doc """
  Builds a nested TOC tree from flat heading nodes, preserving hierarchy.

  Headings are nested based on their level — a heading becomes a child of the
  most recent heading at a lower level.
  """
  @spec build_toc_tree([MDEx.Heading.t()]) :: list(map())
  def build_toc_tree(headings) when is_list(headings) do
    headings
    |> Enum.map(fn h ->
      %{
        id: Map.get(h, :id) || "",
        text: extract_text(h.nodes),
        level: h.level,
        children: []
      }
    end)
    |> nest_headings()
  end

  @doc """
  Recursively extracts plain text from heading nodes, stripping all inline formatting.
  """
  @spec extract_text([MDEx.Document.md_node()]) :: String.t()
  def extract_text(nodes) do
    nodes
    |> Enum.map(&extract_text_node/1)
    |> Enum.join(" ")
    |> String.replace(~r/[\s]+/, " ")
    |> String.trim()
  end

  defp extract_text_node(%MDEx.Text{literal: literal}), do: literal
  defp extract_text_node(%MDEx.LineBreak{}), do: " "
  defp extract_text_node(%MDEx.Code{literal: literal}), do: literal
  defp extract_text_node(%MDEx.Strong{nodes: nodes}), do: extract_text(nodes)
  defp extract_text_node(%MDEx.Emph{nodes: nodes}), do: extract_text(nodes)
  defp extract_text_node(%MDEx.Link{nodes: nodes}), do: extract_text(nodes)
  defp extract_text_node(%MDEx.Image{nodes: nodes}), do: extract_text(nodes)
  defp extract_text_node(_), do: ""

  # ── Nesting Logic ──────────────────────────────────────────────────────

  # Takes a flat list of headings and nests them by level.
  # A heading's children are all consecutive deeper headings,
  # stopping when we hit a heading at the same or higher level.
  defp nest_headings([]), do: []

  defp nest_headings([heading | rest]) do
    {children, remaining} = collect_flat_children(rest, heading.level)
    [%{heading | children: nest_headings(children)} | nest_headings(remaining)]
  end

  # Collect all consecutive headings that are strictly deeper than parent_level.
  # Returns them as a flat list — nesting is done by nest_headings recursively.
  defp collect_flat_children([], _parent_level), do: {[], []}

  defp collect_flat_children([heading | rest], parent_level) when heading.level > parent_level do
    {more, remaining} = collect_flat_children(rest, parent_level)
    {[heading | more], remaining}
  end

  # Next heading is at or above parent level — stop collecting.
  defp collect_flat_children(headings, _parent_level), do: {[], headings}
end
