defmodule SiteDeNormes.Git do
  @moduledoc """
  Minimal wrapper around the git command line.

  Each source repository is cloned once as a bare repository (no working copy),
  each version is then checked out from that single clone as a worktree.
  """

  @doc "Clones `url` as a bare repository into `dir`, or updates all its branches and tags."
  def sync(url, dir) do
    if File.dir?(dir) do
      git!(["-C", dir, "fetch", "--quiet", "--prune", "origin"] ++ refspecs())
    else
      git!(["clone", "--bare", "--quiet", url, dir])
    end

    :ok
  end

  @doc """
  Returns the commit SHA `ref` points to (annotated tags are peeled).

  Raises if `ref` doesn't exist.
  """
  def commit_sha(dir, ref) do
    case git(["-C", dir, "rev-parse", "--verify", "--quiet", ref <> "^{commit}"]) do
      {sha, 0} -> String.trim(sha)
      _ -> raise "unknown ref #{ref} in #{dir}"
    end
  end

  @doc """
  Writes the files of commit `sha` of the bare repository `repo` into `dir`, as a
  detached worktree. If `dir` is already a worktree of `repo`, it is replaced.

  Raises if the commit contains symlinks (git mode 120000): they could point outside
  of the repository (e.g. `~/.ssh` or CI secrets) and get published.

  Raises if `dir` exists but isn't a worktree of `repo`: it is never deleted then.
  """
  def checkout_into(repo, sha, dir) do
    if git!(["-C", repo, "ls-tree", "-r", sha]) =~ ~r/^120000 /m do
      raise "symlinks are not allowed (commit #{sha}), run `git ls-tree -r #{sha}` to find them"
    end

    # Absolute, as git would otherwise resolve it relative to `repo`
    dir = Path.expand(dir)

    # Start from scratch, so that `dir` holds exactly the files of `sha` (no leftovers
    # from a previous version, no local changes). Deleting through git rather than with
    # File.rm_rf! is a safety net: git only deletes a worktree of `repo`, and refuses
    # any other directory (e.g. a wrong path computed from the config).
    if File.exists?(dir), do: git!(["-C", repo, "worktree", "remove", "--force", dir])

    # Forget worktrees whose directory was deleted by hand, otherwise git refuses
    # to create a new one at the same path
    git!(["-C", repo, "worktree", "prune"])

    # This is where `dir` gets its content: git creates it and writes all the files
    # of `sha` into it, read from the bare repository (no network access), plus a
    # `.git` file linking `dir` back to that repository. `--detach`: no local branch
    # is created, `dir` just points at `sha`.
    git!(["-C", repo, "worktree", "add", "--quiet", "--detach", dir, sha])
    :ok
  end

  defp refspecs, do: ["+refs/heads/*:refs/heads/*", "+refs/tags/*:refs/tags/*"]

  defp git!(args) do
    case git(args) do
      {output, 0} -> output
      {output, status} -> raise "git #{Enum.join(args, " ")} failed (exit #{status})\n#{output}"
    end
  end

  # Fail instead of hanging on a credentials prompt (e.g. repository renamed or made private)
  defp git(args),
    do: System.cmd("git", args, stderr_to_stdout: true, env: [{"GIT_TERMINAL_PROMPT", "0"}])
end
