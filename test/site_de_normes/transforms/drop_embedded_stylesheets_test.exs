defmodule SiteDeNormes.Transforms.DropEmbeddedStylesheetsTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.Transforms.DropEmbeddedStylesheets

  describe "attach/1" do
    test "removes a block-level <style> tag" do
      markdown = """
      # Title

      <style>.hl { background: yellow; }</style>

      Some text.
      """

      doc = MDEx.new(markdown: markdown, extension: [table: true]) |> MDEx.Document.run()
      result = DropEmbeddedStylesheets.attach(doc)
      html = MDEx.to_html!(result)

      refute String.contains?(html, "<style>")
      assert String.contains?(html, "<h1>Title</h1>")
      assert String.contains?(html, "Some text.")
    end

    test "removes a <style> block with multi-line CSS" do
      markdown = """
      # Page

      <style>
        .hl { background: yellow; }
        .mark-blue { background: cyan; }
        .red { color: red; }
      </style>

      Content here.
      """

      doc = MDEx.new(markdown: markdown, extension: [table: true]) |> MDEx.Document.run()
      result = DropEmbeddedStylesheets.attach(doc)
      html = MDEx.to_html!(result)

      refute String.contains?(html, "<style>")
      refute String.contains?(html, "background")
      assert String.contains?(html, "Content here.")
    end

    test "preserves surrounding content when style block is removed" do
      markdown = """
      # Heading 1

      Paragraph before.

      <style>.x{color:red}</style>

      Paragraph after.

      | A | B |
      |---|---|
      | 1 | 2 |
      """

      doc = MDEx.new(markdown: markdown, extension: [table: true]) |> MDEx.Document.run()
      result = DropEmbeddedStylesheets.attach(doc)
      html = MDEx.to_html!(result)

      refute String.contains?(html, "<style>")
      assert String.contains?(html, "<h1>Heading 1</h1>")
      assert String.contains?(html, "Paragraph before.")
      assert String.contains?(html, "Paragraph after.")
      assert String.contains?(html, "<table>")
    end

    test "removes inline <style> and </style> HtmlInline nodes" do
      markdown = "Text with <style>.x{}</style> inline."

      doc = MDEx.new(markdown: markdown, extension: [table: true]) |> MDEx.Document.run()
      result = DropEmbeddedStylesheets.attach(doc)
      html = MDEx.to_html!(result)

      refute String.contains?(html, "<style>")
      assert String.contains?(html, "Text with")
      assert String.contains?(html, "inline.")
    end

    test "handles multiple <style> blocks" do
      markdown = """
      # Title

      <style>.a { color: red; }</style>

      Middle.

      <style>.b { color: blue; }</style>

      End.
      """

      doc = MDEx.new(markdown: markdown, extension: [table: true]) |> MDEx.Document.run()
      result = DropEmbeddedStylesheets.attach(doc)
      html = MDEx.to_html!(result)

      refute String.contains?(html, "<style>")
      assert String.contains?(html, "<h1>Title</h1>")
      assert String.contains?(html, "Middle.")
      assert String.contains?(html, "End.")
    end

    test "no-op on document without style blocks" do
      markdown = """
      # Hello

      Just a normal paragraph.
      """

      doc = MDEx.new(markdown: markdown, extension: [table: true]) |> MDEx.Document.run()
      result = DropEmbeddedStylesheets.attach(doc)
      html = MDEx.to_html!(result)

      assert String.contains?(html, "<h1>Hello</h1>")
      assert String.contains?(html, "normal paragraph")
    end

    test "no-op on empty document" do
      doc = MDEx.new(markdown: "", extension: [table: true]) |> MDEx.Document.run()
      result = DropEmbeddedStylesheets.attach(doc)

      assert MDEx.to_html!(result) == ""
    end

    test "preserves other HTML elements (not style blocks)" do
      markdown = """
      <div class="content">Hello</div>

      <style>.hl{color:red}</style>

      <span class="hl">marked text</span>
      """

      doc = MDEx.new(markdown: markdown, extension: [table: true]) |> MDEx.Document.run()
      result = DropEmbeddedStylesheets.attach(doc)
      html = MDEx.to_html!(result, render: [unsafe: true])

      refute String.contains?(html, "<style>")
      assert String.contains?(html, "<div class=\"content\">")
      assert String.contains?(html, "<span class=\"hl\">marked text</span>")
    end

    test "preserves code blocks with style keywords" do
      markdown = """
      Here is some CSS:

      ```css
      .hl { background: yellow; }
      .mark-blue { background: cyan; }
      ```
      """

      doc = MDEx.new(markdown: markdown, extension: [table: true]) |> MDEx.Document.run()
      result = DropEmbeddedStylesheets.attach(doc)
      html = MDEx.to_html!(result)

      refute String.contains?(html, "<style>")
      assert String.contains?(html, ".hl { background: yellow; }")
    end

    test "works alongside other transforms in pipeline" do
      markdown = """
      # Title

      <style>.hl{color:red}</style>

      | Col |
      |---|
      | Val |
      """

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> SiteDeNormes.Transforms.Navigation.attach()
        |> MDEx.Document.run()
        |> DropEmbeddedStylesheets.attach()
        |> MDEx.to_html!(render: [unsafe: true])
        |> SiteDeNormes.Transforms.Dsfr.wrap_tables()

      refute String.contains?(html, "<style>")
      assert String.contains?(html, ~s(id="title"))
      assert String.contains?(html, "fr-table")
    end
  end
end
