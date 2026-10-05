defmodule SiteDeNormes.GitTest do
  @moduledoc """
  Not a connected test: each test creates a local git repository in its tmp_dir
  and uses it as the "origin" to clone from, so no network access is needed.
  """
  use ExUnit.Case, async: true

  alias SiteDeNormes.Git

  @moduletag :tmp_dir

  # origin: a repository with one commit on main, tagged v1.0. The tag is annotated,
  # like releases usually are, so that the tests check we get the commit it points to.
  setup %{tmp_dir: tmp_dir} do
    origin = Path.join(tmp_dir, "origin")
    File.mkdir_p!(origin)
    run!(origin, ["init", "--quiet", "--initial-branch", "main"])
    commit!(origin, "first")
    run!(origin, ["tag", "--annotate", "v1.0", "--message", "v1.0"])

    %{
      origin: origin,
      clone: Path.join(tmp_dir, "clone.git"),
      dir: Path.join(tmp_dir, "dir")
    }
  end

  describe "sync/2" do
    test "clones the branches and tags of the repository", ctx do
      Git.sync(ctx.origin, ctx.clone)

      assert Git.commit_sha(ctx.clone, "refs/heads/main") == head(ctx.origin)
      assert Git.commit_sha(ctx.clone, "refs/tags/v1.0") == head(ctx.origin)
    end

    test "updates an existing clone with the new commits", ctx do
      Git.sync(ctx.origin, ctx.clone)
      tagged = head(ctx.origin)
      commit!(ctx.origin, "second")

      Git.sync(ctx.origin, ctx.clone)

      assert Git.commit_sha(ctx.clone, "refs/heads/main") == head(ctx.origin)
      assert Git.commit_sha(ctx.clone, "refs/tags/v1.0") == tagged
    end
  end

  describe "commit_sha/2" do
    test "raises on an unknown ref, so that a typo in the config fails the build", ctx do
      Git.sync(ctx.origin, ctx.clone)

      assert_raise RuntimeError, ~r/unknown ref refs\/tags\/v9\.9/, fn ->
        Git.commit_sha(ctx.clone, "refs/tags/v9.9")
      end
    end

    test "raises on a short ref name, which git would resolve by guessing", ctx do
      Git.sync(ctx.origin, ctx.clone)

      assert_raise RuntimeError, ~r/v1\.0 must be fully qualified/, fn ->
        Git.commit_sha(ctx.clone, "v1.0")
      end
    end
  end

  describe "checkout_into/3" do
    test "writes the files of the commit into the directory", ctx do
      commit_file!(ctx.origin, "README.md", "hello")
      Git.sync(ctx.origin, ctx.clone)

      Git.checkout_into(ctx.clone, head(ctx.origin), ctx.dir)

      assert File.read!(Path.join(ctx.dir, "README.md")) == "hello"
    end

    # Happens on each run of `mix site.fetch` after the first one
    test "replaces the previous content of the directory", ctx do
      commit_file!(ctx.origin, "removed.md", "removed upstream")
      Git.sync(ctx.origin, ctx.clone)
      Git.checkout_into(ctx.clone, head(ctx.origin), ctx.dir)
      File.write!(Path.join(ctx.dir, "local.md"), "local change")

      run!(ctx.origin, ["rm", "--quiet", "removed.md"])
      commit_file!(ctx.origin, "added.md", "added upstream")
      Git.sync(ctx.origin, ctx.clone)
      Git.checkout_into(ctx.clone, head(ctx.origin), ctx.dir)

      assert File.exists?(Path.join(ctx.dir, "added.md"))
      refute File.exists?(Path.join(ctx.dir, "removed.md"))
      refute File.exists?(Path.join(ctx.dir, "local.md"))
    end

    # Safety net against a wrong path (e.g. computed from a bad config): never delete it
    test "refuses to replace a directory that isn't one of its worktrees", ctx do
      Git.sync(ctx.origin, ctx.clone)
      File.mkdir_p!(ctx.dir)
      File.write!(Path.join(ctx.dir, "precious.md"), "not ours")

      assert_raise RuntimeError, ~r/failed/, fn ->
        Git.checkout_into(ctx.clone, head(ctx.origin), ctx.dir)
      end

      assert File.read!(Path.join(ctx.dir, "precious.md")) == "not ours"
    end

    # Happens if someone deletes a version directory by hand
    test "recreates a worktree whose directory was deleted", ctx do
      Git.sync(ctx.origin, ctx.clone)
      Git.checkout_into(ctx.clone, head(ctx.origin), ctx.dir)
      # Same as a deletion for git, without deleting anything
      File.rename!(ctx.dir, Path.join(ctx.tmp_dir, "moved-away"))

      Git.checkout_into(ctx.clone, head(ctx.origin), ctx.dir)

      assert File.exists?(Path.join(ctx.dir, ".git"))
    end

    test "refuses a commit containing a symlink, which could expose files outside of the repository",
         ctx do
      secret = Path.join(ctx.tmp_dir, "secret.txt")
      File.write!(secret, "secret")
      File.ln_s!(secret, Path.join(ctx.origin, "leak.md"))
      run!(ctx.origin, ["add", "leak.md"])
      commit!(ctx.origin, "add a symlink to a file outside of the repository")
      Git.sync(ctx.origin, ctx.clone)

      assert_raise RuntimeError, ~r/symlinks are not allowed/, fn ->
        Git.checkout_into(ctx.clone, head(ctx.origin), ctx.dir)
      end

      refute File.exists?(ctx.dir)
    end
  end

  defp head(repo), do: run!(repo, ["rev-parse", "HEAD"]) |> String.trim()

  defp commit!(repo, message),
    do: run!(repo, ["commit", "--quiet", "--allow-empty", "-m", message])

  defp commit_file!(repo, path, content) do
    File.write!(Path.join(repo, path), content)
    run!(repo, ["add", path])
    commit!(repo, "update #{path}")
  end

  # Explicit identity and no signing, so that tests don't depend on the local git config
  defp run!(repo, args) do
    config =
      ~w(-c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false -c tag.gpgsign=false)

    {output, 0} = System.cmd("git", ["-C", repo] ++ config ++ args, stderr_to_stdout: true)
    output
  end
end
