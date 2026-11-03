defmodule SiteDeNormes do
  @moduledoc """
  Static site generator. Writes plain files to an output directory.
  """

  alias SiteDeNormes.{FrontMatter, Layouts, PostProcessing.ToC}
  alias SiteDeNormes.Transforms.{Dsfr, Navigation}

  @doc """
  Renders each Markdown file of each version of `sources` (fetched in `sources_dir`
  by `mix site.fetch`) to an HTML page, plus a home page listing them.
  """
  def build(output_dir, sources_dir, sources) do
    File.rm_rf!(output_dir)
    File.mkdir_p!(output_dir)

    sources = for source <- sources, do: build_source(source, sources_dir, output_dir)
    write_home!(output_dir, sources)
    write!(output_dir, "robots.txt", robots_txt())
  end

  @doc ~s(Directory of `ref` of `source`, relative to the sources directory, e.g. "netex-fr/tags/v2.4.0".)
  def version_path(source, ref), do: Path.join(source.id, String.replace_prefix(ref, "refs/", ""))

  # Each version gets the same path in the site as in the sources directory
  defp build_source(source, sources_dir, output_dir) do
    versions =
      for ref <- source.refs do
        path = version_path(source, ref)
        %{ref: ref, pages: build_version(Path.join(sources_dir, path), output_dir, path)}
      end

    %{name: source.name, versions: versions}
  end

  # Renders the Markdown files of the version to `path` in the site, and copies the other
  # files (images, examples...) next to them, so that the links between them work as is
  defp build_version(version_dir, output_dir, path) do
    File.dir?(version_dir) || raise "#{version_dir} not found, run `mix site.fetch` first"

    {markdown, others} =
      version_dir |> list_files() |> Enum.split_with(&(Path.extname(&1) == ".md"))

    for file <- others do
      write!(output_dir, Path.join(path, file), File.read!(Path.join(version_dir, file)))
    end

    for file <- markdown do
      %{
        path: file,
        href: build_page(Path.join(version_dir, file), output_dir, Path.join(path, file))
      }
    end
  end

  # Relative paths of the files in `dir`. Path.wildcard skips dotfiles, like the .git
  # file of a version (it contains a local path, not to be published)
  defp list_files(dir) do
    for file <- Path.wildcard(Path.join(dir, "**")), File.regular?(file) do
      Path.relative_to(file, dir)
    end
  end

  # Writes the page of the Markdown `file` at `path` (relative to the site root, with an
  # .html extension instead), returns that path
  defp build_page(file, output_dir, path) do
    href = Path.rootname(path) <> ".html"
    root = String.duplicate("../", length(Path.split(href)) - 1)

    markdown =
      file
      |> File.read!()
      |> strip_invisible_whitespace()

    doc =
      MDEx.new(
        markdown: markdown,
        extension: [table: true]
      )
      |> Navigation.attach()
      |> FrontMatter.attach()
      |> MDEx.Document.run()

    front_matter = MDEx.Document.get_private(doc, :front_matter, %{})
    autonumbering? = Map.get(front_matter, "autonumbering", false) == true

    content =
      doc
      |> MDEx.to_html!(
        render: [github_pre_lang: true, full_info_string: true, unsafe: true],
        syntax_highlight: [
          engine: :lumis,
          opts: [
            formatter:
              {:html_multi_themes,
               themes: [light: "github_light", dark: "github_dark"], default_theme: "light-dark()"}
          ]
        ]
      )
      |> Dsfr.wrap_tables()

    toc_tree = ToC.extract(content)

    write!(
      output_dir,
      href,
      Layouts.render_page(%{
        title: path,
        root: root,
        content: content,
        toc_tree: toc_tree,
        autonumbering: autonumbering?
      })
    )

    href
  end

  defp write_home!(output_dir, sources) do
    content = Layouts.render_index(%{sources: sources})
    page = Layouts.render_page(%{title: "Accueil", root: "", content: content})
    write!(output_dir, "index.html", page)
  end

  defp write!(output_dir, path, content) do
    path = Path.join(output_dir, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  @doc "Removes soft hyphens (U+00AD) and zero-width spaces (U+200B)."
  def strip_invisible_whitespace(text) do
    text
    |> String.replace("\u00AD", "")
    |> String.replace("\u200B", "")
  end

  defp robots_txt do
    """
    User-agent: *
    Disallow: /
    """
  end
end
