defmodule SiteDeNormes.Lint.Rule do
  @moduledoc """
  Behaviour for content lint rules.

  Each rule is a module that implements this behaviour. Rules are auto-discovered
  from the `SiteDeNormes.Lint` namespace — any module implementing this behaviour
  will be picked up and run against every markdown file.

  ## Example

      defmodule SiteDeNormes.Lint.HtmlInlineTags do
        @behaviour SiteDeNormes.Lint.Rule

        @impl true
        def name, do: "HTML-INLINE"

        @impl true
        def description do
          "Detects inline HTML tags that should be written in Markdown instead"
        end

        @impl true
        def run({_file_path, document}) do
          Enum.filter(document, fn node ->
            %MDEx.HtmlInline{literal: literal} = node
            String.contains?(literal, "<span") or String.contains?(literal, "<mark")
          end)
          |> Enum.map(fn %MDEx.HtmlInline{literal: literal, sourcepos: pos} ->
            %{
              code: "HTML-INLINE",
              line: elem(pos.start, 1),
              column: elem(pos.start, 2),
              message: "Inline HTML tag found — use Markdown syntax instead",
              suggestion: "Use ==text== for highlights"
            }
          end)
        end
      end

  ## Issue map fields

  Each rule returns a list of maps. The report generator adds `file`, `line`, and
  `column` from the AST sourcepos. Rules should provide:

    * `:code` — unique identifier, e.g. `"HTML-INLINE"` (used for docs and filtering)
    * `:message` — human-readable description of the problem
    * `:suggestion` — how to fix it, optionally with a link to documentation
  """

  @doc "Returns the rule's unique code identifier, e.g. \"HTML-INLINE\""
  @callback name :: String.t()

  @doc "Returns a short human-readable description of what this rule checks"
  @callback description :: String.t()

  @doc """
  Runs the rule against a parsed document.

  Receives `{file_path, MDEx.Document}` and returns a list of issue maps:

      [
        %{code: "...", message: "...", suggestion: "..."}
      ]
  """
  @callback run({String.t(), MDEx.Document.t()}) :: [map()]

  @optional_callbacks description: 0
end
