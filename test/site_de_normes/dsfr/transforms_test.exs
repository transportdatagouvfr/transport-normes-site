defmodule SiteDeNormes.Dsfr.TransformsTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.Dsfr.Transforms
  import LazyHTML, only: [from_fragment: 1, query: 2]
  import DsfrTestHelpers

  # ── Integration with DSFR table transform ────────────────────────────────

  describe "integration tests" do
    test "tables and figures coexist in the same HTML" do
      markdown =
        "<div class=\"table-title\">My Table</div>\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n![image](media/foo.png)\n*Caption*"

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> Transforms.transform()
        |> from_fragment()

      assert is_present?(query(html, ".fr-table"))
      assert is_present?(query(html, ".fr-figure"))
    end
  end
end
