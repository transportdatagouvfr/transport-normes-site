defmodule Mix.Tasks.Site.Lint do
  @shortdoc "Lints markdown content and writes a report to content_lint_report.html"
  use Mix.Task

  @output_file "content_lint_report.html"
  @sources_dir "_sources"

  @moduledoc """
  Lints all markdown files in `#{inspect(@sources_dir)}` and writes an HTML report.

  ## Usage

      mix site.lint

  The report is written to `#{@output_file}` in the project root. It lists all issues
  found across all markdown files, grouped by file.

  ## Rules

  Lint rules are auto-discovered from modules implementing `SiteDeNormes.Lint.Rule`.
  Currently available:

    * `HTML-INLINE` — inline HTML tags used instead of Markdown syntax
    * `TABLE-NO-HEADERS` — tables without proper headers or data rows

  ## Examples

      # Run linting
      $ mix site.lint

      # Check how many issues were found
      $ mix site.lint | grep "issues"
  """

  @impl Mix.Task
  def run(_args) do
    sources_dir = Path.expand(@sources_dir, File.cwd!())

    unless File.dir?(sources_dir) do
      Mix.shell().error(
        "Sources directory #{inspect(sources_dir)} not found. Run `mix site.fetch` first."
      )

      System.halt(1)
    end

    markdown_files = find_markdown_files(sources_dir)

    if Enum.empty?(markdown_files) do
      Mix.shell().info("No markdown files found in #{inspect(sources_dir)}.")
      File.write!(@output_file, empty_report_html())
    else
      rules = discover_rules()

      if Enum.empty?(rules) do
        Mix.shell().error(
          "No lint rules found. Make sure modules implementing SiteDeNormes.Lint.Rule are compiled."
        )

        System.halt(1)
      end

      Mix.shell().info("Running #{length(rules)} rule(s) on #{length(markdown_files)} file(s)...")

      issues = collect_issues(markdown_files, rules)
      write_report(issues, rules)

      total = Enum.count(issues)
      files_with_issues = issues |> Enum.map(& &1.file) |> Enum.uniq() |> length

      Mix.shell().info(
        "Found #{total} issue(s) in #{files_with_issues} file(s). Report: #{@output_file}"
      )
    end
  end

  # --- Markdown file discovery ---

  defp find_markdown_files(dir) do
    dir
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.map(&Path.relative_to(&1, dir))
    |> Enum.sort()
  end

  # --- Rule auto-discovery ---

  defp discover_rules() do
    lib_dir = Path.join(File.cwd!(), "lib")
    lint_dir = Path.join(lib_dir, "site_de_normes/lint")

    unless File.dir?(lint_dir) do
      []
    else
      # Load all modules from .ex files and check if they implement the Rule behaviour
      lint_dir
      |> Path.join("*.ex")
      |> Path.wildcard()
      |> Enum.map(&file_to_module/1)
      |> Enum.filter(fn mod ->
        Code.ensure_loaded?(mod) && implements_rule?(mod)
      end)
      |> Enum.map(fn mod ->
        %{
          module: mod,
          name: mod.name(),
          description:
            if(function_exported?(mod, :description, 0), do: mod.description(), else: "")
        }
      end)
      |> Enum.sort_by(& &1.name)
    end
  end

  defp file_to_module(file) do
    # Convert lib/site_de_normes/lint/html_inline_tags.ex to SiteDeNormes.Lint.HtmlInlineTags
    base = Path.basename(file, ".ex")
    pascal = String.split(base, "_") |> Enum.map_join("", &String.capitalize/1)
    Module.concat(SiteDeNormes.Lint, pascal)
  end

  defp implements_rule?(mod) do
    # A rule module must export: name/0 and run/2 (at minimum)
    # The @behaviour attribute stores this info in the module's metadata
    case Code.ensure_loaded(mod) do
      {:module, ^mod} ->
        mod.__info__(:attributes)[:behaviour] == [SiteDeNormes.Lint.Rule]

      _ ->
        false
    end
  end

  # --- Issue collection ---

  defp collect_issues(markdown_files, rules) do
    for file <- markdown_files,
        full_path = Path.join(@sources_dir, file),
        markdown = File.read!(full_path),
        doc = parse_document(markdown),
        rule <- rules,
        issue <- rule.module.run({file, doc}) do
      Map.merge(issue, %{file: file, rule_name: rule.name})
    end
  end

  defp parse_document(markdown) do
    MDEx.new(markdown: markdown, extension: [table: true])
    |> MDEx.Document.run()
  end

  # --- Report generation ---

  defp write_report(issues, rules) do
    html = render_html(issues, rules)
    File.write!(@output_file, html)
  end

  defp empty_report_html() do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Content Lint Report</title>
      <style>
        body { font-family: system-ui, sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem; color: #333; }
        h1 { color: #16233F; }
        .summary { background: #f0f7ff; padding: 1rem; border-radius: 4px; margin-bottom: 2rem; }
        .empty { color: #666; font-style: italic; }
      </style>
    </head>
    <body>
      <h1>Content Lint Report</h1>
      <div class="summary">
        <p>No markdown files found to lint.</p>
      </div>
    </body>
    </html>
    """
  end

  defp render_html(issues, _rules) do
    issues_by_file = issues |> Enum.group_by(& &1.file)

    html_body =
      if Enum.empty?(issues_by_file) do
        "<p class=\"empty\">No issues found. All markdown files pass the lint rules.</p>"
      else
        for {file, file_issues} <- issues_by_file do
          rows =
            for issue <- file_issues do
              """
              <tr>
                <td><code>#{escape_html(issue.code)}</code></td>
                <td>L#{issue.line}:C#{issue.column}</td>
                <td>#{escape_html(issue.message)}</td>
                <!-- <td class="suggestion">#{escape_html(issue.suggestion)}</td> -->
              </tr>
              """
            end

          """
          <div class="file-section">
            <h3 class="file-path">#{escape_html(file)}</h3>
            <table>
              <thead>
                <tr>
                  <th>Code</th>
                  <th>Position</th>
                  <th>Issue</th>
                  <!-- <th>Suggestion</th> -->
                </tr>
              </thead>
              <tbody>
                #{rows}
              </tbody>
            </table>
          </div>
          """
        end
        |> Enum.join("\n")
      end

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Content Lint Report</title>
      <style>
        body { font-family: system-ui, -apple-system, sans-serif; max-width: 960px; margin: 0 auto; padding: 2rem 1rem; color: #333; line-height: 1.6; }
        h1 { color: #16233F; border-bottom: 2px solid #000091; padding-bottom: 0.5rem; }
        h2 { color: #162340; margin-top: 2rem; }
        h3.file-path { color: #000091; background: #f6f6f6; padding: 0.5rem 1rem; border-radius: 4px; font-family: monospace; margin-top: 1.5rem; }
        .summary { background: #f0f7ff; padding: 1rem 1.5rem; border-radius: 4px; margin-bottom: 2rem; border-left: 4px solid #000091; }
        .summary strong { color: #000091; }
        table { width: 100%; border-collapse: collapse; margin: 0.5rem 0 1.5rem 0; }
        th, td { text-align: left; padding: 0.6rem 0.8rem; border-bottom: 1px solid #e0e0e0; vertical-align: top; }
        th { background: #f6f6f6; font-weight: 600; color: #333; white-space: nowrap; }
        td:first-child { white-space: nowrap; }
        code { background: #f0f0f0; padding: 0.15rem 0.4rem; border-radius: 3px; font-size: 0.9em; color: #c7254e; }
        .suggestion { color: #155724; background: #f0fff4; padding: 0.3rem 0.6rem; border-radius: 3px; font-size: 0.95em; }
        .empty { color: #666; font-style: italic; }
        .file-section { margin-bottom: 1rem; }
        footer { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid #e0e0e0; color: #888; font-size: 0.85em; text-align: center; }
      </style>
    </head>
    <body>
      <h1>Content Lint Report</h1>

      <div class="summary">
        #{summary_html(issues)}
      </div>

      #{html_body}

      <footer>
        Generated by <code>mix site.lint</code> — Transport Données Normes
      </footer>
    </body>
    </html>
    """
  end

  defp summary_html([]) do
    "<p>No issues found. All markdown files pass the lint rules.</p>"
  end

  defp summary_html(issues) do
    total = length(issues)

    by_code =
      issues
      |> Enum.group_by(& &1.code)
      |> Map.new(fn {code, list} -> {code, length(list)} end)

    code_details =
      for {code, count} <- Enum.sort(by_code),
          do: "<li><strong>#{escape_html(code)}</strong>: #{count} issue(s)</li>"

    """
    <p><strong>#{total}</strong> issue(s) found across the markdown content.</p>
    <ul>#{code_details}</ul>
    """
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
