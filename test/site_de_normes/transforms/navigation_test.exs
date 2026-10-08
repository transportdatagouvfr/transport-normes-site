defmodule SiteDeNormes.Transforms.NavigationTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.Transforms.Navigation
  import LazyHTML, only: [from_fragment: 1, query: 2, text: 1]

  describe "heading ID generation" do
    test "generates slugified IDs from heading text" do
      html = run_plugin("# Hello World") |> to_html()

      assert html |> query("h1") |> text() == "Hello World"
    end

    test "handles accents in heading text" do
      html = run_plugin("# Arrêts des lignes") |> to_html()

      assert html |> query("h1") |> text() == "Arrêts des lignes"
    end

    test "handles inline formatting by stripping it" do
      html = run_plugin("# Section **bold** and *italic*") |> to_html()

      assert html |> query("#section-bold-and-italic") |> text() == "Section bold and italic"
    end

    test "handles links in heading text" do
      html = run_plugin("# Section [with link](https://example.com)") |> to_html()

      assert html |> query("#section-with-link") |> text() == "Section with link"
    end

    test "handles code in heading text" do
      html = run_plugin("# Use the `config` file") |> to_html()

      assert html |> query("#use-the-config-file") |> text() == "Use the config file"
    end

    test "generates IDs for setext headings" do
      markdown = """
      Title
      =====

      Subtitle
      --------
      """

      html = markdown |> run_plugin() |> to_html()

      assert html |> query("#title") |> text() == "Title"
      assert html |> query("#subtitle") |> text() == "Subtitle"
    end

    test "generates deterministic IDs (no randomness)" do
      html1 =
        run_plugin("# Test Heading")
        |> MDEx.to_html!()

      html2 =
        run_plugin("# Test Heading")
        |> MDEx.to_html!()

      assert html1 == html2
    end
  end

  describe "TOC tree extraction" do
    test "extracts flat TOC for single-level headings" do
      markdown = """
      # First
      # Second
      # Third
      """

      doc = run_plugin(markdown)
      toc_tree = MDEx.Document.get_private(doc, :toc_tree)

      assert length(toc_tree) == 3
      assert hd(toc_tree).id == "first"
      assert hd(toc_tree).text == "First"
      assert hd(toc_tree).children == []
    end

    test "preserves nesting hierarchy" do
      markdown = """
      # Section 1
      ## Subsection 1.1
      ## Subsection 1.2
      ### Deep subsection
      # Section 2
      """

      doc = run_plugin(markdown)
      toc_tree = MDEx.Document.get_private(doc, :toc_tree)

      assert length(toc_tree) == 2

      section_1 = Enum.find(toc_tree, &(&1.id == "section-1"))
      assert length(section_1.children) == 2
      assert hd(section_1.children).id == "subsection-11"

      # Deep subsection belongs under Subsection 1.2 (most recent H2),
      # following standard markdown heading semantics.
      subsection_1_2 = Enum.find(section_1.children, &(&1.id == "subsection-12"))
      assert length(subsection_1_2.children) == 1
      assert hd(subsection_1_2.children).id == "deep-subsection"
    end

    test "handles deeply nested headings" do
      markdown = """
      # Level 1
      ## Level 2
      ### Level 3
      #### Level 4
      """

      doc = run_plugin(markdown)
      toc_tree = MDEx.Document.get_private(doc, :toc_tree)

      level_1 = hd(toc_tree)
      assert level_1.id == "level-1"
      assert length(level_1.children) == 1

      level_2 = hd(level_1.children)
      assert level_2.id == "level-2"
      assert length(level_2.children) == 1

      level_3 = hd(level_2.children)
      assert level_3.id == "level-3"
      assert length(level_3.children) == 1

      level_4 = hd(level_3.children)
      assert level_4.id == "level-4"
      assert level_4.children == []
    end

    test "extracts plain text without formatting in TOC entries" do
      markdown = "# Section with **bold** and *italic*"

      doc = run_plugin(markdown)
      toc_tree = MDEx.Document.get_private(doc, :toc_tree)

      assert hd(toc_tree).text == "Section with bold and italic"
    end
  end

  describe "HTML rendering" do
    test "heading IDs appear in rendered HTML" do
      html = run_plugin("# Hello World\n## Sub heading") |> to_html()

      assert html |> query("#hello-world") |> text() == "Hello World"
      assert html |> query("#sub-heading") |> text() == "Sub heading"
    end

    test "accent-containing IDs appear in HTML" do
      doc = run_plugin("# Arrêts des lignes")

      html = MDEx.to_html!(doc)
      toc_tree = MDEx.Document.get_private(doc, :toc_tree)

      assert hd(toc_tree).id == "arrêts-des-lignes"
      assert String.contains?(html, ~s(id="arrêts-des-lignes"))
    end
  end

  describe "duplicate ID handling" do
    test "appends numeric suffix to duplicate IDs" do
      markdown = """
      # Contexte
      Some text
      ## Contexte
      More text
      """

      doc = run_plugin(markdown)
      toc_tree = MDEx.Document.get_private(doc, :toc_tree)

      ids = for h <- flatten_toc(toc_tree), do: h.id
      assert "contexte" in ids
      assert "contexte-1" in ids
    end

    test "handles multiple duplicates of same heading" do
      markdown = """
      # Contexte
      # Contexte
      # Contexte
      """

      doc = run_plugin(markdown)
      toc_tree = MDEx.Document.get_private(doc, :toc_tree)

      ids = for h <- flatten_toc(toc_tree), do: h.id
      assert "contexte" in ids
      assert "contexte-1" in ids
      assert "contexte-2" in ids
    end
  end

  describe "full pipeline integration" do
    test "works with MDEx.to_html!/2 and preserves assigns" do
      html =
        run_plugin("# Test Page\n## Section A\n## Section B")
        |> MDEx.to_html!()

      assert String.contains?(html, ~s(id="test-page"))
      assert String.contains?(html, ~s(id="section-a"))
      assert String.contains?(html, ~s(id="section-b"))
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────

  defp run_plugin(markdown) do
    MDEx.new(markdown: markdown)
    |> Navigation.attach()
    |> MDEx.Document.run()
  end

  defp to_html(doc) do
    doc
    |> MDEx.to_html!()
    |> from_fragment()
  end

  defp flatten_toc(toc_tree) do
    Enum.flat_map(toc_tree, fn entry ->
      [entry | flatten_toc(entry.children)]
    end)
  end
end
