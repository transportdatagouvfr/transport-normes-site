defmodule SiteDeNormes do
  @moduledoc """
  Static site generator. Writes plain files to an output directory.
  """

  alias SiteDeNormes.{FrontMatter, Layouts, PostProcessing.ToC, SnippetsLanguageInference}
  alias SiteDeNormes.Transforms.{Dsfr, Navigation, DropEmbeddedStylesheets}

  @doc """
  Renders each Markdown file of each version of `sources` (fetched in `sources_dir`
  by `mix site.fetch`) to an HTML page, plus the pages of the `extras` content (see
  `config/config.exs`), plus a home page listing them.
  """
  def build(output_dir, sources_dir, sources, extras \\ nil) do
    File.rm_rf!(output_dir)
    File.mkdir_p!(output_dir)

    sources = for source <- sources, do: build_source(source, sources_dir, output_dir)

    extras =
      if extras,
        do: build_extras(extras, sources_dir, output_dir),
        else: %{placed: [], unplaced: []}

    write_home!(output_dir, sources, extras)
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
  def site_path(source, ref), do: Path.join(profile_path(source), version_name(ref))

  defp profile_path(source), do: Path.join("profils", source.id)

  # Git name of the tag or branch, e.g. "v2.4.0" for "refs/tags/v2.4.0"
  defp version_name(ref), do: String.replace(ref, ~r{^refs/(tags|heads)/}, "")

  # Builds each version of `source`, plus its page listing them
  defp build_source(source, sources_dir, output_dir) do
    # For the version selector of each page, the page of the profile and the home page
    versions =
      for ref <- source.refs, do: %{name: version_name(ref), path: site_path(source, ref)}

    for ref <- source.refs do
      version_dir = Path.join(sources_dir, version_path(source, ref))

      version = %{
        profile: source.name,
        profile_id: source.id,
        name: version_name(ref),
        path: site_path(source, ref),
        all: versions,
        # Files of the version on GitHub, on its tag or branch
        source_url: "#{source.url}/blob/#{version_name(ref)}"
      }

      build_version(version_dir, output_dir, site_path(source, ref), version)
    end

    write_profile!(output_dir, source, versions)
    %{name: source.name, versions: versions}
  end

  # Renders the Markdown files of the version to `path` in the site, and copies the other
  # files (images, examples...) next to them, so that the links between them work as is
  defp build_version(version_dir, output_dir, path, version) do
    File.dir?(version_dir) || raise "#{version_dir} not found, run `mix site.fetch` first"

    {markdown, others} =
      version_dir |> list_files() |> Enum.split_with(&(Path.extname(&1) == ".md"))

    for file <- others do
      write!(output_dir, Path.join(path, file), File.read!(Path.join(version_dir, file)))
    end

    # URLs known before rendering, for each page to list the pages of its version
    pages = for file <- markdown, do: %{path: file, href: page_dir(Path.join(path, file)) <> "/"}

    for page <- pages do
      assigns = %{
        version: version,
        file: page.path,
        source_url: "#{version.source_url}/#{page.path}",
        parents: [{"Accueil", ""}, {"#{version.profile} #{version.name}", version.path <> "/"}],
        pages_title: "Pages du profil #{version.profile} #{version.name}",
        version_pages: pages,
        href: page.href
      }

      build_page(
        Path.join(version_dir, page.path),
        output_dir,
        Path.join(path, page.path),
        assigns
      )
    end
  end

  @unplaced_path "a-placer"
  @unplaced_title "Pages à emplacement provisoire"

  # Renders the pages of the extra content placed in the site, and the other ones under
  # `a-placer/`, listed together. Returns the links of the home page to both
  defp build_extras(extras, sources_dir, output_dir) do
    dir = Path.join(sources_dir, version_path(extras, extras.ref))
    File.dir?(dir) || raise "#{dir} not found, run `mix site.fetch` first"
    source_url = "#{extras.url}/blob/#{version_name(extras.ref)}"

    placed =
      for {file, path} <- extras.pages do
        assigns = %{
          file: file,
          source_url: "#{source_url}/#{file}",
          parents: [{"Accueil", ""}],
          beta: true
        }

        title = build_page(Path.join(dir, file), output_dir, path <> ".md", assigns)
        %{title: title, href: path <> "/"}
      end

    pages =
      for file <- list_files(Path.join(dir, extras.unplaced)),
          Path.extname(file) == ".md",
          path = Path.join(extras.unplaced, file),
          not Map.has_key?(extras.pages, path) do
        site_path = Path.join(@unplaced_path, file)
        %{path: path, site_path: site_path, href: page_dir(site_path) <> "/"}
      end

    unplaced =
      for page <- pages do
        assigns = %{
          file: page.path,
          source_url: "#{source_url}/#{page.path}",
          parents: [{"Accueil", ""}, {@unplaced_title, @unplaced_path <> "/"}],
          pages_title: @unplaced_title,
          beta: true,
          version_pages: pages,
          href: page.href
        }

        title = build_page(Path.join(dir, page.path), output_dir, page.site_path, assigns)
        %{title: title, href: page.href}
      end

    write!(
      output_dir,
      Path.join(@unplaced_path, "index.html"),
      Layouts.render_page(%{
        title: @unplaced_title,
        breadcrumb: [{"Accueil", "../"}, {@unplaced_title, nil}],
        root: "../",
        content: Layouts.render_unplaced(%{title: @unplaced_title}),
        pages_title: @unplaced_title,
        beta: true,
        version_pages: pages,
        href: @unplaced_path <> "/"
      })
    )

    %{placed: placed, unplaced: unplaced}
  end

  # Relative paths of the files in `dir`. Path.wildcard skips dotfiles, like the .git
  # file of a version (it contains a local path, not to be published)
  defp list_files(dir) do
    for file <- Path.wildcard(Path.join(dir, "**")), File.regular?(file) do
      Path.relative_to(file, dir)
    end
  end

  # Writes the page of the Markdown `file` at `path` (relative to the site root) as the
  # index.html of a directory, so that its URL has no .html. Returns the title of the page
  # `assigns`: URL of `file` on GitHub, `parents` in the breadcrumb (paths relative to the
  # site root), and for the pages of a version, the version and its pages
  defp build_page(file, output_dir, path, assigns) do
    dir = page_dir(path)
    root = String.duplicate("../", length(Path.split(dir)))

    markdown =
      file
      |> File.read!()
      |> strip_invisible_whitespace()

    doc =
      MDEx.new(markdown: markdown, extension: [table: true])
      |> Navigation.attach()
      |> FrontMatter.attach()
      |> SnippetsLanguageInference.attach()
      |> MDEx.Document.run()
      |> DropEmbeddedStylesheets.attach()

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

    {toc_tree, toc_annexes} = ToC.extract(content)
    # Hugo pages have their title in the front matter, their first h1 being a section.
    # Some pages have neither (e.g. the README of siri-fr v1.7)
    title = front_matter["title"] || first_h1(content) || Path.basename(file)

    profile_id = assigns |> Map.get(:version, %{}) |> Map.get(:profile_id, "")

    write!(
      output_dir,
      Path.join(dir, "index.html"),
      Layouts.render_page(
        Map.merge(assigns, %{
          title: path,
          breadcrumb:
            for({label, href} <- assigns.parents, do: {label, root <> href}) ++ [{title, nil}],
          root: root,
          content: content,
          toc_tree: toc_tree,
          toc_annexes: toc_annexes,
          autonumbering: autonumbering?,
          profile_id: profile_id
        })
      )
    )

    title
  end

  defp first_h1(html),
    do:
      html
      |> Floki.parse_document!()
      |> Floki.find("h1")
      |> Enum.map(&Floki.text/1)
      |> List.first()

  # `foo.md` gets the directory `foo`, and `index.md`, `_index.md` (Hugo convention) or
  # `README.md` the directory they are in
  defp page_dir(path) do
    if String.downcase(Path.basename(path)) in ["index.md", "_index.md", "readme.md"],
      do: Path.dirname(path),
      else: Path.rootname(path)
  end

  defp write_home!(output_dir, sources, extras) do
    content = Layouts.render_index(%{sources: sources, extras: extras})

    page =
      Layouts.render_page(%{
        title: "Accueil",
        breadcrumb: [{"Accueil", nil}],
        root: "./",
        content: content
      })

    write!(output_dir, "index.html", page)
  end

  defp write_profile!(output_dir, source, versions) do
    content = Layouts.render_profile(%{name: source.name, versions: versions})

    page =
      Layouts.render_page(%{
        title: source.name,
        breadcrumb: [{"Accueil", "../../"}, {source.name, nil}],
        root: "../../",
        content: content
      })

    write!(output_dir, Path.join(profile_path(source), "index.html"), page)
  end

  # The output directory being emptied first, a file written twice means that two pages
  # (or files) have the same URL, e.g. an extra page placed on a page of a profile: the
  # build fails instead of silently publishing only one of them
  defp write!(output_dir, path, content) do
    full_path = Path.join(output_dir, path)
    File.exists?(full_path) && raise "#{path} written twice: two pages have the same URL"
    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, content)
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
