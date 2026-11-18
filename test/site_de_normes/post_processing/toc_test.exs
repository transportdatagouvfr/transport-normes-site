defmodule SiteDeNormes.PostProcessing.ToCTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.PostProcessing.ToC
  alias SiteDeNormes.Transforms.Navigation

  doctest ToC

  defp html(markdown) do
    MDEx.new(markdown: markdown)
    |> Navigation.attach()
    |> MDEx.Document.run()
    |> MDEx.to_html!(render: [unsafe: true])
  end

  defp entry(id, text, children \\ [], hide_numbering \\ false) do
    %{id: id, text: text, children: children, hide_numbering: hide_numbering}
  end

  defp result(tree, annexes \\ []) do
    {tree, annexes}
  end

  describe "extract/1 — basic behavior" do
    test "returns empty lists for empty document" do
      assert ToC.extract(html("")) == result([])
    end

    test "extracts h1 headings as top-level entries" do
      assert ToC.extract(html("# Hello World\n## Sub")) ==
               result([entry("hello-world", "Hello World", [entry("sub", "Sub")])])
    end

    test "extracts h2 headings as children of the most recent h1" do
      assert ToC.extract(html("# Section 1\n## Sub 1.1\n## Sub 1.2")) ==
               result([
                 entry("section-1", "Section 1", [
                   entry("sub-11", "Sub 1.1"),
                   entry("sub-12", "Sub 1.2")
                 ])
               ])
    end

    test "handles multiple h1 headings at the same level" do
      assert ToC.extract(html("# First\n## Sub A\n# Second\n## Sub B")) ==
               result([
                 entry("first", "First", [entry("sub-a", "Sub A")]),
                 entry("second", "Second", [entry("sub-b", "Sub B")])
               ])
    end

    test "ignores h3 and deeper headings" do
      assert ToC.extract(html("# H1\n## H2\n### H3\n#### H4")) ==
               result([entry("h1", "H1", [entry("h2", "H2")])])
    end

    test "ignores orphaned h2 headings (no preceding h1)" do
      assert ToC.extract(html("## Orphan\n# Real H1\n## Child")) ==
               result([entry("real-h1", "Real H1", [entry("child", "Child")])])
    end

    test "handles headings with inline formatting by stripping it" do
      assert ToC.extract(html("# Section **bold** and *italic*")) ==
               result([entry("section-bold-and-italic", "Section bold and italic")])
    end

    test "returns empty lists when no headings are present" do
      assert ToC.extract(html("Just some text without any headings.")) == result([])
    end
  end

  describe "extract/1 — annex detection" do
    test "splits headings inside div.annexes into the annexes list" do
      markdown = """
      # Main Section

      Some content before the annex.

      <div class="annexes">

      # Annex A

      ## Subsection A.1

      </div>
      """

      assert ToC.extract(html(markdown)) ==
               result(
                 [entry("main-section", "Main Section")],
                 [
                   entry(
                     "annex-a",
                     "Annex A",
                     [entry("subsection-a1", "Subsection A.1")]
                   )
                 ]
               )
    end

    test "tags only headings inside annexes, not those before or after" do
      markdown = """
      # Introduction

      <div class="annexes">

      # Annex B

      </div>

      # Conclusion
      """

      assert ToC.extract(html(markdown)) ==
               result(
                 [entry("introduction", "Introduction"), entry("conclusion", "Conclusion")],
                 [entry("annex-b", "Annex B")]
               )
    end

    test "handles multiple separate annex sections" do
      markdown = """
      # Chapter One

      <div class="annexes">

      # Annex A

      </div>

      # Chapter Two

      <div class="annexes">

      # Annex B

      </div>
      """

      assert ToC.extract(html(markdown)) ==
               result(
                 [entry("chapter-one", "Chapter One"), entry("chapter-two", "Chapter Two")],
                 [entry("annex-a", "Annex A"), entry("annex-b", "Annex B")]
               )
    end

    test "handles nested divs inside annexes without double-counting depth" do
      markdown = """
      <div class="annexes">

      # Annex A

      <div>
      ## Nested section (not rendered as h2 by MDEx)
      </div>

      ## Real Subsection

      </div>
      """

      assert ToC.extract(html(markdown)) ==
               result([], [
                 entry(
                   "annex-a",
                   "Annex A",
                   [entry("real-subsection", "Real Subsection")]
                 )
               ])
    end

    test "works with class containing annexes as part of a longer class string" do
      markdown = """
      <div class="wrapper annexes other-class">

      # Annex Content

      </div>
      """

      assert ToC.extract(html(markdown)) == result([], [entry("annex-content", "Annex Content")])
    end
  end

  describe "extract/1 — Bibliographie detection" do
    test "tags h1 with text 'Bibliographie' as hide_numbering: true" do
      markdown = """
      # Main Section

      # Bibliographie

      <div class="annexes">

      # Annex A

      </div>
      """

      assert ToC.extract(html(markdown)) ==
               result(
                 [
                   entry("main-section", "Main Section"),
                   entry("bibliographie", "Bibliographie", [], true)
                 ],
                 [entry("annex-a", "Annex A")]
               )
    end

    test "detects Bibliographie regardless of position in document" do
      markdown = """
      # Bibliographie

      # Main Section
      """

      assert ToC.extract(html(markdown)) ==
               result(
                 [
                   entry("bibliographie", "Bibliographie", [], true),
                   entry("main-section", "Main Section")
                 ],
                 []
               )
    end

    test "detects Bibliographie inside annexes too" do
      markdown = """
      <div class="annexes">

      # Annex A

      # Bibliographie

      </div>
      """

      assert ToC.extract(html(markdown)) ==
               result([], [
                 entry("annex-a", "Annex A"),
                 entry("bibliographie", "Bibliographie", [], true)
               ])
    end

    test "does not match similar but different text" do
      markdown = """
      # Bibliographic References
      # Bibliography
      # List of References
      """

      assert ToC.extract(html(markdown)) ==
               result([
                 entry("bibliographic-references", "Bibliographic References"),
                 entry("bibliography", "Bibliography"),
                 entry("list-of-references", "List of References")
               ])
    end
  end

  describe "extract/1 — combined annex and Bibliographie" do
    test "real-world parkings pattern: Bibliographie before annexes" do
      markdown = """
      # Introduction

      # Bibliographie

      <div class="annexes">

      # Annex A - Rappel sur les objets

      ## Introduction

      ## Profil Arrêt

      </div>
      """

      assert ToC.extract(html(markdown)) ==
               result(
                 [
                   entry("introduction", "Introduction"),
                   entry("bibliographie", "Bibliographie", [], true)
                 ],
                 [
                   entry(
                     "annex-a---rappel-sur-les-objets",
                     "Annex A - Rappel sur les objets",
                     [
                       entry("introduction-1", "Introduction"),
                       entry("profil-arrêt", "Profil Arrêt")
                     ]
                   )
                 ]
               )
    end

    test "real-world tarifs pattern: annexes before Bibliographie" do
      markdown = """
      # Main Content

      <div class="annexes">

      # Annex A - Usage Parameters

      ## RoundTrip – Element

      </div>

      # Bibliographie
      """

      assert ToC.extract(html(markdown)) ==
               result(
                 [
                   entry("main-content", "Main Content"),
                   entry("bibliographie", "Bibliographie", [], true)
                 ],
                 [
                   entry(
                     "annex-a---usage-parameters",
                     "Annex A - Usage Parameters",
                     [entry("roundtrip--element", "RoundTrip – Element")]
                   )
                 ]
               )
    end
  end

  describe "extract/1 — nested children inside annexes" do
    test "h2s inside annexes are correctly nested under their h1 parent" do
      markdown = """
      # Regular Section

      ## Regular Sub

      <div class="annexes">

      # Annex Title

      ## Annex Sub 1

      ### Deeper (ignored)

      ## Annex Sub 2

      </div>
      """

      assert ToC.extract(html(markdown)) ==
               result(
                 [
                   entry("regular-section", "Regular Section", [
                     entry("regular-sub", "Regular Sub")
                   ])
                 ],
                 [
                   entry(
                     "annex-title",
                     "Annex Title",
                     [
                       entry("annex-sub-1", "Annex Sub 1"),
                       entry("annex-sub-2", "Annex Sub 2")
                     ]
                   )
                 ]
               )
    end

    test "orphaned h2s inside annexes (no preceding h1 in annex) are dropped" do
      markdown = """
      <div class="annexes">

      ## Orphaned Annex Sub

      # Real Annex Title

      </div>
      """

      assert ToC.extract(html(markdown)) ==
               result([], [
                 entry("real-annex-title", "Real Annex Title")
               ])
    end
  end
end
