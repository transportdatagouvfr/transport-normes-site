defmodule SiteDeNormes.Transforms.DsfrTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.Transforms.Dsfr
  import LazyHTML, only: [from_fragment: 1, query: 2, text: 1]

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

  # Helper to safely get values from Floki-style attribute lists (string keys)
  defp kwget([], _key), do: nil
  defp kwget([{"scope", value} | _], "scope"), do: value
  defp kwget([{"style", value} | _], "style"), do: value
  defp kwget([{"align", value} | _], "align"), do: value
  defp kwget([_ | tail], key), do: kwget(tail, key)

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

      assert String.contains?(html, ~s(<div class="fr-table">))
      assert String.contains?(html, "<table>")
    end
  end

  # ── Header / body rows ───────────────────────────────────────────────────

  describe "row serialization" do
    test "serializes header rows as <th> with scope=\"col\"" do
      html = process("| Name | Value |\n|---|---|\n| x | y |")

      th_text = html |> query(".fr-table th") |> text()
      assert String.contains?(th_text, "Name")
      assert String.contains?(th_text, "Value")

      # Check scope attribute
      th_nodes = html |> query(".fr-table th") |> LazyHTML.to_tree()

      assert Enum.any?(th_nodes, fn node ->
               case node do
                 {"th", attrs, _} -> kwget(attrs, "scope") == "col"
                 _ -> false
               end
             end)
    end

    test "serializes body rows as <td>" do
      html = process("| A |\n|---|\n| B |")

      td_text = html |> query(".fr-table td") |> text()
      assert String.contains?(td_text, "B")
    end

    test "handles tables with only a header" do
      html = process("| Header |\n|---|")

      assert html |> query("thead") |> is_present?()
      refute html |> query("tbody") |> is_present?()
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
          {"col", attrs, _} -> kwget(attrs, "style")
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

      assert html |> query("caption") |> is_present?()
      caption_text = html |> query("caption") |> text()
      assert String.contains?(caption_text, "Ma légende")
    end

    test "strips HTML tags from title text" do
      html =
        "<div class=\"table-title\"><strong>Bold title</strong></div>\n<table><tr><th>A</th></tr></table>"
        |> Dsfr.wrap_tables()
        |> from_fragment()

      caption_text = html |> query("caption") |> text()
      assert String.contains?(caption_text, "Bold title")
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

      caption_texts = html |> query("caption") |> text()
      assert String.contains?(caption_texts, "First")
      assert String.contains?(caption_texts, "Second")
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
      assert String.contains?(html, ~s(<div class="fr-table">))
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

      lazy = from_fragment(html)

      # Caption should exist and contain the title text
      assert lazy |> query("caption") |> is_present?()
      caption_text = lazy |> query("caption") |> text()
      assert String.contains?(caption_text, "Ma légende")

      # Original .table-title div should be gone
      refute String.contains?(html, ~s(class="table-title"))

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

      lazy = from_fragment(html)
      caption_texts = lazy |> query("caption") |> text()

      assert String.contains?(caption_texts, "First table")
      assert String.contains?(caption_texts, "Second table")
    end

    test "table-title with inline HTML is stripped in caption" do
      markdown =
        "<div class=\"table-title\"><strong>Bold title</strong></div>\n\n| A |\n|---|\n| B |"

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> Dsfr.wrap_tables()

      lazy = from_fragment(html)
      caption_text = lazy |> query("caption") |> text()

      assert String.contains?(caption_text, "Bold title")
      refute String.contains?(caption_text, "<strong>")
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

      th_text = html |> query(".fr-table th") |> text()
      assert String.contains?(th_text, "Bold")
      assert String.contains?(th_text, "Italic")
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

      # .fr-table should contain the table
      assert html |> query(".fr-table > table") |> is_present?()
    end
  end
end
