defmodule SiteDeNormes.PostProcessing.ToCTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.PostProcessing.ToC
  alias SiteDeNormes.Transforms.Navigation

  defp html(markdown) do
    MDEx.new(markdown: markdown)
    |> Navigation.attach()
    |> MDEx.Document.run()
    |> MDEx.to_html!()
  end

  describe "extract/1" do
    test "returns empty list for empty document" do
      assert ToC.extract(html("")) == []
    end

    test "extracts h1 headings as top-level entries" do
      toc = ToC.extract(html("# Hello World\n## Sub"))

      assert [entry] = toc
      assert_toc_entry(entry)
      assert entry.id == "hello-world"
      assert entry.text == "Hello World"
    end

    test "extracts h2 headings as children of the most recent h1" do
      toc = ToC.extract(html("# Section 1\n## Sub 1.1\n## Sub 1.2"))

      assert [section_1] = toc
      assert_toc_entry(section_1)
      assert section_1.id == "section-1"
      assert length(section_1.children) == 2
      Enum.each(section_1.children, &assert_toc_entry/1)
      assert hd(section_1.children).id == "sub-11"
      assert Enum.at(section_1.children, 1).id == "sub-12"
    end

    test "handles multiple h1 headings at the same level" do
      toc = ToC.extract(html("# First\n## Sub A\n# Second\n## Sub B"))

      assert [first, second] = toc
      assert_toc_entry(first)
      assert first.id == "first"
      assert length(first.children) == 1
      Enum.each(first.children, &assert_toc_entry/1)
      assert hd(first.children).id == "sub-a"

      assert_toc_entry(second)
      assert second.id == "second"
      assert length(second.children) == 1
      Enum.each(second.children, &assert_toc_entry/1)
      assert hd(second.children).id == "sub-b"
    end

    test "ignores h3 and deeper headings" do
      toc = ToC.extract(html("# H1\n## H2\n### H3\n#### H4"))

      assert [entry] = toc
      assert_toc_entry(entry)
      assert length(entry.children) == 1
      Enum.each(entry.children, &assert_toc_entry/1)
      # H3 should NOT appear as a child of H2
      refute Enum.any?(toc, fn h ->
               Enum.any?(h.children, &(&1.id == "h3"))
             end)
    end

    test "ignores orphaned h2 headings (no preceding h1)" do
      toc = ToC.extract(html("## Orphan\n# Real H1\n## Child"))

      assert [entry] = toc
      assert_toc_entry(entry)
      assert entry.id == "real-h1"
      # The orphaned h2 should not appear
      refute Enum.any?(toc, &(&1.id == "orphan"))
    end

    test "handles headings with inline formatting by stripping it" do
      toc = ToC.extract(html("# Section **bold** and *italic*"))

      assert [entry] = toc
      assert_toc_entry(entry)
      assert entry.text == "Section bold and italic"
    end

    test "handles headings with links by stripping link markup" do
      toc = ToC.extract(html("# Section [with link](https://example.com)"))

      assert [entry] = toc
      assert_toc_entry(entry)
      assert entry.text == "Section with link"
    end

    test "handles headings with code by stripping backticks" do
      toc = ToC.extract(html("# Use the `config` file"))

      assert [entry] = toc
      assert_toc_entry(entry)
      assert entry.text == "Use the config file"
    end

    test "handles accent-containing headings" do
      toc = ToC.extract(html("# Arrêts des lignes\n## Sous-section"))

      assert [entry] = toc
      assert_toc_entry(entry)
      assert entry.id == "arrêts-des-lignes"
      assert entry.text == "Arrêts des lignes"
    end

    test "handles duplicate IDs with numeric suffixes" do
      toc = ToC.extract(html("# Contexte\n## Contexte\n# Another"))

      ids = for h <- flatten_toc(toc), do: h.id
      assert "contexte" in ids
      assert "contexte-1" in ids
    end

    test "returns empty list when no headings are present" do
      assert ToC.extract(html("Just some text without any headings.")) == []
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────

  defp assert_toc_entry(%{id: _, text: _, children: _} = entry)
       when is_list(entry.children),
       do: entry

  defp assert_toc_entry(entry) do
    flunk("expected entry with :id, :text, :children keys, got: #{inspect(entry)}")
  end

  defp flatten_toc(toc_tree) do
    Enum.flat_map(toc_tree, fn entry ->
      assert_toc_entry(entry)
      [entry | flatten_toc(entry.children)]
    end)
  end
end
