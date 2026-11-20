defmodule SiteDeNormes.Lint.HtmlInlineTags do
  @moduledoc """
  Detects inline HTML tags (`<span class="hl">`, `<mark>`) used instead of Markdown syntax.

  The DSFR documentation uses `==text==` for highlights (rendered as `<mark>`),
  not raw HTML `<span class="hl">`. This rule flags inline HTML styling that should
  be written in Markdown.

  ## Known patterns

    * `<span class="hl">...</span>` → use `==...==`
    * `<mark>...</mark>` → use `==...==`

  ## Exceptions

  This rule intentionally does NOT flag:
    * `<span lang="...">` — legitimate i18n markup
    * `<span class="Definition">` — DSFR semantic markup (handled by CSS)

  ## Why this matters

  Using Markdown syntax ensures consistency across documents and makes it easier
  to maintain the site. Inline HTML is harder to spot in diffs and may be stripped
  or mangled by sanitization rules.
  """

  @behaviour SiteDeNormes.Lint.Rule

  @impl true
  def name, do: "HTML-INLINE"

  @impl true
  def description do
    "Detects inline HTML tags used instead of Markdown syntax"
  end

  @impl true
  def run({_file_path, document}) do
    document
    |> Enum.filter(&flagged_inline_tag?/1)
    |> Enum.map(fn node -> build_issue(node) end)
  end

  # --- helpers ---

  defp flagged_inline_tag?(%MDEx.HtmlInline{literal: literal}) do
    case literal do
      "<mark" <> _ -> true
      "<span class=\"hl\"" <> _ -> true
      "<span class='hl'" <> _ -> true
      "<span class=\"highlight\"" <> _ -> true
      _ -> false
    end
  end

  defp flagged_inline_tag?(_), do: false

  defp build_issue(%MDEx.HtmlInline{literal: literal, sourcepos: pos}) do
    {line, column} = pos.start

    %{
      code: "HTML-INLINE",
      line: line,
      column: column,
      message: inline_tag_message(literal),
      suggestion: "Use ==text== for highlighted text (renders as <mark> in DSFR)"
    }
  end

  defp inline_tag_message("<mark" <> _),
    do: "Inline HTML tag <mark> found — use Markdown highlight syntax"

  defp inline_tag_message("<span" <> _),
    do: "Inline HTML tag <span class=\"hl\"> found — use Markdown highlight syntax"
end
