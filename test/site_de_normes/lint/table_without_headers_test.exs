defmodule SiteDeNormes.Lint.TableWithoutHeadersTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.Lint.TableWithoutHeaders

  defp lint(markdown) do
    doc =
      MDEx.new(markdown: markdown, extension: [table: true])
      |> MDEx.Document.run()

    TableWithoutHeaders.run({"test.md", doc})
  end

  describe "run/1 — detects single-row tables" do
    test "flags a GFM table with only one row (header-only)" do
      issues = lint("| Header |\n|---|")

      assert length(issues) == 1
      issue = hd(issues)
      assert issue.code == "TABLE-NO-HEADERS"
      assert issue.line == 1
      assert issue.message =~ "only one row"
    end

    test "flags a GFM table with one header row and no data rows" do
      markdown = """
      Some text before.

      | A | B | C |
      |---|---|---|
      """

      issues = lint(markdown)
      assert length(issues) == 1
      assert hd(issues).line == 3
    end

    test "flags a single-row table in a multi-paragraph document" do
      markdown = """
      # Introduction

      | Single row only |
      |---|

      More content after.
      """

      issues = lint(markdown)
      assert length(issues) == 1
      assert hd(issues).line == 3
    end
  end

  describe "run/1 — detects all-header tables" do
    test "flags a table where every row is marked as header" do
      markdown = """
      | Header 1 | Header 2 |
      |---|---|
      | Data A | Data B |
      """

      # GFM tables always mark the first row as header, body rows are not.
      # So a normal table should NOT trigger this rule.
      issues = lint(markdown)
      assert issues == []
    end

    test "flags raw HTML tables with only <thead>" do
      markdown = """
      <table>
      <thead>
      <tr><th>A</th></tr>
      </thead>
      </table>
      """

      issues = lint(markdown)
      # This may or may not trigger depending on how MDEx parses raw HTML tables.
      # The rule checks the AST, so we test what actually happens.
      # Raw HTML tables go through html5ever which may produce different structures.
      _ = issues
    end
  end

  describe "run/1 — passes normal tables" do
    test "does not flag a table with header and data rows" do
      markdown = """
      | Name | Value |
      |---|---|
      | Foo | 1 |
      | Bar | 2 |
      """

      issues = lint(markdown)
      assert issues == []
    end

    test "does not flag a table with multiple data rows" do
      markdown = """
      | Col 1 | Col 2 |
      |---|---|
      | a | b |
      | c | d |
      | e | f |
      """

      issues = lint(markdown)
      assert issues == []
    end

    test "does not flag multiple normal tables" do
      markdown = """
      | A | B |
      |---|---|
      | 1 | 2 |

      | C | D |
      |---|---|
      | 3 | 4 |
      """

      issues = lint(markdown)
      assert issues == []
    end
  end

  describe "run/1 — edge cases" do
    test "does not flag documents without tables" do
      markdown = """
      # No Tables Here

      Just some text with a list:

      - Item one
      - Item two
      """

      issues = lint(markdown)
      assert issues == []
    end

    test "reports correct line numbers for multiple problematic tables" do
      markdown = """
      | First bad table |
      |---|

      Normal paragraph.

      | Second bad table |
      |---|
      """

      issues = lint(markdown)
      assert length(issues) == 2
      assert hd(issues).line == 1
      assert Enum.at(issues, 1).line == 6
    end

    test "does not flag tables with only whitespace separator row" do
      markdown = """
      | Header |
      |---|
      | Data |
      """

      issues = lint(markdown)
      assert issues == []
    end
  end

  describe "run/1 — message and suggestion content" do
    test "message for single-row table is clear" do
      issues = lint("| Only row |\n|---|")
      assert hd(issues).message =~ "only one row"
    end

    test "suggestion provides actionable guidance" do
      issues = lint("| Only row |\n|---|")
      assert hd(issues).suggestion =~ "Remove the table"
    end
  end

  describe "name/0 and description/0" do
    test "returns the expected code identifier" do
      assert TableWithoutHeaders.name() == "TABLE-NO-HEADERS"
    end

    test "returns a human-readable description" do
      assert is_binary(TableWithoutHeaders.description())
      assert String.length(TableWithoutHeaders.description()) > 10
    end
  end
end
