defmodule SiteDeNormes.Transforms.Html5everTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.Transforms.Html5ever

  describe "strip_wrapper/1" do
    test "empty string returns empty string" do
      assert Html5ever.strip_wrapper("") == ""
    end

    test "strips standard html5ever wrapper" do
      input = "<html><head></head><body><p>Hello</p></body></html>"
      assert Html5ever.strip_wrapper(input) == "<p>Hello</p>"
    end

    test "strips wrapper with multiple children in body" do
      input =
        "<html><head></head><body><p>First</p>\n<p>Second</p></body></html>"

      assert Html5ever.strip_wrapper(input) == "<p>First</p>\n<p>Second</p>"
    end

    test "strips wrapper with nested elements" do
      input =
        "<html><head></head><body><div class=\"fr-figure\"><img src=\"x.png\"/><figcaption>Caption</figcaption></div></body></html>"

      assert Html5ever.strip_wrapper(input) ==
               ~s(<div class="fr-figure"><img src="x.png"/><figcaption>Caption</figcaption></div>)
    end

    test "strips wrapper with html tag attributes" do
      input = "<html lang=\"fr\"><head></head><body><p>Hello</p></body></html>"
      assert Html5ever.strip_wrapper(input) == "<p>Hello</p>"
    end

    test "passes through clean fragment without wrapper" do
      input = "<p>Hello</p>"
      assert Html5ever.strip_wrapper(input) == "<p>Hello</p>"
    end

    test "passes through single element without wrapper" do
      input = ~s(<div class="foo">bar</div>)
      assert Html5ever.strip_wrapper(input) == ~s(<div class="foo">bar</div>)
    end

    test "preserves special characters and unicode" do
      input = "<html><head></head><body><p>Élément avec &amp; NBSP\u00A0</p></body></html>"
      assert Html5ever.strip_wrapper(input) == ~s(<p>Élément avec &amp; NBSP\u00A0</p>)
    end

    test "strips wrapper with empty body" do
      # Floki adds an empty <body> when parsing, so this returns ""
      input = "<html><head></head></html>"
      assert Html5ever.strip_wrapper(input) == ""
    end
  end
end
