defmodule SiteDeNormes.FrontMatterTest do
  use ExUnit.Case, async: true

  import LazyHTML, only: [from_fragment: 1, query: 2, text: 1]

  defp to_html(markdown) do
    MDEx.new(markdown: markdown) |> SiteDeNormes.FrontMatter.attach() |> MDEx.to_html!()
  end

  test "shows the front matter as YAML code in a callout" do
    html = to_html("---\ntitle: <b>Arrêts</b>\n---\n# Heading") |> from_fragment()

    assert html |> query(".fr-callout code.language-yaml") |> text() == "title: <b>Arrêts</b>"
    assert html |> query("h1") |> text() == "Heading"
  end

  test "leaves pages without front matter as is" do
    assert to_html("# Heading") == "<h1>Heading</h1>"
  end
end
