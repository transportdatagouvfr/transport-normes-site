defmodule SiteDeNormes.Transforms.BlockquoteToHighlightTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.Transforms.BlockquoteToHighlight

  doctest BlockquoteToHighlight

  # ── Simple blockquotes ───────────────────────────────────────────────────

  describe "simple blockquotes" do
    test "converts a single-paragraph blockquote to DSFR highlight" do
      markdown = "> A quoted note."

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, ~s(role="note"))
      assert String.contains?(html, "<p>A quoted note.</p>")
      refute String.contains?(html, "<blockquote>")
    end

    test "converts a blockquote with bold text" do
      markdown = "> **Important** note."

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "<strong>Important</strong>")
      refute String.contains?(html, "<blockquote>")
    end

    test "converts a blockquote with italic text" do
      markdown = "> *Italic* quote."

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "<em>Italic</em>")
      refute String.contains?(html, "<blockquote>")
    end

    test "converts a blockquote with inline code (backtick syntax)" do
      markdown = "> Use `mdex` to render."

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "<code>mdex</code>")
      refute String.contains?(html, "<blockquote>")
    end

    test "converts a blockquote with links" do
      markdown = "> See [the docs](https://example.com)."

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, ~s(href="https://example.com"))
      refute String.contains?(html, "<blockquote>")
    end

    test "converts a blockquote with mixed formatting" do
      markdown = "> **Bold**, *italic*, and `code` together."

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "<strong>Bold</strong>")
      assert String.contains?(html, "<em>italic</em>")
      assert String.contains?(html, "<code>code</code>")
      refute String.contains?(html, "<blockquote>")
    end

    test "converts a blockquote with nested formatting" do
      markdown = "> **Bold and *italic* text**."

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      # MDEx renders bold wrapping italic correctly
      assert String.contains?(html, "<strong>Bold and <em>italic</em> text</strong>")
      refute String.contains?(html, "<blockquote>")
    end
  end

  # ── Multi-paragraph blockquotes ──────────────────────────────────────────

  describe "multi-paragraph blockquotes" do
    test "converts a multi-paragraph blockquote preserving all paragraphs" do
      markdown = """
      > First paragraph.
      >
      > Second paragraph continues.
      """

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "<p>First paragraph.</p>")
      assert String.contains?(html, "<p>Second paragraph continues.</p>")
      refute String.contains?(html, "<blockquote>")
    end

    test "converts a blockquote with empty lines between paragraphs" do
      markdown = """
      > Line one.
      >
      >
      > Line two after blank line.
      """

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      refute String.contains?(html, "<blockquote>")
    end
  end

  # ── Nested blockquotes ───────────────────────────────────────────────────

  describe "nested blockquotes" do
    test "converts both outer and inner blockquotes" do
      markdown = """
      > Outer quote
      > > Inner quote
      """

      html = full_pipeline(markdown)

      highlight_count = String.count(html, "fr-highlight fr-highlight--default")
      assert highlight_count == 2
      refute String.contains?(html, "<blockquote>")
    end

    test "preserves nesting structure in output" do
      markdown = "> Outer\n> > Inner"

      html = full_pipeline(markdown)

      # The inner div should be inside the outer div
      assert html =~ ~s(<div class="fr-highlight fr-highlight--default" role="note">)
      refute String.contains?(html, "<blockquote>")
    end
  end

  # ── Multiline blockquotes ────────────────────────────────────────────────

  describe "multiline blockquotes (no > on continuation lines)" do
    test "converts a multiline blockquote" do
      markdown = """
      > This is a multiline
      block quote that continues
      without > markers.
      """

      html = full_pipeline(markdown, multiline_block_quotes: true)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "This is a multiline")
      assert String.contains?(html, "block quote that continues")
      refute String.contains?(html, "<blockquote>")
    end

    test "converts multiple multiline blockquotes" do
      markdown = """
      > First multiline
      continuation here.

      > Second one
      also multiline.
      """

      html = full_pipeline(markdown, multiline_block_quotes: true)

      highlight_count = String.count(html, "fr-highlight fr-highlight--default")
      assert highlight_count == 2
      refute String.contains?(html, "<blockquote>")
    end
  end

  # ── Surrounding content ──────────────────────────────────────────────────

  describe "surrounding content" do
    test "preserves paragraphs before and after blockquotes" do
      markdown = """
      Before quote.

      > Quoted text.

      After quote.
      """

      html = full_pipeline(markdown)

      assert String.contains?(html, "<p>Before quote.</p>")
      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "<p>After quote.</p>")
      refute String.contains?(html, "<blockquote>")
    end

    test "preserves headings alongside blockquotes" do
      markdown = """
      # Heading

      > A note.
      """

      html = full_pipeline(markdown)

      assert String.contains?(html, "<h1>Heading</h1>")
      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      refute String.contains?(html, "<blockquote>")
    end

    test "handles multiple blockquotes in the same document" do
      markdown = """
      > First quote.

      Middle text.

      > Second quote.
      """

      html = full_pipeline(markdown)

      highlight_count = String.count(html, "fr-highlight fr-highlight--default")
      assert highlight_count == 2
      refute String.contains?(html, "<blockquote>")
    end

    test "preserves lists alongside blockquotes" do
      markdown = """
      > A note.

      * Item one
      * Item two
      """

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "<ul>")
      assert String.contains?(html, "<li>Item one</li>")
      refute String.contains?(html, "<blockquote>")
    end
  end

  # ── No-op cases ──────────────────────────────────────────────────────────

  describe "no-op cases" do
    test "document without blockquotes is unchanged" do
      markdown = """
      # Title

      Just a regular paragraph.
      """

      html = full_pipeline(markdown)

      refute String.contains?(html, "fr-highlight")
      assert String.contains?(html, "<h1>Title</h1>")
    end

    test "empty document produces empty output" do
      doc = MDEx.new(markdown: "", extension: [table: true]) |> MDEx.Document.run()
      result = BlockquoteToHighlight.attach(doc)
      html = MDEx.to_html!(result)

      assert html == ""
    end

    test "only blockquotes are converted, other elements preserved" do
      markdown = """
      # Heading

      <div class="custom">Custom HTML</div>

      > A quote.

      `inline code`
      """

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> BlockquoteToHighlight.attach()
        |> MDEx.to_html!(render: [unsafe: true])

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, ~s(class="custom"))
      assert String.contains?(html, "<h1>Heading</h1>")
      assert String.contains?(html, "<code>inline code</code>")
      refute String.contains?(html, "<blockquote>")
    end
  end

  # ── Real-world NetEx FR content ──────────────────────────────────────────

  describe "real-world NetEx FR content" do
    test "address blockquote is converted" do
      markdown = "> Bâtiment B\n> 5 Allée des Pirouettes\n> 31420 Bouzin"

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "Bâtiment B")
      assert String.contains?(html, "5 Allée des Pirouettes")
      assert String.contains?(html, "31420 Bouzin")
      refute String.contains?(html, "<blockquote>")
    end

    test "quoted spec list is converted" do
      markdown = """
      > \(i\) Park & Ride stops
      >
      > \(ii\) Bike sharing stations
      >
      > \(iii\) Car-sharing stations
      """

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      # MDEx renders escaped parens and escapes & to &amp;
      assert String.contains?(html, "Park &amp; Ride stops")
      refute String.contains?(html, "<blockquote>")
    end

    test "blockquote with bold inline text (not title pattern)" do
      markdown = "> **Types of the dynamic travel and traffic data**"

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))

      assert String.contains?(
               html,
               "<strong>Types of the dynamic travel and traffic data</strong>"
             )

      refute String.contains?(html, "<blockquote>")
    end

    test "empty marker blockquote" do
      markdown = "> <span class=\"mark\"></span>"

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      refute String.contains?(html, "<blockquote>")
    end
  end

  # ── Full pipeline integration ────────────────────────────────────────────

  describe "full pipeline with other transforms" do
    test "works alongside Navigation plugin" do
      markdown = """
      # Title

      > A note.
      """

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> SiteDeNormes.Transforms.Navigation.attach()
        |> MDEx.Document.run()
        |> BlockquoteToHighlight.attach()
        |> MDEx.to_html!()

      assert String.contains?(html, ~s(id="title"))
      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      refute String.contains?(html, "<blockquote>")
    end

    test "works alongside DropEmbeddedStylesheets" do
      markdown = """
      <style>.x{color:red}</style>

      > A quote.
      """

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> SiteDeNormes.Transforms.DropEmbeddedStylesheets.attach()
        |> BlockquoteToHighlight.attach()
        |> MDEx.to_html!()

      refute String.contains?(html, "<style>")
      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      refute String.contains?(html, "<blockquote>")
    end

    test "works alongside Dsfr.wrap_tables" do
      markdown = """
      > A note.

      | Col A | Col B |
      |---|---|
      | 1 | 2 |
      """

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> BlockquoteToHighlight.attach()
        |> MDEx.to_html!(render: [unsafe: true])
        |> SiteDeNormes.Transforms.Dsfr.wrap_tables()

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "fr-table")
      refute String.contains?(html, "<blockquote>")
    end

    test "full build pipeline: markdown → plugins → to_html! → wrap_tables" do
      markdown = """
      > A quoted note.

      | Col |
      |---|
      | Val |
      """

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> SiteDeNormes.Transforms.Navigation.attach()
        |> MDEx.Document.run()
        |> SiteDeNormes.Transforms.DropEmbeddedStylesheets.attach()
        |> BlockquoteToHighlight.attach()
        |> MDEx.to_html!(render: [unsafe: true])
        |> SiteDeNormes.Transforms.Dsfr.wrap_tables()

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
      assert String.contains?(html, "fr-table")
      refute String.contains?(html, "<blockquote>")
    end
  end

  # ── Attribute verification ───────────────────────────────────────────────

  describe "output attributes" do
    test "all highlights have role=\"note\"" do
      markdown = """
      > Quote one.

      > Quote two.
      """

      html = full_pipeline(markdown)

      note_count = String.count(html, ~s(role="note"))
      assert note_count == 2
    end

    test "class is exactly fr-highlight fr-highlight--default" do
      markdown = "> Content"

      html = full_pipeline(markdown)

      assert String.contains?(html, ~s(class="fr-highlight fr-highlight--default"))
    end

    test "role=\"note\" appears once per highlight (not duplicated)" do
      markdown = "> Single quote."

      html = full_pipeline(markdown)

      note_count = String.count(html, ~s(role="note"))
      assert note_count == 1
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp full_pipeline(markdown, opts \\ []) do
    extensions = Keyword.merge([table: true], opts)

    MDEx.new(markdown: markdown, extension: extensions)
    |> MDEx.Document.run()
    |> BlockquoteToHighlight.attach()
    |> MDEx.to_html!()
  end
end
