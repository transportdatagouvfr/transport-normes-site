defmodule SiteDeNormes.FrontMatter do
  @moduledoc """
  MDEx plugin showing the front matter of a page (the YAML block at its top)
  as highlighted code in a DSFR callout, instead of hiding it.
  """

  alias MDEx.Document

  def attach(document) do
    document
    # Parses the front matter into a %MDEx.FrontMatter{} node (otherwise hidden by MDEx)
    |> Document.put_extension_options(front_matter_delimiter: "---")
    |> Document.append_steps(front_matter_as_code: &as_code/1)
  end

  defp as_code(document) do
    MDEx.traverse_and_update(document, fn
      %MDEx.FrontMatter{literal: literal} ->
        yaml = literal |> String.trim() |> String.trim("---") |> String.trim()
        # Escapes the YAML. Only colors the tokens (:inline), with light-dark() colors
        # following the light/dark mode, so that the code sits on the callout background
        code =
          Lumis.highlight!(yaml,
            formatter:
              {:html_multi_themes,
               language: "yaml",
               structure: :inline,
               themes: [light: "github_light", dark: "github_dark"],
               default_theme: "light-dark()"}
          )

        # Rendered as is, whatever the :unsafe option
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
