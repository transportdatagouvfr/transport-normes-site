defmodule SiteDeNormes.Lint.TableWithoutHeaders do
  @moduledoc """
  Detects tables without proper headers.

  There are two cases this rule catches:

  1. **All-header tables** — a table where every row is marked as a header (`header: true`).
     This usually means the table has no data rows, which makes it not really a table.

  2. **Single-row tables** — a table with only one row that's treated as a header.
     A single row can't have headers vs data; it should be a regular paragraph or list.

  ## Why this matters

  Tables without headers are confusing to readers and may not render correctly
  in the DSFR styling. The site's Dsfr transform converts single-row tables to
  data rows, but the issue still indicates content that needs fixing.
  """

  @behaviour SiteDeNormes.Lint.Rule

  @impl true
  def name, do: "TABLE-NO-HEADERS"

  @impl true
  def description do
    "Detects tables without proper headers or data rows"
  end

  @impl true
  def run({_file_path, document}) do
    document
    |> Enum.filter(&problematic_table?/1)
    |> Enum.map(fn table -> build_issue(table) end)
  end

  # --- helpers ---

  defp problematic_table?(%MDEx.Table{num_rows: num_rows, nodes: rows}) do
    header_rows = Enum.count(rows, &header_row?/1)

    cond do
      # Single row table — can't have headers vs data
      num_rows == 1 -> true
      # All rows are headers — no data rows at all
      header_rows == num_rows and num_rows > 0 -> true
      true -> false
    end
  end

  defp problematic_table?(_), do: false

  defp header_row?(%MDEx.TableRow{header: true}), do: true
  defp header_row?(_), do: false

  defp build_issue(%MDEx.Table{sourcepos: pos, num_rows: num_rows}) do
    {line, column} = pos.start

    %{
      code: "TABLE-NO-HEADERS",
      line: line,
      column: column,
      message: table_message(num_rows),
      suggestion: table_suggestion(num_rows)
    }
  end

  defp table_message(1), do: "Table has only one row — it cannot have headers"
  defp table_message(n) when n > 1, do: "Table with #{n} rows has no data rows (all are headers)"

  defp table_suggestion(1),
    do: "Remove the table syntax and write as plain text, or add more rows for data"

  defp table_suggestion(_),
    do: "Add a data row after the header row, or convert to a list if there's only one item"
end
