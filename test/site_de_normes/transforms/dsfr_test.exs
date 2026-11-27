defmodule SiteDeNormes.Transforms.DsfrTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.Transforms.Dsfr
  import LazyHTML, only: [from_fragment: 1, query: 2, text: 1]

  # Dsfr = SiteDeNormes.Transforms.Dsfr (table wrapping + FAQ accordion)
  doctest Dsfr

  # ── GFM table wrapping ───────────────────────────────────────────────────

  describe "table wrapper" do
    test "wraps a simple GFM table in fr-table div" do
      html = process("| A | B |\n|---|---|\n| 1 | 2 |")

      assert html |> query(".fr-table") |> is_present?()
      assert html |> query(".fr-table table") |> is_present?()
    end

    test "produces valid DSFR structure" do
      html = process("| Name | Value |\n|---|---|\n| x | y |")

      assert html |> query("div.fr-table") |> is_present?()
      assert html |> query("table") |> is_present?()
    end

    test "wraps raw HTML tables too" do
      html = Dsfr.wrap_tables("<table><tr><td>hello</td></tr></table>")

      assert String.contains?(html, ~s(<div class="fr-table fr-table--multiline">))
      assert String.contains?(html, "<table>")
    end
  end

  # ── Header / body rows ───────────────────────────────────────────────────

  describe "row serialization" do
    test "serializes header rows as <th> with scope=\"col\"" do
      html = process("| Name | Value |\n|---|---|\n| x | y |")

      assert texts_of(html, ".fr-table th") == ["Name", "Value"]

      # Check scope attribute
      th_nodes = html |> query(".fr-table th") |> LazyHTML.to_tree()

      assert Enum.any?(th_nodes, fn node ->
               case node do
                 {"th", attrs, _} -> Dsfr.safe_kwget(attrs, "scope") == "col"
                 _ -> false
               end
             end)
    end

    test "serializes body rows as <td>" do
      html = process("| A |\n|---|\n| B |")

      assert texts_of(html, ".fr-table td") == ["B"]
    end

    # The DSFR table JS crashes on a table without <tbody> (issue #52)
    test "handles tables with only a header" do
      html = process("| Header |\n|---|")

      refute html |> query("thead") |> is_present?()
      assert html |> query("tbody") |> is_present?()
    end

    test "treats a single-row table as data, not as a header" do
      html = process("| **Classification** | Nom |\n|---|---|")

      refute html |> query("thead") |> is_present?()
      refute html |> query("th") |> is_present?()
      assert texts_of(html, "tbody td") == ["Classification", "Nom"]
      assert html |> query("tbody td strong") |> is_present?()
    end

    test "handles tables with body rows" do
      html = process("| A |\n|---|\n| B |")

      assert html |> query("thead") |> is_present?()
      assert html |> query("tbody") |> is_present?()
    end
  end

  # ── Column alignment ─────────────────────────────────────────────────────

  describe "column alignment" do
    test "generates colgroup from column alignments" do
      html = process("| Left | Center | Right |\n|---|:-:|---:|\n| a | b | c |")

      # Check colgroup exists
      assert html |> query("colgroup") |> is_present?()

      # Check alignment styles on cols
      col_nodes = html |> query("colgroup col") |> LazyHTML.to_tree()

      col_styles =
        Enum.map(col_nodes, fn
          {"col", attrs, _} -> Dsfr.safe_kwget(attrs, "style")
          _ -> nil
        end)

      # Center and right must be present; left is the default (may be nil)
      assert "text-align:center" in col_styles
      assert "text-align:right" in col_styles
    end

    test "default alignment produces plain <col>" do
      html = process("| A | B |\n|---|---|\n| 1 | 2 |")

      col_nodes = html |> query("colgroup col") |> LazyHTML.to_tree()
      assert length(col_nodes) == 2
    end
  end

  # ── Table captions ───────────────────────────────────────────────────────

  describe "table captions from .table-title divs" do
    test "converts preceding .table-title into a <caption> element" do
      html =
        "<div class=\"table-title\">Ma légende</div>\n<table><tr><th>A</th></tr></table>"
        |> Dsfr.wrap_tables()
        |> from_fragment()

      assert texts_of(html, "caption") == ["Ma légende"]
    end

    test "strips HTML tags from title text" do
      html =
        "<div class=\"table-title\"><strong>Bold title</strong></div>\n<table><tr><th>A</th></tr></table>"
        |> Dsfr.wrap_tables()
        |> from_fragment()

      assert texts_of(html, "caption") == ["Bold title"]
    end

    test "orphan title without following table is dropped" do
      html =
        "<div class=\"table-title\">Orphan</div>\n<p>No table here</p>"
        |> Dsfr.wrap_tables()

      refute String.contains?(html, ~s(class="table-title"))
    end

    test "multiple tables each get their own caption" do
      html =
        ("<div class=\"table-title\">First</div>\n<table><tr><th>A</th></tr></table>" <>
           "<div class=\"table-title\">Second</div>\n<table><tr><th>B</th></tr></table>")
        |> Dsfr.wrap_tables()
        |> from_fragment()

      assert texts_of(html, "caption") == ["First", "Second"]
    end

    test "title div is removed when paired with a table" do
      html =
        "<div class=\"table-title\">Caption</div>\n<table><tr><th>A</th></tr></table>"
        |> Dsfr.wrap_tables()

      refute String.contains?(html, ~s(class="table-title"))
    end
  end

  # ── Integration with other transforms ────────────────────────────────────

  describe "works alongside other plugins" do
    test "navigation plugin and DSFR table transform coexist" do
      html =
        MDEx.new(markdown: "# Title\n\n| Col |\n|---|\n| Val |", extension: [table: true])
        |> SiteDeNormes.Transforms.Navigation.attach()
        |> MDEx.Document.run()
        |> MDEx.to_html!()
        |> Dsfr.wrap_tables()

      assert String.contains?(html, ~s(id="title"))
      assert String.contains?(html, ~s(<div class="fr-table fr-table--multiline">))
    end
  end

  # ── Fake header detection ────────────────────────────────────────────────

  describe "fake headers: <td><strong> → <th scope=\"col\">" do
    test "converts first row td to th and strips the strong wrapper" do
      html =
        """
        <table>
        <tbody>
        <tr class="odd">
        <td><strong>Niveau</strong></td>
        <td><strong>Catégorie</strong></td>
        </tr>
        <tr class="even">
        <td>1</td>
        <td>Location search</td>
        </tr>
        </tbody>
        </table>
        """
        |> Dsfr.wrap_tables()

      assert String.contains?(html, ~s(<th scope="col">Niveau</th>))
      refute String.contains?(html, ~s(<th scope="col"><strong>Niveau</strong></th>))
      assert String.contains?(html, ~s(<thead>))
    end

    test "leaves non-strong td rows as body" do
      html =
        """
        <table>
        <tbody>
        <tr><td>plain cell</td></tr>
        </tbody>
        </table>
        """
        |> Dsfr.wrap_tables()

      refute String.contains?(html, ~s(<thead>))
      assert String.contains?(html, ~s(<td>plain cell</td>))
    end

    test "converts td without strong content to th in header row" do
      html =
        """
        <table>
        <tr><td>Label</td><td><strong>Value</strong></td></tr>
        <tr><td>a</td><td>b</td></tr>
        </table>
        """
        |> Dsfr.wrap_tables()

      # Both cells should be th (first row is header because of strong content)
      assert texts_of(html, "th") == ["Label", "Value"]
    end

    test "preserves td attributes when converting to th" do
      html =
        """
        <table>
        <tr><td class="highlight" colspan="2"><strong>Title</strong></td></tr>
        <tr><td>a</td><td>b</td></tr>
        </table>
        """
        |> Dsfr.wrap_tables()

      # Attributes preserved when converting td to th
      assert String.contains?(html, ~s(<th scope="col" class="highlight" colspan="2">Title</th>))
    end
  end

  # ── Real NetEx FR content ────────────────────────────────────────────────

  describe "real NetEx FR raw HTML tables" do
    test "preserves existing colgroup with width styles" do
      markdown =
        """
        <div class="table-title">Concepts relatifs à la LOM</div>

        <table>
        <colgroup>
        <col style="width: 7%" />
        <col style="width: 15%" />
        <col style="width: 17%" />
        </colgroup>
        <thead>
        <tr class="header">
        <th><strong>Niveau</strong></th>
        <th><strong>Catégorie</strong></th>
        <th><strong>Détail</strong></th>
        </tr>
        </thead>
        <tbody>
        <tr class="odd">
        <td><strong>1</strong></td>
        <td><em><strong>Location search</strong></em></td>
        <td>Address identifiers</td>
        </tr>
        </tbody>
        </table>
        """

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> Dsfr.wrap_tables()

      # Colgroup with widths must survive
      assert col_widths(html) == ["width: 7%", "width: 15%", "width: 17%"]
    end
  end

  # ── Full pipeline integration ────────────────────────────────────────────

  describe "full pipeline: markdown → MDEx → to_html! → wrap_tables" do
    test "table-title div preceding a GFM table produces a caption" do
      markdown =
        "<div class=\"table-title\">Ma légende</div>\n\n| Col A | Col B |\n|---|---|\n| x | y |"

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> Dsfr.wrap_tables()

      # Caption should exist and contain the title text
      assert texts_of(html, "caption") == ["Ma légende"]

      # Original .table-title div should be gone
      refute String.contains?(html, ~s(class="table-title"))

      lazy = from_fragment(html)

      # Table should be wrapped in fr-table
      assert lazy |> query(".fr-table") |> is_present?()
    end

    test "multiple table-title divs with GFM tables each get captions" do
      markdown =
        "<div class=\"table-title\">First table</div>\n\n| A | B |\n|---|---|\n| 1 | 2 |" <>
          "\n\n<div class=\"table-title\">Second table</div>\n\n| C | D |\n|---|---|\n| 3 | 4 |"

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> Dsfr.wrap_tables()

      assert texts_of(html, "caption") == ["First table", "Second table"]
    end

    test "table-title with inline HTML is stripped in caption" do
      markdown =
        "<div class=\"table-title\"><strong>Bold title</strong></div>\n\n| A |\n|---|\n| B |"

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> Dsfr.wrap_tables()

      assert texts_of(html, "caption") == ["Bold title"]
    end

    test "orphan table-title without following GFM table is dropped" do
      markdown = "<div class=\"table-title\">Orphan</div>\n\nJust some text"

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> Dsfr.wrap_tables()

      refute String.contains?(html, ~s(class="table-title"))
    end
  end

  # ── Non-breaking space preservation ──────────────────────────────────────

  describe "non-breaking space (U+00A0) preservation" do
    test "preserves NBSP in table cells (html5ever keeps raw \u00A0)" do
      # « PK » with non-breaking spaces around PK
      html =
        "<table><tr><th>«\u00A0PK\u00A0»</th></tr></table>"
        |> Dsfr.wrap_tables()

      # html5ever preserves \u00A0 raw — browser renders it correctly
      assert String.contains?(html, "\u00A0")
    end

    test "preserves NBSP in prose alongside tables" do
      html =
        "<p>L'harmonisation\u00A0: un enjeu</p>"
        |> Dsfr.wrap_tables()

      # NBSP preserved in prose too
      assert String.contains?(html, "\u00A0")
    end

    test "does not alter <pre> block content" do
      pre_block = "<pre><code>lignes\u00A0avec\u00A0nbsp</code></pre>"
      html = Dsfr.wrap_tables(pre_block)

      # Pre blocks are restored verbatim (original NBSP, not &nbsp;)
      assert String.contains?(html, "\u00A0")
    end
  end

  # ── Edge cases ───────────────────────────────────────────────────────────

  describe "edge cases" do
    test "empty input produces unchanged output" do
      html = Dsfr.wrap_tables("")
      assert html == ""
    end

    test "table with no rows produces minimal structure" do
      html = "<table></table>" |> Dsfr.wrap_tables() |> from_fragment()

      assert html |> query(".fr-table") |> is_present?()
      assert html |> query("table") |> is_present?()
    end

    test "nested inline elements in cells are preserved" do
      html = process("| **Bold** | *Italic* |\n|---|---|\n| `code` | link |")

      assert texts_of(html, ".fr-table th") == ["Bold", "Italic"]
    end

    test "caption is inside table element" do
      html =
        "<div class=\"table-title\">My Table</div>\n<table><tr><th>A</th></tr></table>"
        |> Dsfr.wrap_tables()
        |> from_fragment()

      # Caption should be a direct child of the table
      assert html |> query("table caption") |> is_present?()
    end

    test "fr-table wraps the table element" do
      html =
        "<table><tr><th>A</th></tr></table>"
        |> Dsfr.wrap_tables()
        |> from_fragment()

      # the table is the direct child of the fr-table__content div
      assert html |> query(".fr-table__content > table") |> is_present?()
    end
  end

  # ── FAQ Accordion Wrapping ───────────────────────────────────────────────

  describe "FAQ accordion wrapping" do
    test "wraps two consecutive details in an accordion group" do
      html =
        Dsfr.wrap_faqs(
          ~s|<details><summary>Q1</summary><p>A1</p></details><details><summary>Q2</summary><p>A2</p></details>|
        )

      assert String.contains?(html, ~s(<div class="fr-accordions-group">))
      assert String.contains?(html, ~s(<div class="fr-accordion">))
      refute String.contains?(html, ~s(<details>))
    end

    test "converts each details to accordion with correct structure" do
      html =
        Dsfr.wrap_faqs(
          ~s|<details><summary>Question?</summary><p>Answer</p></details><details><summary>Q2</summary><p>A2</p></details>|
        )

      # Check accordion button structure
      assert String.contains?(html, ~s(<h3 class="fr-accordion__title">))

      assert String.contains?(
               html,
               ~s(<button class="fr-accordion__btn" aria-expanded="false" aria-controls="accordion-0">Question?</button>)
             )

      assert String.contains?(
               html,
               ~s(<div class="fr-collapse fr-accordion__content" id="accordion-0">)
             )
    end

    test "preserves content inside details (excluding summary)" do
      html =
        Dsfr.wrap_faqs(
          ~s|<details><summary>Q</summary><p>Paragraph</p><ul><li>Item</li></ul></details><details><summary>Q2</summary><p>A2</p></details>|
        )

      assert String.contains?(html, "<p>Paragraph</p>")
      assert String.contains?(html, "<ul><li>Item</li></ul>")
    end

    test "leaves single details unchanged" do
      html = Dsfr.wrap_faqs(~s|<details><summary>Only one</summary><p>Content</p></details>|)

      refute String.contains?(html, ~s(class="fr-accordions-group"))
      assert String.contains?(html, ~s(<details>))
    end

    test "leaves non-consecutive details unchanged" do
      html =
        Dsfr.wrap_faqs(
          ~s|<p>Between</p><details><summary>Q1</summary><p>A1</p></details><p>Between</p><details><summary>Q2</summary><p>A2</p></details>|
        )

      refute String.contains?(html, ~s(class="fr-accordions-group"))
      # original two + header
      assert html |> String.split("<details>") |> length() == 3
    end

    test "skips whitespace between details" do
      html =
        Dsfr.wrap_faqs(
          ~s|<details><summary>Q1</summary><p>A1</p></details>\n\n<details><summary>Q2</summary><p>A2</p></details>|
        )

      assert String.contains?(html, ~s(<div class="fr-accordions-group">))
    end

    test "generates sequential unique IDs" do
      html =
        Dsfr.wrap_faqs(
          ~s|<details><summary>1</summary><p>a</p></details><details><summary>2</summary><p>b</p></details><details><summary>3</summary><p>c</p></details>|
        )

      assert String.contains?(html, ~s(id="accordion-0"))
      assert String.contains?(html, ~s(id="accordion-1"))
      assert String.contains?(html, ~s(id="accordion-2"))
      # aria-controls must match corresponding id
      assert String.contains?(html, ~s(aria-controls="accordion-0"))
      assert String.contains?(html, ~s(aria-controls="accordion-1"))
      assert String.contains?(html, ~s(aria-controls="accordion-2"))
    end

    test "handles multiple separate detail groups" do
      html =
        Dsfr.wrap_faqs(
          ~s|<details><summary>A1</summary><p>a1</p></details><details><summary>A2</summary><p>a2</p></details><p>Middle</p><details><summary>B1</summary><p>b1</p></details><details><summary>B2</summary><p>b2</p></details>|
        )

      # Should produce two accordion groups
      assert String.contains?(html, ~s(<div class="fr-accordions-group">))
      # Count occurrences (should be 2)
      # 2 separators = 3 parts
      assert String.split(html, ~s(class="fr-accordions-group")) |> length() == 3
    end

    test "handles empty input" do
      html = Dsfr.wrap_faqs("")
      assert html == ""
    end

    test "preserves other HTML elements around details" do
      html =
        Dsfr.wrap_faqs(
          ~s|<h2>FAQ</h2><details><summary>Q1</summary><p>A1</p></details><details><summary>Q2</summary><p>A2</p></details><p>After</p>|
        )

      assert String.contains?(html, ~s(<h2>FAQ</h2>))
      assert String.contains?(html, ~s(<p>After</p>))
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp to_html(markdown) do
    MDEx.new(markdown: markdown, extension: [table: true])
    |> MDEx.Document.run()
    |> MDEx.to_html!()
  end

  defp process(markdown) do
    markdown |> to_html() |> Dsfr.wrap_tables() |> from_fragment()
  end

  defp is_present?(%LazyHTML{} = lazy_html) do
    # Convert to tree and check if non-empty
    case LazyHTML.to_tree(lazy_html) do
      [] -> false
      _ -> true
    end
  end

  defp is_present?([]), do: false
  defp is_present?(%{}), do: true
  defp is_present?(_), do: true

  defp texts_of(html, selector) when is_binary(html) do
    html
    |> from_fragment()
    |> query(selector)
    |> Enum.map(&text/1)
  end

  defp texts_of(lazy_html, selector) do
    lazy_html
    |> query(selector)
    |> Enum.map(&text/1)
  end

  defp col_widths(html_or_fragment) do
    html_or_fragment
    |> from_fragment()
    |> query("colgroup col")
    |> LazyHTML.to_tree()
    |> Enum.map(fn
      {"col", attrs, _} -> Dsfr.safe_kwget(attrs, "style") || ""
      _ -> ""
    end)
  end
end
