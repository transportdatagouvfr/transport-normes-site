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
    write!(sources_dir, "netex-fr/tags/v1.0/NeTEx/arrets/index.md", "# Arrêts\n![](media/a.png)")
    write!(sources_dir, "netex-fr/tags/v1.0/NeTEx/arrets/media/a.png", "PNG")
    write!(sources_dir, "netex-fr/tags/v1.0/changelog.md", "# Changelog")
    write!(sources_dir, "netex-fr/tags/v1.0/.git", "gitdir: /local/path")

    output_dir = Path.join(tmp_dir, "site")
    SiteDeNormes.build(output_dir, sources_dir, [@source])
    %{sources_dir: sources_dir, output_dir: output_dir}
  end

  test "build/3 renders each markdown file, and copies the other files next to it", ctx do
    page = read!(ctx.output_dir, "profils/netex-fr/v1.0/NeTEx/arrets/index.html")

    assert page |> query("h1") |> text() == "Arrêts"
    assert page |> query("img") |> attribute("src") == ["media/a.png"]

    assert File.exists?(
             Path.join(ctx.output_dir, "profils/netex-fr/v1.0/NeTEx/arrets/media/a.png")
           )

    refute File.exists?(Path.join(ctx.output_dir, "profils/netex-fr/v1.0/.git"))
  end

  test "build/3 writes a home page linking to each page, with URLs without .html", ctx do
    assert read!(ctx.output_dir, "index.html") |> query("li a") |> attribute("href") == [
             "profils/netex-fr/v1.0/NeTEx/arrets/",
             "profils/netex-fr/v1.0/",
             "profils/netex-fr/v1.0/changelog/"
           ]
  end

  test "build/3 writes a page per profile listing its versions, linked from the home page",
       ctx do
    home = read!(ctx.output_dir, "index.html")

    assert home |> query("h2 a") |> attribute("href") == ["profils/netex-fr/"]
    assert home |> query("h3") |> text() == "v1.0"

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

    page = read!(ctx.output_dir, "profils/netex-fr/v1.0/NeTEx/arrets/index.html")

    assert page |> query("label[for=version-select]") |> text() == "NeTEx FR"

    assert page |> query("#version-select option") |> attribute("value") == [
             "../../../../../profils/netex-fr/v2.0-wip/",
             "../../../../../profils/netex-fr/v1.0/"
           ]

    assert page |> query("#version-select option[selected]") |> text() |> String.trim() ==
             "v1.0"

    assert read!(ctx.output_dir, "index.html") |> query("#version-select") |> Enum.empty?()
  end

  test "build/3 links each page to its source file on GitHub, on its tag or branch", ctx do
    source = %{@source | refs: ["refs/heads/v2.0-wip", "refs/tags/v1.0"]}
    write!(ctx.sources_dir, "netex-fr/heads/v2.0-wip/README.md", "# NeTEx")
    SiteDeNormes.build(ctx.output_dir, ctx.sources_dir, [source])

    assert read!(ctx.output_dir, "profils/netex-fr/v1.0/NeTEx/arrets/index.html")
           |> query(~s(a[href*="github.com"]))
           |> attribute("href") == [
             "https://github.com/etalab/transport-profil-netex-fr/blob/v1.0/NeTEx/arrets/index.md"
           ]

    assert read!(ctx.output_dir, "profils/netex-fr/v2.0-wip/index.html")
           |> query(~s(a[href*="github.com"]))
           |> attribute("href") == [
             "https://github.com/etalab/transport-profil-netex-fr/blob/v2.0-wip/README.md"
           ]
  end

  test "build/3 raises if a version wasn't fetched", ctx do
    source = %{@source | refs: ["refs/tags/v2.0"]}

    assert_raise RuntimeError, ~r/run `mix site.fetch` first/, fn ->
      SiteDeNormes.build(ctx.output_dir, ctx.sources_dir, [source])
    end
  end

  # Beta: must not be indexed
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
