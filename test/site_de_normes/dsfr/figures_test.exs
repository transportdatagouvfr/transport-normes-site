defmodule SiteDeNormes.Dsfr.FiguresTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.Dsfr.Figures
  import LazyHTML, only: [from_fragment: 1, query: 2]
  import DsfrTestHelpers

  doctest Figures

  # ── Basic wrapping ───────────────────────────────────────────────────────

  describe "basic figure wrapping" do
    test "wraps img + em in a DSFR figure" do
      html =
        "<p><img src=\"media/image1.png\" alt=\"my image\"/><em>Caption</em></p>"
        |> wrap_figures()
        |> from_fragment()

      assert is_present?(query(html, ".fr-figure"))
    end

    test "produces correct DSFR class names" do
      html =
        wrap_figures("<p><img src=\"foo.png\" alt=\"x\"/><em>Caption</em></p>")

      assert String.contains?(html, ~s(class="fr-figure fr-figure--image fr-figure--lg"))
    end

    test "moves em content into figcaption" do
      html =
        "<p><img src=\"foo.png\" alt=\"x\"/><em>Caption text</em></p>"
        |> wrap_figures()
        |> from_fragment()

      assert texts_of(html, ".fr-caption") == ["Caption text"]
    end

    test "removes the em wrapper" do
      html = wrap_figures("<p><img src=\"foo.png\" alt=\"x\"/><em>Caption</em></p>")

      refute String.contains?(html, ~s(<em>Caption</em>))
    end

    test "preserves all img attributes" do
      html =
        "<p><img src=\"media/image1.png\" alt=\"my image\" width=\"400\" height=\"300\"/><em>Caption</em></p>"
        |> wrap_figures()

      assert String.contains?(html, ~s(src="media/image1.png"))
      assert String.contains?(html, ~s(alt="my image"))
      assert String.contains?(html, ~s(width="400"))
      assert String.contains?(html, ~s(height="300"))
    end

    test "img is first child of figure, figcaption second" do
      html =
        "<p><img src=\"foo.png\" alt=\"x\"/><em>Caption</em></p>"
        |> wrap_figures()
        |> from_fragment()

      children = query(html, ".fr-figure img, .fr-figure figcaption") |> LazyHTML.to_tree()
      assert length(children) == 2
    end
  end

  # ── Bare images (no caption) ─────────────────────────────────────────────

  describe "bare images without captions" do
    test "leaves img without following em unchanged" do
      html = wrap_figures("<p><img src=\"foo.png\" alt=\"x\"/></p>")

      assert String.contains?(html, ~s(<img src="foo.png" alt="x"/>))
      refute String.contains?(html, "fr-figure")
    end

    test "leaves img without following em unchanged in original p" do
      html = wrap_figures("<p><img src=\"foo.png\" alt=\"x\"/></p>")

      assert String.contains?(html, ~s(<p>))
    end
  end

  # ── Multiple images in one paragraph ─────────────────────────────────────

  describe "multiple img+em pairs" do
    test "handles the first img+em pair, subsequent text is preserved as plain text" do
      html =
        wrap_figures(
          "<p><img src=\"a.png\" alt=\"A\"/><em>Caption A</em> text <img src=\"b.png\" alt=\"B\"/><em>Caption B</em></p>"
        )

      # First pair is converted to a figure
      assert String.contains?(html, "fr-figure")
      assert String.contains?(html, "Caption A")
      # Post-text (including subsequent img+em as plain text) is preserved in a <p>
      assert String.contains?(html, ~s(<p>))
    end
  end

  # ── Pre/post siblings ────────────────────────────────────────────────────

  describe "content before/after img+em pair" do
    test "preserves content before the image in a <p>" do
      html =
        wrap_figures("<p>Some intro <img src=\"foo.png\" alt=\"x\"/><em>Caption</em></p>")

      assert String.contains?(html, ~s(<p>Some intro</p>))
    end

    test "preserves content after the caption in a new <p>" do
      html =
        wrap_figures("<p><img src=\"foo.png\" alt=\"x\"/><em>Caption</em> After text</p>")

      assert String.contains?(html, ~s(<p>After text</p>))
    end

    test "preserves content both before and after" do
      html =
        wrap_figures("<p>Before <img src=\"foo.png\" alt=\"x\"/><em>Caption</em> After</p>")

      assert String.contains?(html, ~s(<p>Before</p>))
      assert String.contains?(html, ~s(<p>After</p>))
    end
  end

  # ── Real markdown pipeline ───────────────────────────────────────────────

  describe "full pipeline: markdown → MDEx → to_html! → wrap_figures" do
    test "GFM image with italic caption becomes a figure" do
      # Note: no blank line between image and caption — they end up in same <p>
      markdown = "![image](media/image1.png)\n*Structuration des arrêts*"

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> wrap_figures()
        |> from_fragment()

      assert is_present?(query(html, ".fr-figure"))
      assert texts_of(html, ".fr-caption") == ["Structuration des arrêts"]
    end

    test "image without caption stays as plain img" do
      markdown = "![image](media/image1.png)"

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> wrap_figures()

      assert String.contains?(html, ~s(<img src="media/image1.png"))
      refute String.contains?(html, "fr-figure")
    end

    test "multiple images with captions each become figures" do
      markdown =
        "![image](media/image1.png)\n*First caption*\n\n![image](media/image2.png)\n*Second caption*"

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> wrap_figures()
        |> from_fragment()

      assert length(query(html, ".fr-figure") |> LazyHTML.to_tree()) == 2
    end

    test "paragraph with text then image+caption splits correctly" do
      markdown = "Text before\n\n![image](media/image1.png)\n*Caption*"

      html =
        MDEx.new(markdown: markdown, extension: [table: true])
        |> MDEx.Document.run()
        |> MDEx.to_html!(render: [unsafe: true])
        |> wrap_figures()
        |> from_fragment()

      assert is_present?(query(html, ".fr-figure"))
    end
  end

  # ── Edge cases ───────────────────────────────────────────────────────────

  describe "edge cases" do
    test "empty input produces unchanged output" do
      html = wrap_figures("")
      assert html == ""
    end

    test "paragraph with only em (no img) passes through" do
      html = wrap_figures("<p><em>Caption</em></p>")

      refute String.contains?(html, "fr-figure")
      assert String.contains?(html, ~s(<em>Caption</em>))
    end

    test "paragraph with em then img (wrong order) passes through" do
      html = wrap_figures("<p><em>Caption</em><img src=\"foo.png\" alt=\"x\"/></p>")

      refute String.contains?(html, "fr-figure")
    end

    test "figure is not nested inside another figure" do
      html =
        "<p><img src=\"foo.png\" alt=\"x\"/><em>Caption</em></p>"
        |> wrap_figures()
        |> from_fragment()

      # No figure should contain another figure
      refute is_present?(query(html, ".fr-figure .fr-figure"))
    end

    test "preserves non-breaking spaces in caption" do
      html =
        wrap_figures("<p><img src=\"foo.png\" alt=\"x\"/><em>\u00A0Caption\u00A0</em></p>")

      assert String.contains?(html, "\u00A0")
    end
  end

  @spec wrap_figures(String.t()) :: String.t()
  def wrap_figures("") do
    ""
  end

  def wrap_figures(html) when is_binary(html) do
    html
    |> SiteDeNormes.Dsfr.Transforms.apply_transform(&Figures.transform_tree/1)
    |> SiteDeNormes.Transforms.Html5ever.strip_wrapper()
  end
end
