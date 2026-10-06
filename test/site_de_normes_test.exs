defmodule SiteDeNormesTest do
  use ExUnit.Case, async: true

  import LazyHTML, only: [from_document: 1, query: 2, text: 1, attribute: 2]

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    SiteDeNormes.build(tmp_dir)
    %{page: tmp_dir |> Path.join("index.html") |> File.read!() |> from_document()}
  end

  test "build/1 writes an index.html", %{page: page} do
    assert page |> query("h1") |> text() == "Site en construction"
  end

  test "build/1 writes pages using the DSFR, with a beta banner, not to be indexed",
       %{page: page} do
    assert [href] = page |> query(~s(link[rel="stylesheet"])) |> attribute("href")
    assert href =~ "dsfr.min.css"
    assert page |> query(".fr-notice__title") |> text() == "Version bêta"
    assert page |> query(~s(meta[name="robots"])) |> attribute("content") == ["noindex, nofollow"]
  end

  test "build/1 writes a robots.txt disallowing all crawling", %{tmp_dir: tmp_dir} do
    assert File.read!(Path.join(tmp_dir, "robots.txt")) == "User-agent: *\nDisallow: /\n"
  end
end
