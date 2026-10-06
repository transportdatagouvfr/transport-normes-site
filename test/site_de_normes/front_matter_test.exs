defmodule SiteDeNormes.FrontMatterTest do
  use ExUnit.Case, async: true

  import LazyHTML, only: [from_fragment: 1, query: 2, text: 1]

  test "shows the front matter as code" do
    html =
      MDEx.new(markdown: "---\ntitle: <b>Arrêts</b>\n---\n# Heading")
      |> SiteDeNormes.FrontMatter.attach()
      |> MDEx.to_html!()
      |> from_fragment()

    assert html |> query("code") |> text() == "title: <b>Arrêts</b>"
  end
end
