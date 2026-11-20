defmodule SiteDeNormes.Transforms.Figures do
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

  ## Examples

      iex> Figures.wrap_figures(~s(<p><img src="foo.png" alt="my image"/><em>Caption</em></p>))
      ~s(<figure class="fr-figure fr-figure--image fr-figure--lg"><img src="foo.png" alt="my image"/><figcaption class="fr-caption">Caption</figcaption></figure>)

  Bare images pass through unchanged:

      iex> Figures.wrap_figures(~s(<p><img src="foo.png" alt="my image"/></p>))
      ~s(<p><img src="foo.png" alt="my image"/></p>)
  """

  @doc """
  Wraps all `<img>` + `<em>` pairs in DSFR figure markup.

  Takes an HTML string and returns a modified HTML string with figures
  properly structured per the DSFR specification.
  """
  @spec wrap_figures(String.t()) :: String.t()
  def wrap_figures(html) when is_binary(html) do
    parsed = Floki.parse_fragment!(html)

    # Find all <p> elements that contain an <img> followed by <em>,
    # and replace them with figure(s).
    {nodes, _} = Floki.traverse_and_update(parsed, nil, &handle_p/2)

    nodes
    |> Floki.raw_html()
    |> strip_all_wrappers()
  end

  # ── Node Traversal ────────────────────────────────────────────────────────

  @doc false
  @spec handle_p(Floki.html_node(), any()) :: {Floki.html_node(), any()}

  defp handle_p({"p", attrs, children}, acc) when is_list(children) do
    case extract_img_em(children) do
      {:ok, pre_text, img_tag, em_content, post_text} ->
        figure_html = build_figure_html(img_tag, em_content)
        # Build the output as a string to avoid nested Floki wrappers
        output = build_output_html(pre_text, figure_html, post_text, attrs)
        {extract_elements(output), acc}

      :no_pair ->
        {{"p", attrs, children}, acc}
    end
  end

  defp handle_p(node, acc), do: {node, acc}

  # ── Output builder (string-based to avoid nested wrappers) ────────────────

  @spec build_output_html(String.t(), String.t(), String.t(), [{atom(), String.t()}]) ::
          String.t()
  defp build_output_html(pre_text, figure_html, post_text, _attrs) do
    case {String.trim(pre_text), String.trim(post_text)} do
      {"", ""} ->
        # Just the figure, no surrounding paragraphs
        figure_html

      {pre, ""} ->
        "<p>#{pre}</p>\n#{figure_html}"

      {"", post} ->
        "#{figure_html}\n<p>#{post}</p>"

      {pre, post} ->
        "<p>#{pre}</p>\n#{figure_html}\n<p>#{post}</p>"
    end
  end

  # Extract all real elements from a Floki-parsed fragment,
  # skipping the <html><head></head><body> wrapper that Floki adds.
  @spec extract_elements(String.t()) :: [Floki.html_node()]
  defp extract_elements(html_str) do
    parsed = Floki.parse_fragment!(html_str)
    html_node = List.first(parsed)
    body_children = elem(html_node, 2)
    body_node = Enum.find(body_children, fn {tag, _, _} -> tag == "body" end)
    elem(body_node, 2)
  end

  # ── Extraction ────────────────────────────────────────────────────────────

  @doc false
  @spec extract_img_em([any()]) ::
          {:ok, String.t(), String.t(), String.t(), String.t()} | :no_pair
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

            pre_text = children_to_text(pre) <> children_to_text(between)
            img_tag = Floki.raw_html(img_node)
            em_content = Floki.text(em_node)
            post_text = children_to_text(post)

            {:ok, pre_text, img_tag, em_content, post_text}
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

  @spec children_to_text([any()]) :: String.t()
  defp children_to_text(children) when is_list(children) do
    Enum.map_join(children, &text_node/1)
  end

  @spec text_node(any()) :: String.t()
  defp text_node(text) when is_binary(text), do: text
  defp text_node(_), do: ""

  # ── Building ──────────────────────────────────────────────────────────────

  @doc false
  @spec build_figure_html(String.t(), String.t()) :: String.t()
  defp build_figure_html(img_tag, em_content) do
    "<figure class=\"fr-figure fr-figure--image fr-figure--lg\">#{img_tag}<figcaption class=\"fr-caption\">#{em_content}</figcaption></figure>"
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  @spec img_node?(any()) :: boolean()
  defp img_node?({"img", _, _}), do: true
  defp img_node?(_), do: false

  # ── html5ever compat ─────────────────────────────────────────────────────

  @spec strip_all_wrappers(String.t()) :: String.t()
  defp strip_all_wrappers("") do
    ""
  end

  defp strip_all_wrappers(html) do
    case Regex.run(~r|<html[^>]*><head></head><body>(.*)</body></html>|s, html) do
      [_, inner] -> strip_all_wrappers(inner)
      _ -> html
    end
  end
end
