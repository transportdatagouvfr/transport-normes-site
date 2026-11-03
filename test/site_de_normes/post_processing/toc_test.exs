defmodule SiteDeNormes.PostProcessing.ToCTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.PostProcessing.ToC
  alias SiteDeNormes.Transforms.Navigation

  doctest ToC

  defp html(markdown) do
    MDEx.new(markdown: markdown)
    |> Navigation.attach()
    |> MDEx.Document.run()
    |> MDEx.to_html!()
  end

  defp entry(id, text, children \\ []), do: %{id: id, text: text, children: children}

  describe "extract/1" do
    test "returns empty list for empty document" do
      assert ToC.extract(html("")) == []
    end

    test "extracts h1 headings as top-level entries" do
      assert ToC.extract(html("# Hello World\n## Sub")) == [
               entry("hello-world", "Hello World", [entry("sub", "Sub")])
             ]
    end

    test "extracts h2 headings as children of the most recent h1" do
      assert ToC.extract(html("# Section 1\n## Sub 1.1\n## Sub 1.2")) == [
               entry("section-1", "Section 1", [
                 entry("sub-11", "Sub 1.1"),
                 entry("sub-12", "Sub 1.2")
               ])
             ]
    end

    test "handles multiple h1 headings at the same level" do
      assert ToC.extract(html("# First\n## Sub A\n# Second\n## Sub B")) == [
               entry("first", "First", [entry("sub-a", "Sub A")]),
               entry("second", "Second", [entry("sub-b", "Sub B")])
             ]
    end

    test "ignores h3 and deeper headings" do
      assert ToC.extract(html("# H1\n## H2\n### H3\n#### H4")) == [
               entry("h1", "H1", [entry("h2", "H2")])
             ]
    end

    test "ignores orphaned h2 headings (no preceding h1)" do
      assert ToC.extract(html("## Orphan\n# Real H1\n## Child")) == [
               entry("real-h1", "Real H1", [entry("child", "Child")])
             ]
    end

    test "handles headings with inline formatting by stripping it" do
      assert ToC.extract(html("# Section **bold** and *italic*")) == [
               entry("section-bold-and-italic", "Section bold and italic")
             ]
    end

    test "handles headings with links by stripping link markup" do
      assert ToC.extract(html("# Section [with link](https://example.com)")) == [
               entry("section-with-link", "Section with link")
             ]
    end

    test "handles headings with code by stripping backticks" do
      assert ToC.extract(html("# Use the `config` file")) == [
               entry("use-the-config-file", "Use the config file")
             ]
    end

    test "handles accent-containing headings" do
      assert ToC.extract(html("# Arrêts des lignes\n## Sous-section")) == [
               entry("arrêts-des-lignes", "Arrêts des lignes", [
                 entry("sous-section", "Sous-section")
               ])
             ]
    end

    test "handles duplicate IDs with numeric suffixes" do
      assert ToC.extract(html("# Contexte\n## Contexte\n# Another")) == [
               entry("contexte", "Contexte", [entry("contexte-1", "Contexte")]),
               entry("another", "Another")
             ]
    end

    test "returns empty list when no headings are present" do
      assert ToC.extract(html("Just some text without any headings.")) == []
    end
  end
end
