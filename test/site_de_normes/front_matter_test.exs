defmodule SiteDeNormes.FrontMatterTest do
  use ExUnit.Case, async: true

  import LazyHTML, only: [from_fragment: 1, query: 2, text: 1]

  doctest SiteDeNormes.FrontMatter

  defp document(markdown) do
    MDEx.new(markdown: markdown)
    |> SiteDeNormes.FrontMatter.attach()
    |> MDEx.Document.run()
  end

  defp html(markdown) do
    markdown
    |> document()
    |> MDEx.to_html!()
  end

  test "renders front matter as debug callout in HTML" do
    html =
      html("---\ntitle: <b>Arrêts</b>\n---\n# Heading")
      |> from_fragment()

    assert html |> query("code") |> text() == "title: <b>Arrêts</b>"
    assert html |> query(".fr-callout") != nil
  end

  test "parses YAML front matter into document private fields" do
    doc = document("---\ntitle: Arrêts\nautonumbering: true\n---\n# Heading")

    assert MDEx.Document.get_private(doc, :front_matter, %{}) == %{
             "title" => "Arrêts",
             "autonumbering" => true
           }
  end

  test "returns empty map when no front matter is present" do
    doc = document("# Just a heading")

    assert MDEx.Document.get_private(doc, :front_matter, %{}) == %{}
  end

  test "handles nested front matter" do
    doc =
      document("---\ntags:\n  - netex\n  - arrets\nmetadata:\n  version: '2.4'\n---\n# Content")

    assert MDEx.Document.get_private(doc, :front_matter, %{}) == %{
             "tags" => ["netex", "arrets"],
             "metadata" => %{"version" => "2.4"}
           }
  end

  test "debug callout is not rendered when no front matter" do
    html = html("# Just a heading")

    refute html =~ "fr-callout"
  end
end
