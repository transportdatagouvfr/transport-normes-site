defmodule SiteDeNormes.Lint.HtmlInlineTagsTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.Lint.HtmlInlineTags

  defp lint(markdown) do
    doc =
      MDEx.new(markdown: markdown, extension: [table: true])
      |> MDEx.Document.run()

    HtmlInlineTags.run({"test.md", doc})
  end

  describe "run/1 — detects <span class=\"hl\"> tags" do
    test "flags a simple span.hl tag" do
      issues = lint("<span class=\"hl\">highlighted</span>")

      assert length(issues) == 1
      issue = hd(issues)
      assert issue.code == "HTML-INLINE"
      assert issue.line == 1
      assert issue.column == 1
      assert issue.message =~ "<span"
      assert issue.suggestion =~ "==text=="
    end

    test "flags span.hl used inline with text" do
      issues = lint("Some text <span class=\"hl\">highlighted</span> more text")

      assert length(issues) == 1
      assert hd(issues).line == 1
    end

    test "flags multiple span.hl tags in the same document" do
      markdown = """
      First <span class="hl">one</span>.

      Second <span class="hl">two</span>.
      """

      issues = lint(markdown)
      assert length(issues) == 2
    end

    test "reports correct line numbers for multi-line documents" do
      markdown = """
      Line 1 no issue.

      Line 3 <span class="hl">bad</span>.

      Line 5 also clean.
      """

      issues = lint(markdown)
      assert length(issues) == 1
      assert hd(issues).line == 3
    end
  end

  describe "run/1 — detects <mark> tags" do
    test "flags a <mark> tag" do
      issues = lint("<mark>highlighted</mark>")

      assert length(issues) == 1
      issue = hd(issues)
      assert issue.code == "HTML-INLINE"
      assert issue.message =~ "<mark>"
      assert issue.suggestion =~ "==text=="
    end
  end

  describe "run/1 — ignores safe patterns" do
    test "ignores <span> with other classes (e.g. i18n lang)" do
      issues = lint("<span lang=\"en\">English text</span>")
      assert issues == []
    end

    test "ignores <span class=\"Definition\">" do
      markdown = """
      <div class="Definition">
      <span class="Definition">Term</span> — definition here.
      </div>
      """

      issues = lint(markdown)
      assert issues == []
    end

    test "ignores plain text without HTML" do
      markdown = """
      # Title

      Just normal text with no markup issues.
      """

      issues = lint(markdown)
      assert issues == []
    end

    test "ignores Markdown highlight syntax (no false positive)" do
      markdown = "==This is highlighted in Markdown=="
      issues = lint(markdown)
      assert issues == []
    end

    test "ignores code blocks containing the word span" do
      markdown = """
      ```elixir
      defmodule Foo do
        # Use <span> tags for styling
        :ok
      end
      ```
      """

      issues = lint(markdown)
      assert issues == []
    end

    test "ignores inline code" do
      markdown = "Use `==highlight==` syntax, not `<span class=\"hl\">`."
      issues = lint(markdown)
      assert issues == []
    end
  end

  describe "run/1 — message and suggestion content" do
    test "message includes the offending tag" do
      issues = lint("<mark>bad</mark>")
      assert hd(issues).message =~ "<mark>"
    end

    test "suggestion always points to ==text== syntax" do
      markdown = """
      <span class="hl">first</span>
      <mark>second</mark>
      """

      issues = lint(markdown)
      assert Enum.all?(issues, &String.contains?(&1.suggestion, "==text=="))
    end
  end

  describe "name/0 and description/0" do
    test "returns the expected code identifier" do
      assert HtmlInlineTags.name() == "HTML-INLINE"
    end

    test "returns a human-readable description" do
      assert is_binary(HtmlInlineTags.description())
      assert String.length(HtmlInlineTags.description()) > 10
    end
  end
end
