defmodule SiteDeNormes.Git do
  @moduledoc """
  Minimal wrapper around the git command line.

  Each source repository is cloned once as a bare repository (no working copy),
  all its versions are then read from that single clone.
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
    git!(["-C", dir, "rev-parse", "--verify", "--quiet", ref <> "^{commit}"])
    |> String.trim()
  end

  defp refspecs, do: ["+refs/heads/*:refs/heads/*", "+refs/tags/*:refs/tags/*"]

  defp git!(args) do
    # Fail instead of hanging on a credentials prompt (e.g. repository renamed or made private)
    case System.cmd("git", args, stderr_to_stdout: true, env: [{"GIT_TERMINAL_PROMPT", "0"}]) do
      {output, 0} -> output
      {output, status} -> raise "git #{Enum.join(args, " ")} failed (exit #{status})\n#{output}"
    end
  end
end
