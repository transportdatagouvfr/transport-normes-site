defmodule SiteDeNormes.Dsfr.Figures do
  @moduledoc """
  Post-processing transform for images with captions using Floki.

  Runs after `MDEx.to_html!/1` to convert `<img>` followed by `<em>` caption
  into DSFR-compliant figure components for better accessibility, responsiveness,
  and dark mode support.

  ## Features

  - Wraps `<img>` + `<em>` pairs in `<figure class="fr-figure fr-figure--image fr-figure--lg">`
  - Moves the `<em>` caption into `<figcaption class="fr-caption">`
  - Preserves `alt`, `src`, and other image attributes
  - Leaves bare `<img>` tags (without following `<em>`) unchanged
  """

  @doc false
  @spec transform_tree([Floki.html_node()]) :: [Floki.html_node()]
  def transform_tree(nodes) when is_list(nodes) do
    {result, _} = Floki.traverse_and_update(nodes, nil, &handle_p/2)
    result
  end

  # ── Node Traversal ────────────────────────────────────────────────────────

  @doc false
  @spec handle_p(Floki.html_node(), any()) :: {Floki.html_node(), any()}

  defp handle_p({"p", attrs, children}, acc) when is_list(children) do
    case extract_img_em(children) do
      {:ok, pre_children, img_node, em_content, post_children} ->
        figure = build_figure_node(img_node, em_content)
        output = build_output_nodes(pre_children, figure, post_children)
        {output, acc}

      :no_pair ->
        {{"p", attrs, children}, acc}
    end
  end

  defp handle_p(node, acc), do: {node, acc}

  # ── Output builder (pure tree nodes) ─────────────────────────────────────

  @spec build_output_nodes([any()], Floki.html_node(), [any()]) :: [Floki.html_node()]
  defp build_output_nodes([], figure, []), do: [figure]

  defp build_output_nodes(pre_children, figure, []) do
    [{"p", [], trim_text(pre_children)}, figure]
  end

  defp build_output_nodes([], figure, post_children) do
    [figure, {"p", [], trim_text(post_children)}]
  end

  defp build_output_nodes(pre_children, figure, post_children) do
    [{"p", [], trim_text(pre_children)}, figure, {"p", [], trim_text(post_children)}]
  end

  # Trim leading/trailing whitespace from text nodes in a children list.
  # This mirrors the original String.trim() behavior before splitting into paragraphs.
  @spec trim_text([any()]) :: [any()]
  defp trim_text(children) do
    # Drop leading/trailing all-whitespace nodes
    trimmed =
      children
      |> Enum.drop_while(&whitespace_node?/1)
      |> Enum.reverse()
      |> Enum.drop_while(&whitespace_node?/1)
      |> Enum.reverse()

    case trimmed do
      [] ->
        []

      _ ->
        # Find first and last text nodes and trim them
        {first_idx, last_idx} = find_text_bounds(trimmed)

        case {first_idx, last_idx} do
          {nil, nil} ->
            trimmed

          {f, l} when f == l ->
            # Single text node: trim both ends
            List.update_at(trimmed, f, &String.trim/1)

          _ ->
            trimmed
            |> List.update_at(first_idx, &String.trim_leading/1)
            |> List.update_at(last_idx, &String.trim_trailing/1)
        end
    end
  end

  # Find the indices of the first and last text nodes in a children list.
  @spec find_text_bounds([any()]) :: {integer() | nil, integer() | nil}
  defp find_text_bounds(children) do
    text_indices =
      Enum.with_index(children)
      |> Enum.filter(fn {node, _} -> is_binary(node) end)
      |> Enum.map(&elem(&1, 1))

    case text_indices do
      [] -> {nil, nil}
      [first] -> {first, first}
      [first | rest] -> {first, List.last(rest)}
    end
  end

  @spec whitespace_node?(any()) :: boolean()
  defp whitespace_node?(text) when is_binary(text), do: String.trim(text) == ""
  defp whitespace_node?(_), do: false

  # ── Extraction ────────────────────────────────────────────────────────────

  @doc false
  @spec extract_img_em([any()]) ::
          {:ok, [any()], Floki.html_node(), String.t(), [any()]} | :no_pair
  defp extract_img_em(children) when is_list(children) do
    img_idx = Enum.find_index(children, &img_node?/1)

    case img_idx do
      nil ->
        :no_pair

      _img_idx ->
        {pre, rest} = Enum.split(children, img_idx)
        # rest starts with the img node
        [img_node | after_img] = rest
        em_idx = find_em_index(after_img)

        case em_idx do
          nil ->
            :no_pair

          _em_idx ->
            {between, [em_node | post]} = Enum.split(after_img, em_idx)

            em_content = Floki.text(em_node)
            {:ok, pre ++ between, img_node, em_content, post}
        end
    end
  end

  @spec find_em_index([any()]) :: integer() | nil
  defp find_em_index(children) when is_list(children) do
    Enum.find_index(children, fn
      {"em", _, _} -> true
      _ -> false
    end)
  end

  # ── Building ──────────────────────────────────────────────────────────────

  @doc false
  @spec build_figure_node(Floki.html_node(), String.t()) :: Floki.html_node()
  defp build_figure_node(img_node, em_content) do
    {"figure", [{"class", "fr-figure fr-figure--image fr-figure--lg"}],
     [
       img_node,
       {"figcaption", [{"class", "fr-caption"}], [em_content]}
     ]}
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  @spec img_node?(any()) :: boolean()
  defp img_node?({"img", _, _}), do: true
  defp img_node?(_), do: false
end
