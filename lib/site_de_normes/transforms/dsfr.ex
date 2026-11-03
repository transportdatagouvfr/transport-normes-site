defmodule SiteDeNormes.Transforms.Dsfr do
  @moduledoc """
  Post-processing transform for tables using Floki.

  Runs after `MDEx.to_html!/1` to apply DSFR table styling without the
  Comrak round-trip corruption that occurs when injecting raw HTML into
  the AST.

  ## Features

  - Wraps every `<table>` in `<div class="fr-table">`
  - Extracts captions from preceding `.table-title` divs and inserts them as `<caption>` elements
  - Adds column alignment attributes based on header cell `style` values
  - Ensures proper `<thead>`/`<tbody>` structure
  """

  @doc """
  Wraps all tables in `.fr-table` divs and applies DSFR structure.

  Takes an HTML string (typically from `MDEx.to_html!/1`) and returns a
  modified HTML string with DSFR-compliant table markup.

  ## Examples

  Basic wrapping:

      iex> Dsfr.wrap_tables("<table><tr><th>A</th></tr><tr><td>B</td></tr></table>")
      ~s(<div class="fr-table"><table><colgroup><col/></colgroup><thead><tr><th scope="col">A</th></tr></thead><tbody><tr><td>B</td></tr></tbody></table></div>)

  Captions from preceding `.table-title` divs:

      iex> Dsfr.wrap_tables(~s(<div class="table-title">Ma légende</div><table><tr><th>A</th></tr></table>))
      ~s(<div class="fr-table"><table><caption>Ma légende</caption><colgroup><col/></colgroup><thead><tr><th scope="col">A</th></tr></thead></table></div>)
  """
  @spec wrap_tables(String.t()) :: String.t()
  def wrap_tables(html) when is_binary(html) do
    parsed = Floki.parse_fragment!(html)
    {nodes, _} = Floki.traverse_and_update(parsed, %{last_title: nil}, &traverse_node/2)
    Floki.raw_html(nodes)
  end

  # ── Node Traversal ────────────────────────────────────────────────────────

  @doc false
  @spec traverse_node(Floki.html_node(), map()) :: {Floki.html_node() | [], map()}

  # `.table-title` div: extract text, remove from DOM, pass title forward.
  # Orphan titles (no following table) are silently dropped.
  defp traverse_node({"div", [{"class", "table-title"}], children}, acc) do
    title_text = Floki.text(children) |> String.trim()
    {[], %{acc | last_title: title_text}}
  end

  # `<table>` with a pending caption
  defp traverse_node({"table", _attrs, children}, %{last_title: title} = acc)
       when is_binary(title) and title != "" do
    new_acc = %{acc | last_title: nil}

    {wrap_table(children) |> insert_caption(title) |> dsfr_table(), new_acc}
  end

  # `<table>` without a caption
  defp traverse_node({"table", _attrs, children}, acc) do
    {wrap_table(children) |> dsfr_table(), acc}
  end

  # All other nodes pass through unchanged, no state change
  defp traverse_node(node, acc), do: {node, acc}

  # ── Table Wrapping ────────────────────────────────────────────────────────

  @spec wrap_table([Floki.html_node()]) :: Floki.html_node()
  defp wrap_table(children) do
    {header_row, body_rows} = partition_rows(children)

    # Add scope="col" to header cells if not present
    header_row = ensure_scope_col(header_row)

    # Preserve existing colgroup (e.g. column widths from raw HTML),
    # only build one when there isn't already one and we have headers.
    colgroup =
      case Enum.find(children, fn {tag, _, _} -> tag == "colgroup" end) do
        nil -> build_colgroup(header_row)
        existing -> existing
      end

    thead = if header_row, do: {"thead", [], [header_row]}, else: nil
    tbody = if body_rows != [], do: {"tbody", [], body_rows}, else: nil

    table_children = List.flatten([colgroup, thead, tbody]) |> Enum.filter(& &1)
    {"table", [], table_children}
  end

  defp dsfr_table(children) do
    {"div", [{"class", "fr-table"}], children}
  end

  @spec insert_caption(Floki.html_node(), String.t()) :: Floki.html_node()
  defp insert_caption({"table", attrs, children}, title) do
    {"table", attrs, [{"caption", [], [title]} | children]}
  end

  # ── Row Partitioning ──────────────────────────────────────────────────────

  @spec partition_rows([Floki.html_node()]) :: {Floki.html_node() | nil, [Floki.html_node()]}
  defp partition_rows(children) do
    # Extract rows from thead/tbody if present, or use direct tr children
    rows =
      Enum.flat_map(children, fn
        {"thead", _, rows} -> rows
        {"tbody", _, rows} -> rows
        {"tr", _, _} = row -> [row]
        _ -> []
      end)

    case rows do
      [] ->
        {nil, []}

      [first | rest] ->
        is_header? = has_th?(first)
        if is_header?, do: {first, rest}, else: {nil, rows}
    end
  end

  @spec has_th?(Floki.html_node()) :: boolean()
  defp has_th?(node) do
    Enum.any?(Floki.find(node, "th")) or
      Enum.any?(Floki.find(node, "td strong"), fn {"strong", _, _} -> true end)
  end

  @spec has_strong?([any()]) :: boolean()
  defp has_strong?(children), do: Enum.any?(children, &has_strong_in_node?/1)

  @spec has_strong_in_node?(any()) :: boolean()
  defp has_strong_in_node?({"strong", _, _}), do: true
  defp has_strong_in_node?(node) when is_list(node), do: Enum.any?(node, &has_strong_in_node?/1)
  defp has_strong_in_node?(_), do: false

  @doc false
  @spec strip_strong([any()]) :: [any()]
  defp strip_strong(children) when is_list(children) do
    Enum.flat_map(children, &strip_strong_one/1)
  end

  @spec strip_strong_one(any()) :: [any()]
  defp strip_strong_one({"strong", _, children}), do: strip_strong(children)
  defp strip_strong_one(other), do: [other]

  # ── Column Alignment ──────────────────────────────────────────────────────

  @spec build_colgroup(Floki.html_node() | nil) :: Floki.html_node() | nil
  defp build_colgroup(nil), do: nil

  defp build_colgroup({"tr", _, cells}) do
    cols = Enum.map(cells, &cell_to_col/1)
    {"colgroup", [], cols}
  end

  @spec cell_to_col(Floki.html_node()) :: Floki.html_node()
  defp cell_to_col({"th", attrs, _children}) do
    alignment = extract_alignment(attrs)
    if alignment, do: {"col", [{"style", alignment}], []}, else: {"col", [], []}
  end

  defp cell_to_col({"td", attrs, _children}) do
    alignment = extract_alignment(attrs)
    if alignment, do: {"col", [{"style", alignment}], []}, else: {"col", [], []}
  end

  @spec extract_alignment([{atom(), String.t()}]) :: String.t() | nil
  defp extract_alignment(attrs) do
    # Try style attribute first (text-align)
    case safe_kwget(attrs, "style") do
      nil ->
        # Fall back to align attribute
        case safe_kwget(attrs, "align") do
          "center" -> "text-align:center"
          "right" -> "text-align:right"
          "left" -> "text-align:left"
          _ -> nil
        end

      style when is_binary(style) ->
        case Regex.run(~r/text-align\s*:\s*(left|center|right)/i, style) do
          [_, align] -> "text-align:#{align}"
          nil -> nil
        end

      _ ->
        nil
    end
  end

  # Safely get a value from Floki-style attribute lists (string keys)
  def safe_kwget([], _key), do: nil
  def safe_kwget([{"style", value} | _], "style"), do: value
  def safe_kwget([{"align", value} | _], "align"), do: value
  def safe_kwget([{"scope", value} | _], "scope"), do: value
  def safe_kwget([_ | tail], key), do: safe_kwget(tail, key)

  @spec ensure_scope_col(Floki.html_node() | nil) :: Floki.html_node() | nil
  defp ensure_scope_col(nil), do: nil

  defp ensure_scope_col({"tr", attrs, cells}) do
    updated_cells =
      Enum.map(cells, fn
        {"th", th_attrs, children} when is_list(th_attrs) ->
          has_scope? = safe_kwget(th_attrs, :scope) == "col"

          if has_scope?,
            do: {"th", th_attrs, children},
            else: {"th", [{"scope", "col"} | th_attrs], children}

        {"td", td_attrs, children} when is_list(td_attrs) ->
          if has_strong?(children),
            do: {"th", [{"scope", "col"}], strip_strong(children)},
            else: {"td", td_attrs, children}

        other ->
          other
      end)

    {"tr", attrs, updated_cells}
  end
end
