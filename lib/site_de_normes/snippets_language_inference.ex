defmodule SiteDeNormes.SnippetsLanguageInference do
  @moduledoc """
  MDEx plugin that infers the language of unlabelled code blocks.

  Currently detects XML content and sets the `info` field to `"xml"`, enabling
  syntax highlighting in the rendering pipeline.

  ## Example

      iex> doc = MDEx.new(markdown: "<root><child/></root>")
      ...> |> SiteDeNormes.SnippetsLanguageInference.attach()
      ...> |> MDEx.Document.run()
      ...> |> MDEx.to_html!()
      "<pre><code class=\"language-xml\">&lt;root&gt;&lt;child/&gt;&lt;/root&gt;</code></pre>\\n"

  ## Heuristic

  A code block is labelled `xml` if its literal content matches any of:

  - An XML declaration (`<?xml`)
  - A DTD declaration (`<!DOCTYPE`, `<!ELEMENT`, etc.)
  - At least one opening tag `<tag...>` and one closing tag `</tag>`

  This is intentionally permissive — anything that looks like tagged markup gets
  the `xml` label.
  """

  alias MDEx.Document

  @doc """
  Attaches the language inference step to the document pipeline.
  """
  @spec attach(Document.t()) :: Document.t()
  def attach(document) do
    document
    |> Document.append_steps(infer_language: &infer/1)
  end

  # --- step ---

  defp infer(document) do
    MDEx.traverse_and_update(document, fn
      %MDEx.CodeBlock{info: "", fenced: true} = node ->
        case detect_language(node.literal) do
          :xml -> %{node | info: "xml"}
          _ -> node
        end

      node ->
        node
    end)
  end

  # --- detection ---

  @doc """
  Detects the language of a code block's literal content.

  Returns `:xml` if the content looks like XML, `nil` otherwise.
  """
  @spec detect_language(String.t()) :: :xml | nil
  def detect_language(literal) when is_binary(literal) do
    cond do
      has_xml_declaration?(literal) -> :xml
      has_dtd_declaration?(literal) -> :xml
      has_matching_tags?(literal) -> :xml
      true -> nil
    end
  end

  defp has_xml_declaration?(literal) do
    String.match?(literal, ~r/^\s*<\?xml/)
  end

  defp has_dtd_declaration?(literal) do
    String.match?(literal, ~r/<!DOCTYPE|<!ELEMENT|<!ATTLIST|<!ENTITY/)
  end

  defp has_matching_tags?(literal) do
    opening_names = Regex.scan(~r{<([A-Za-z][\w:-]*)(?:\s|/>)|<([A-Za-z][\w:-]*)>}, literal)
    closing_names = Regex.scan(~r{</([A-Za-z][\w:-]*)>}, literal)

    opening_tag_names =
      Enum.flat_map(opening_names, fn
        [_, "", name] when is_binary(name) -> [name]
        [_, name] when is_binary(name) and name != "" -> [name]
        _ -> []
      end)

    closing_tag_names =
      Enum.map(closing_names, fn [_, name | _] -> name end)

    # At least one closing tag whose name appears among the opening tags
    Enum.any?(closing_tag_names, &(&1 in opening_tag_names))
  end
end
