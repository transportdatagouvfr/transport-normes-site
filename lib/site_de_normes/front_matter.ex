defmodule SiteDeNormes.FrontMatter do
  @moduledoc """
  MDEx plugin that parses YAML front matter and makes it available on the document,
  while also rendering it as a debug callout in the HTML output.

  Parses the `---` delimited YAML block at the top of a Markdown file into an Elixir map
  and stores it in the document's private fields under `:front_matter`.

  The parsed data is accessible via `MDEx.Document.get_private(doc, :front_matter, %{})`
  after the pipeline runs. This enables features like auto-numbering, custom metadata
  rendering, or any other front-matter-driven behavior.

  Additionally, the raw YAML is displayed as highlighted code in a DSFR callout for
  debugging purposes.

  ## Example

      iex> doc = MDEx.new(markdown: "---\\ntitle: Hello\\nautonumbering: true\\n---\\n# Content")
      ...> |> SiteDeNormes.FrontMatter.attach()
      ...> |> MDEx.Document.run()
      iex> MDEx.Document.get_private(doc, :front_matter, %{})
      %{"title" => "Hello", "autonumbering" => true}
  """

  alias MDEx.Document

  @doc """
  Attaches front matter parsing and debug display to the document.

  Sets one private field:
  - `:front_matter` — parsed YAML map (empty `%{}` if no front matter present)
  """
  @spec attach(Document.t()) :: Document.t()
  def attach(document) do
    document
    |> Document.put_extension_options(front_matter_delimiter: "---")
    |> Document.append_steps(parse_front_matter: &parse/1)
  end

  defp parse(document) do
    {document, literal} =
      MDEx.traverse_and_update(document, nil, fn
        node = %MDEx.FrontMatter{literal: lit}, nil -> {node, lit}
        node, acc when is_nil(acc) -> {node, acc}
        node, acc -> {node, acc}
      end)

    # Parse for private data (always done)
    parsed =
      case literal do
        nil -> nil
        yaml_string -> parse_yaml(yaml_string)
      end

    document =
      if parsed do
        Document.put_private(document, :front_matter, parsed)
      else
        document
      end

    # Render debug callout (only when front matter exists)
    case literal do
      nil -> document
      yaml_string -> render_debug_callout(document, yaml_string)
    end
  end

  defp parse_yaml(literal) do
    yaml = String.trim(literal) |> String.trim("---") |> String.trim()

    case YamlElixir.read_from_string(yaml) do
      {:ok, %{} = map} -> map
      _ -> %{}
    end
  end

  defp render_debug_callout(document, literal) do
    yaml = String.trim(literal) |> String.trim("---") |> String.trim()

    code =
      Lumis.highlight!(yaml,
        formatter:
          {:html_multi_themes,
           language: "yaml",
           structure: :inline,
           themes: [light: "github_light", dark: "github_dark"],
           default_theme: "light-dark()"}
      )

    MDEx.traverse_and_update(document, fn
      %MDEx.FrontMatter{} = _ ->
        %MDEx.Raw{
          literal: """
          <div class="fr-callout">
            <p class="fr-text--xs fr-mb-1w">debugging : front matter de la page</p>
            <pre><code class="language-yaml">#{code}</code></pre>
          </div>
          """
        }

      node ->
        node
    end)
  end
end
