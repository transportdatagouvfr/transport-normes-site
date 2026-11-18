defmodule SiteDeNormes.Transforms.DropEmbeddedStylesheets do
  @moduledoc """
  MDEx plugin that removes `<style>` blocks from the document AST.

  Walks the parsed Markdown tree and removes any `HtmlBlock` or `HtmlInline` node
  whose literal content contains a `<style>` tag (opening or closing). This prevents
  embedded CSS from leaking into the rendered HTML output, since styles are already
  defined in the page template.

  ## Example

      iex> markdown = \"\"\"
      ...> # Title
      ...>
      ...> <style>.hl { background: yellow; }</style>
      ...>
      ...> Some text.
      ...> \"\"\"
      iex> doc = MDEx.new(markdown: markdown, extension: [table: true]) |> MDEx.Document.run()
      iex> result = DropEmbeddedStylesheets.attach(doc)
      iex> html = MDEx.to_html!(result)
      iex> String.contains?(html, "<style>")
      false
      iex> String.contains?(html, "# Title")
      true
  """

  alias MDEx.Document

  @doc """
  Drops embedded `<style>` blocks from a parsed document AST.

  Passes the document through `MDEx.traverse_and_update/2` and removes any
  `HtmlBlock` or `HtmlInline` node whose literal content contains a `<style>`
  tag (opening or closing). The modified document is returned.

  Must be called **after** `MDEx.Document.run/1` when the AST is available.
  """
  @spec attach(Document.t()) :: Document.t()
  def attach(document) do
    MDEx.traverse_and_update(document, fn
      %{__struct__: MDEx.HtmlBlock} = hb ->
        if contains_style?(hb.literal), do: nil, else: hb

      %{__struct__: MDEx.HtmlInline} = hi ->
        if contains_style?(hi.literal), do: nil, else: hi

      node ->
        node
    end)
  end

  defp contains_style?(text) when is_binary(text) do
    String.contains?(text, "<style>") or String.contains?(text, "</style>")
  end

  defp contains_style?(_), do: false
end
