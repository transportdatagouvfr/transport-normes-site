defmodule SiteDeNormesTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "build/1 writes an index.html", %{tmp_dir: tmp_dir} do
    SiteDeNormes.build(tmp_dir)

    assert File.read!(Path.join(tmp_dir, "index.html")) =~ "Hello world"
  end

  @tag :tmp_dir
  test "build/1 writes a robots.txt disallowing all crawling", %{tmp_dir: tmp_dir} do
    SiteDeNormes.build(tmp_dir)

    assert File.read!(Path.join(tmp_dir, "robots.txt")) == "User-agent: *\nDisallow: /\n"
  end
end
