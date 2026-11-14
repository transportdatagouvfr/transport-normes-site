defmodule SiteDeNormes do
  @moduledoc """
  Static site generator. Writes plain files to an output directory.
  """

  alias SiteDeNormes.{FrontMatter, Layouts, PostProcessing.ToC, Transforms.Navigation}

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

  @doc """
  Path of `ref` of `source` in the site, with the git name of the tag or branch as is.

      iex> SiteDeNormes.site_path(%{id: "netex-fr"}, "refs/tags/v2.4.0")
      "profils/netex-fr/v2.4.0"
      iex> SiteDeNormes.site_path(%{id: "netex-fr"}, "refs/heads/v2.5-wip")
      "profils/netex-fr/v2.5-wip"
  """
  def site_path(source, ref),
    do: Path.join(["profils", source.id, String.replace(ref, ~r{^refs/(tags|heads)/}, "")])

  defp build_source(source, sources_dir, output_dir) do
    versions =
      for ref <- source.refs do
        version_dir = Path.join(sources_dir, version_path(source, ref))
        %{ref: ref, pages: build_version(version_dir, output_dir, site_path(source, ref))}
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

  # Writes the page of the Markdown `file` at `path` (relative to the site root) as the
  # index.html of a directory, so that its URL has no .html. Returns that URL
  defp build_page(file, output_dir, path) do
    dir = page_dir(path)
    root = String.duplicate("../", length(Path.split(dir)))

    doc =
      MDEx.new(markdown: File.read!(file))
      |> Navigation.attach()
      |> FrontMatter.attach()
      |> MDEx.Document.run()

    front_matter = MDEx.Document.get_private(doc, :front_matter, %{})
    autonumbering? = Map.get(front_matter, "autonumbering", false) == true
    content = MDEx.to_html!(doc)
    toc_tree = ToC.extract(content)

    write!(
      output_dir,
      Path.join(dir, "index.html"),
      Layouts.render_page(%{
        title: path,
        root: root,
        content: content,
        toc_tree: toc_tree,
        autonumbering: autonumbering?
      })
    )

    dir <> "/"
  end

  # `foo.md` gets the directory `foo`, and `index.md`, `_index.md` (Hugo convention) or
  # `README.md` the directory they are in
  defp page_dir(path) do
    if String.downcase(Path.basename(path)) in ["index.md", "_index.md", "readme.md"],
      do: Path.dirname(path),
      else: Path.rootname(path)
  end

  defp write_home!(output_dir, sources) do
    content = Layouts.render_index(%{sources: sources})
    page = Layouts.render_page(%{title: "Accueil", root: "./", content: content})
    write!(output_dir, "index.html", page)
  end

  defp write!(output_dir, path, content) do
    path = Path.join(output_dir, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  defp robots_txt do
    """
    User-agent: *
    Disallow: /
    """
  end
end
