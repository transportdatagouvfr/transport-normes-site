defmodule SiteDeNormes.GitTest do
  @moduledoc """
  Not a connected test: each test creates a local git repository in its tmp_dir
  and uses it as the "origin" to clone from, so no network access is needed.
  """
  use ExUnit.Case, async: true

  alias SiteDeNormes.Git

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    origin = Path.join(tmp_dir, "origin")
    File.mkdir_p!(origin)
    run!(origin, ["init", "--quiet", "--initial-branch", "main"])
    commit!(origin, "first")
    run!(origin, ["tag", "--annotate", "v1.0", "--message", "v1.0"])

    %{origin: origin, clone: Path.join(tmp_dir, "clone.git")}
  end

  test "sync/2 clones branches and tags", %{origin: origin, clone: clone} do
    Git.sync(origin, clone)

    assert Git.commit_sha(clone, "refs/heads/main") == head(origin)
    assert Git.commit_sha(clone, "refs/tags/v1.0") == head(origin)
  end

  test "sync/2 on an existing clone fetches new commits", %{origin: origin, clone: clone} do
    Git.sync(origin, clone)
    release = head(origin)
    commit!(origin, "second")
    Git.sync(origin, clone)

    assert Git.commit_sha(clone, "refs/heads/main") == head(origin)
    assert Git.commit_sha(clone, "refs/tags/v1.0") == release
  end

  test "commit_sha/2 raises on an unknown ref", %{origin: origin, clone: clone} do
    Git.sync(origin, clone)

    assert_raise RuntimeError, ~r/failed/, fn -> Git.commit_sha(clone, "refs/tags/v9.9") end
  end

  defp head(repo), do: run!(repo, ["rev-parse", "HEAD"]) |> String.trim()

  defp commit!(repo, message),
    do: run!(repo, ["commit", "--quiet", "--allow-empty", "-m", message])

  # Explicit identity and no signing, so that tests don't depend on the local git config
  defp run!(repo, args) do
    config =
      ~w(-c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false -c tag.gpgsign=false)

    {output, 0} = System.cmd("git", ["-C", repo] ++ config ++ args, stderr_to_stdout: true)
    output
  end
end
