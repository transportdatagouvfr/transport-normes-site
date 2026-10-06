defmodule SiteDeNormesTest do
  use ExUnit.Case, async: true

  import LazyHTML, only: [from_document: 1, query: 2, text: 1, attribute: 2]

  @moduletag :tmp_dir

  @source %{id: "netex-fr", name: "NeTEx FR", refs: ["refs/tags/v1.0"]}

  # Same layout as written by `mix site.fetch`
  setup %{tmp_dir: tmp_dir} do
    sources_dir = Path.join(tmp_dir, "sources")
    write!(sources_dir, "netex-fr/tags/v1.0/README.md", "# NeTEx")
    write!(sources_dir, "netex-fr/tags/v1.0/NeTEx/arrets/index.md", "# Arrêts\n![](media/a.png)")
    write!(sources_dir, "netex-fr/tags/v1.0/NeTEx/arrets/media/a.png", "PNG")
    write!(sources_dir, "netex-fr/tags/v1.0/.git", "gitdir: /local/path")

    output_dir = Path.join(tmp_dir, "site")
    SiteDeNormes.build(output_dir, sources_dir, [@source])
    %{sources_dir: sources_dir, output_dir: output_dir}
  end

  test "build/3 renders each markdown file, and copies the other files next to it", ctx do
    page = read!(ctx.output_dir, "netex-fr/tags/v1.0/NeTEx/arrets/index.html")

    assert page |> query("h1") |> text() == "Arrêts"
    assert page |> query("img") |> attribute("src") == ["media/a.png"]
    assert File.exists?(Path.join(ctx.output_dir, "netex-fr/tags/v1.0/NeTEx/arrets/media/a.png"))
    refute File.exists?(Path.join(ctx.output_dir, "netex-fr/tags/v1.0/.git"))
  end

  test "build/3 writes a home page linking to each page", ctx do
    assert read!(ctx.output_dir, "index.html") |> query("li a") |> attribute("href") == [
             "netex-fr/tags/v1.0/NeTEx/arrets/index.html",
             "netex-fr/tags/v1.0/README.html"
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
