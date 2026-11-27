defmodule SiteDeNormes.Transforms.BlockquoteToHighlight do
  @moduledoc """
  MDEx plugin that converts blockquotes to DSFR highlights.

  Walks the parsed Markdown tree and replaces every `BlockQuote` (and
  `MultilineBlockQuote`) node with an `MDEx.Raw` containing a DSFR-highlight
  wrapper div around the rendered children. This runs at AST level, before
  HTML rendering, so the highlight markup is produced directly by the comrak
  formatter — no post-processing needed.

  ## Example

      iex> markdown = \"\"\"
      ...> # Title
      ...>
      ...> > A quoted note.
      ...> \"\"\"
      iex> doc = MDEx.new(markdown: markdown, extension: [table: true]) |> MDEx.Document.run()
      iex> result = BlockquoteToHighlight.attach(doc)
      iex> html = MDEx.to_html!(result)
      iex> String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      true
      iex> String.contains?(html, "<blockquote>")
      false
  """

  alias MDEx.Document

  @doc """
  Replaces all blockquotes with DSFR highlight markup in the document AST.

  Passes the document through `MDEx.traverse_and_update/2` and replaces every
  `BlockQuote` or `MultilineBlockQuote` node with an `MDEx.Raw` containing a
  `.fr-highlight` wrapper div around the rendered children.

  Must be called **after** `MDEx.Document.run/1` when the AST is available,
  and **before** `MDEx.to_html!/1`.
  """
  @spec attach(Document.t()) :: Document.t()
  def attach(document) do
    MDEx.traverse_and_update(document, fn
      %{__struct__: MDEx.BlockQuote} = bq -> convert_blockquote(bq)
      %{__struct__: MDEx.MultilineBlockQuote} = mbq -> convert_blockquote(mbq)
      node -> node
    end)
  end

  defp convert_blockquote(%{nodes: children}) do
    # Render the children to HTML, then wrap in DSFR highlight markup.
    # We create a temporary document with just these nodes so MDEx.to_html!/1
    # can render them through comrak's HTML formatter.
    temp_doc = %Document{nodes: children, private: %{}}
    rendered = MDEx.to_html!(temp_doc)

    %MDEx.Raw{
      literal: "<div class=\"fr-highlight fr-highlight--default\" role=\"note\">#{rendered}</div>"
    }
  end
end
