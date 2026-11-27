defmodule SiteDeNormesTest do
  use ExUnit.Case, async: true

  import LazyHTML, only: [from_document: 1, query: 2, text: 1, attribute: 2]

  @moduletag :tmp_dir

  doctest SiteDeNormes

  @source %{
    id: "netex-fr",
    name: "NeTEx FR",
    url: "https://github.com/etalab/transport-profil-netex-fr",
    refs: ["refs/tags/v1.0"]
  }

  # Same layout as written by `mix site.fetch`
  setup %{tmp_dir: tmp_dir} do
    sources_dir = Path.join(tmp_dir, "sources")
    write!(sources_dir, "netex-fr/tags/v1.0/README.md", "# NeTEx")
    write!(sources_dir, "netex-fr/tags/v1.0/NeTEx/_index.md", "---\ntitle: NeTEx\n---\n")
    write!(sources_dir, "netex-fr/tags/v1.0/NeTEx/arrets/index.md", "# Arrêts\n![](media/a.png)")
    write!(sources_dir, "netex-fr/tags/v1.0/NeTEx/arrets/media/a.png", "PNG")
    write!(sources_dir, "netex-fr/tags/v1.0/changelog.md", "# Changelog")
    write!(sources_dir, "netex-fr/tags/v1.0/.git", "gitdir: /local/path")

    output_dir = Path.join(tmp_dir, "site")
    SiteDeNormes.build(output_dir, sources_dir, [@source])
    %{sources_dir: sources_dir, output_dir: output_dir}
  end

  test "build/3 renders each markdown file, and copies the other files next to it", ctx do
    page = read!(ctx.output_dir, "profils/netex-fr/v1.0/arrets/index.html")

    assert page |> query("h1") |> text() == "Arrêts"
    assert page |> query("img") |> attribute("src") == ["media/a.png"]

    assert File.exists?(Path.join(ctx.output_dir, "profils/netex-fr/v1.0/arrets/media/a.png"))

    refute File.exists?(Path.join(ctx.output_dir, "profils/netex-fr/v1.0/.git"))
  end

  test "build/3 publishes NeTEx/ at the root of the version, without its _index.md", ctx do
    refute File.exists?(Path.join(ctx.output_dir, "profils/netex-fr/v1.0/NeTEx"))

    assert read!(ctx.output_dir, "profils/netex-fr/v1.0/index.html") |> query("h1") |> text() ==
             "NeTEx"
  end

  # File.ls! and not File.exists?, the file system of macOS being case-insensitive
  test "build/3 publishes the files with lowercase paths", ctx do
    write!(ctx.sources_dir, "netex-fr/tags/v1.0/exemples/AccesLibre/index.md", "# Accès")
    write!(ctx.sources_dir, "netex-fr/tags/v1.0/exemples/AccesLibre/Stop.xml", "<Stop/>")
    SiteDeNormes.build(ctx.output_dir, ctx.sources_dir, [@source])

    exemples = Path.join(ctx.output_dir, "profils/netex-fr/v1.0/exemples")
    assert File.ls!(exemples) == ["acceslibre"]

    assert exemples |> Path.join("acceslibre") |> File.ls!() |> Enum.sort() == [
             "index.html",
             "stop.xml"
           ]
  end

  test "build/3 writes a page per profile listing its versions, also listed on the home page",
       ctx do
    home = read!(ctx.output_dir, "index.html")

    assert home |> query("h2") |> text() == "NeTEx FR"
    assert home |> query("main li a") |> attribute("href") == ["profils/netex-fr/v1.0/"]
    assert home |> query("main li a") |> text() == "v1.0"

    page = read!(ctx.output_dir, "profils/netex-fr/index.html")

    assert page |> query("h1") |> text() == "NeTEx FR"
    assert page |> query("main li a") |> attribute("href") == ["v1.0/"]
    assert page |> query(~s(a[title^="Accueil"])) |> attribute("href") == ["../../"]
  end

  test "build/3 writes each page as the index.html of a directory, linking to the home page",
       ctx do
    page = read!(ctx.output_dir, "profils/netex-fr/v1.0/changelog/index.html")

    assert page |> query("h1") |> text() == "Changelog"
    assert page |> query(~s(a[title^="Accueil"])) |> attribute("href") == ["../../../../"]
  end

  test "build/3 adds to each page a selector of the versions of its profile", ctx do
    source = %{@source | refs: ["refs/heads/v2.0-wip", "refs/tags/v1.0"]}
    write!(ctx.sources_dir, "netex-fr/heads/v2.0-wip/README.md", "# NeTEx")
    SiteDeNormes.build(ctx.output_dir, ctx.sources_dir, [source])

    page = read!(ctx.output_dir, "profils/netex-fr/v1.0/arrets/index.html")

    assert page |> query("button[aria-controls=version-menu]") |> text() |> String.trim() ==
             "NeTEx FR v1.0"

    assert page |> query("#version-menu a") |> attribute("href") == [
             "../../../../profils/netex-fr/v2.0-wip/",
             "../../../../profils/netex-fr/v1.0/"
           ]

    assert page |> query("#version-menu a[aria-current]") |> text() |> String.trim() == "v1.0"

    assert read!(ctx.output_dir, "index.html") |> query("#version-menu") |> Enum.empty?()
  end

  test "build/3 links each page to its source file on GitHub, on its tag or branch", ctx do
    source = %{@source | refs: ["refs/heads/v2.0-wip", "refs/tags/v1.0"]}
    write!(ctx.sources_dir, "netex-fr/heads/v2.0-wip/README.md", "# NeTEx")
    SiteDeNormes.build(ctx.output_dir, ctx.sources_dir, [source])

    page = read!(ctx.output_dir, "profils/netex-fr/v1.0/arrets/index.html")

    assert page |> query(~s(a[href*="github.com"])) |> attribute("href") == [
             "https://github.com/etalab/transport-profil-netex-fr/blob/v1.0/NeTEx/arrets/index.md"
           ]

    assert page |> query(".fr-breadcrumb__after") |> text() |> String.trim() ==
             "(source : NeTEx/arrets/index.md)"

    assert read!(ctx.output_dir, "profils/netex-fr/v2.0-wip/index.html")
           |> query(~s(a[href*="github.com"]))
           |> attribute("href") == [
             "https://github.com/etalab/transport-profil-netex-fr/blob/v2.0-wip/README.md"
           ]
  end

  test "build/3 adds to each page a breadcrumb: home, profile and version, page", ctx do
    links =
      read!(ctx.output_dir, "profils/netex-fr/v1.0/arrets/index.html")
      |> query(".fr-breadcrumb__link")

    assert Enum.map(links, &String.trim(text(&1))) == ["Accueil", "NeTEx FR v1.0", "Arrêts"]

    assert attribute(links, "href") == [
             "../../../../",
             "../../../../profils/netex-fr/v1.0/"
           ]

    assert links |> query("[aria-current=page]") |> text() |> String.trim() == "Arrêts"

    # Including on the home page of the version (its README)
    assert read!(ctx.output_dir, "profils/netex-fr/v1.0/index.html")
           |> query(".fr-breadcrumb__link")
           |> Enum.map(&String.trim(text(&1))) == ["Accueil", "NeTEx FR v1.0", "NeTEx"]

    # Also on the home page and the page of the profile, which have no source file
    for {path, labels} <- [
          {"index.html", ["Accueil"]},
          {"profils/netex-fr/index.html", ["Accueil", "NeTEx FR"]}
        ] do
      page = read!(ctx.output_dir, path)
      assert page |> query(".fr-breadcrumb__link") |> Enum.map(&String.trim(text(&1))) == labels
      assert page |> query(~s(a[href*="github.com"])) |> Enum.empty?()
    end
  end

  test "build/3 lists on each page the pages of its version, the current one marked", ctx do
    page = read!(ctx.output_dir, "profils/netex-fr/v1.0/arrets/index.html")

    assert page |> query("#version-pages-title") |> text() =~
             ~r/^\s*Pages du profil NeTEx FR v1.0\s/

    links = query(page, ".version-pages a")

    assert Enum.map(links, &String.trim(text(&1))) ==
             ["NeTEx/arrets/index.md", "README.md", "changelog.md"]

    assert attribute(links, "href") == [
             "../../../../profils/netex-fr/v1.0/arrets/",
             "../../../../profils/netex-fr/v1.0/",
             "../../../../profils/netex-fr/v1.0/changelog/"
           ]

    assert page |> query(".version-pages [aria-current=page]") |> text() |> String.trim() ==
             "NeTEx/arrets/index.md"

    assert read!(ctx.output_dir, "index.html") |> query(".version-pages") |> Enum.empty?()
  end

  test "build/3 names a page in the breadcrumb by the title of its front matter, else its first h1, else its file",
       ctx do
    write!(ctx.sources_dir, "netex-fr/tags/v1.0/a.md", "---\ntitle: Titre\n---\n# Section")
    write!(ctx.sources_dir, "netex-fr/tags/v1.0/b.md", "## Not a title")
    SiteDeNormes.build(ctx.output_dir, ctx.sources_dir, [@source])

    for {page, title} <- [{"a", "Titre"}, {"b", "b.md"}, {"changelog", "Changelog"}] do
      assert read!(ctx.output_dir, "profils/netex-fr/v1.0/#{page}/index.html")
             |> query(".fr-breadcrumb__link[aria-current=page]")
             |> text()
             |> String.trim() == title

      # <title> follows the same priority: front matter > first h1 > filename
      assert read!(ctx.output_dir, "profils/netex-fr/v1.0/#{page}/index.html")
             |> query("title")
             |> text()
             |> String.trim() == title <> " - normes.transport.data.gouv.fr v2 (bêta)"
    end
  end

  test "build/4 places the listed extra pages, and lists the other ones under a-placer/", ctx do
    extras = %{
      id: "extras",
      url: "https://github.com/etalab/transport-normes-site-extras",
      ref: "refs/heads/v1.0-wip",
      pages: %{"content/gouvernance.md" => "gouvernance"},
      unplaced: "content"
    }

    write!(ctx.sources_dir, "extras/heads/v1.0-wip/README.md", "# Dépôt")

    write!(
      ctx.sources_dir,
      "extras/heads/v1.0-wip/content/gouvernance.md",
      "---\ntitle: Gouv\n---\n"
    )

    write!(ctx.sources_dir, "extras/heads/v1.0-wip/content/netex.md", "---\ntitle: NeTEx\n---\n")
    SiteDeNormes.build(ctx.output_dir, ctx.sources_dir, [@source], extras)

    page = read!(ctx.output_dir, "gouvernance/index.html")

    assert page |> query(".fr-breadcrumb__link") |> Enum.map(&String.trim(text(&1))) == [
             "Accueil",
             "Gouv"
           ]

    assert page |> query(".fr-breadcrumb__after a") |> attribute("href") ==
             [
               "https://github.com/etalab/transport-normes-site-extras/blob/v1.0-wip/content/gouvernance.md"
             ]

    assert page |> query(".version-menu") |> Enum.empty?()
    assert page |> query("main .fr-alert") |> text() =~ "Version bêta"

    page = read!(ctx.output_dir, "a-placer/netex/index.html")

    assert page |> query(".fr-breadcrumb__link") |> Enum.map(&String.trim(text(&1))) ==
             ["Accueil", "Pages à emplacement provisoire", "NeTEx"]

    for path <- ["a-placer/index.html", "a-placer/netex/index.html"] do
      page = read!(ctx.output_dir, path)

      assert page |> query(".version-pages a") |> attribute("href") |> Enum.map(&Path.basename/1) ==
               ["netex"]

      assert page |> query("main .fr-alert") |> text() =~ "Version bêta"
    end

    refute File.exists?(Path.join(ctx.output_dir, "a-placer/gouvernance"))
    refute File.exists?(Path.join(ctx.output_dir, "a-placer/README"))

    home = read!(ctx.output_dir, "index.html")
    section = query(home, "main section.extras")
    assert section |> query("h2") |> text() =~ ~r/^\s*Contenu additionnel\s/
    assert section |> query("h2 .fr-badge") |> text() =~ "Bêta"

    assert section |> query("p") |> Enum.map(&String.trim(text(&1))) == [
             "Emplacement défini",
             "Emplacement provisoire"
           ]

    [placed, unplaced] = Enum.to_list(query(section, "ul"))
    assert placed |> query("a") |> attribute("href") == ["gouvernance/"]
    assert unplaced |> query("a") |> Enum.map(&text/1) == ["NeTEx"]
    assert unplaced |> query("a") |> attribute("href") == ["a-placer/netex/"]
  end

  test "build/4 raises if an extra page has the URL of another page", ctx do
    write!(ctx.sources_dir, "extras/heads/v1.0-wip/content/netex.md", "# NeTEx")
    write!(ctx.sources_dir, "extras/heads/v1.0-wip/content/autre.md", "# Autre")

    for path <- ["profils/netex-fr", "profils/netex-fr/v1.0/changelog", "a-placer/autre"] do
      extras = %{
        id: "extras",
        url: "https://github.com/etalab/transport-normes-site-extras",
        ref: "refs/heads/v1.0-wip",
        pages: %{"content/netex.md" => path},
        unplaced: "content"
      }

      assert_raise RuntimeError, ~r/written twice/, fn ->
        SiteDeNormes.build(ctx.output_dir, ctx.sources_dir, [@source], extras)
      end
    end
  end

  test "build/3 raises if a version wasn't fetched", ctx do
    source = %{@source | refs: ["refs/tags/v2.0"]}

    assert_raise RuntimeError, ~r/run `mix site.fetch` first/, fn ->
      SiteDeNormes.build(ctx.output_dir, ctx.sources_dir, [source])
    end
  end

  # Beta: must not be indexed
  # ── strip_invisible_whitespace ───────────────────────────────────────────

  describe "strip_invisible_whitespace/1" do
    test "removes soft hyphens (U+00AD)" do
      input = "Classifi\u00ADcation"
      assert SiteDeNormes.strip_invisible_whitespace(input) == "Classification"
    end

    test "removes zero-width spaces (U+200B)" do
      input = "hello\u200Bworld"
      assert SiteDeNormes.strip_invisible_whitespace(input) == "helloworld"
    end

    test "removes both soft hyphens and zero-width spaces" do
      input = "Classifi\u00ADcation\u200Bcolumn"
      assert SiteDeNormes.strip_invisible_whitespace(input) == "Classificationcolumn"
    end

    test "leaves normal text unchanged" do
      input = "Classification column"
      assert SiteDeNormes.strip_invisible_whitespace(input) == input
    end

    test "handles empty string" do
      assert SiteDeNormes.strip_invisible_whitespace("") == ""
    end
  end

  test "build/3 prevents indexing", ctx do
    assert File.read!(Path.join(ctx.output_dir, "robots.txt")) == "User-agent: *\nDisallow: /\n"

    assert read!(ctx.output_dir, "index.html")
           |> query(~s(meta[name="robots"]))
           |> attribute("content") ==
             ["noindex, nofollow"]
  end

  defp read!(dir, path), do: dir |> Path.join(path) |> File.read!() |> from_document()

  defp write!(dir, path, content) do
    path = Path.join(dir, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
