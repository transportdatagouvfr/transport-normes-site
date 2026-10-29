defmodule SiteDeNormes.FrontMatterTest do
  use ExUnit.Case, async: true

  import LazyHTML, only: [from_fragment: 1, query: 2, text: 1]

  test "renders front matter as debug callout in HTML" do
    html =
      MDEx.new(markdown: "---\ntitle: <b>Arrêts</b>\n---\n# Heading")
      |> SiteDeNormes.FrontMatter.attach()
      |> MDEx.to_html!()
      |> from_fragment()

    assert html |> query("code") |> text() == "title: <b>Arrêts</b>"
    assert html |> query(".fr-callout") != nil
  end

  test "parses YAML front matter into document private fields" do
    doc =
      MDEx.new(markdown: "---\ntitle: Arrêts\nautonumbering: true\n---\n# Heading")
      |> SiteDeNormes.FrontMatter.attach()
      |> MDEx.Document.run()

    assert MDEx.Document.get_private(doc, :front_matter, %{}) == %{
             "title" => "Arrêts",
             "autonumbering" => true
           }
  end

  test "returns empty map when no front matter is present" do
    doc =
      MDEx.new(markdown: "# Just a heading")
      |> SiteDeNormes.FrontMatter.attach()
      |> MDEx.Document.run()

    assert MDEx.Document.get_private(doc, :front_matter, %{}) == %{}
  end

  test "handles nested front matter" do
    doc =
      MDEx.new(
        markdown: "---\ntags:\n  - netex\n  - arrets\nmetadata:\n  version: '2.4'\n---\n# Content"
      )
      |> SiteDeNormes.FrontMatter.attach()
      |> MDEx.Document.run()

    assert MDEx.Document.get_private(doc, :front_matter, %{}) == %{
             "tags" => ["netex", "arrets"],
             "metadata" => %{"version" => "2.4"}
           }
  end

  test "debug callout is not rendered when no front matter" do
    html =
      MDEx.new(markdown: "# Just a heading")
      |> SiteDeNormes.FrontMatter.attach()
      |> MDEx.to_html!()

    refute html =~ "fr-callout"
  end
end
