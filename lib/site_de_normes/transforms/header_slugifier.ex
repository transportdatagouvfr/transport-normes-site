defmodule SiteDeNormes.Transforms.HeaderSlugifier do
  @moduledoc """
  Header ID generation for GFM-style anchor identifiers.

  Delegates the slugification (lication) to `MDEx.anchorize/1` which
  replicates Comrak's GFM header ID algorithm, then adds deduplication
  on top.

  ## Algorithm

  1. Slugify via `MDEx.anchorize/1` — lowercases, filters allowed characters,
     replaces ASCII spaces with hyphens, strips disallowed characters
  2. Deduplicate by appending `-1`, `-2`, etc. when collisions occur

  ## Unicode categories permitted by Comrak's anchorizer

  - `Ll` — lowercase letter
  - `Lu` — uppercase letter
  - `Lt` — titlecase letter
  - `Lm` — modifier letter
  - `Lo` — other letter (CJK, Arabic, Devanagari, etc.)
  - `Mc` — combining mark (spacing)
  - `Me` — combining mark (enclosing)
  - `Mn` — combining mark (non-spacing)
  - `Nd` — decimal digit number
  - `Nl` — letter number
  - `No` — other number
  - `Pc` — punctuation connector (underscore)
  - `Zs` — space separator

  Everything else is stripped. ASCII spaces become hyphens.

  ## Example

      iex> SiteDeNormes.Transforms.HeaderSlugifier.slugify("Hello World")
      {"hello-world", %{"hello-world" => 1}}

      iex> {slug1, seen} = SiteDeNormes.Transforms.HeaderSlugifier.slugify("C'est la vie!")
      iex> slug1
      "c-est-la-vie"

      iex> {slug2, _seen} = SiteDeNormes.Transforms.HeaderSlugifier.slugify("C'est la vie!", seen)
      iex> slug2
      "c-est-la-vie-1"
  """

  @doc """
  Slugify a heading text and return the resulting ID along with an updated
  seen-set map for deduplication.

  ## Parameters

    * `text` — plain text extracted from heading nodes (no markdown syntax)
    * `seen` — map of already-used slugs to their occurrence count; defaults to `%{}`

  ## Returns

  `{slug, new_seen_map}` where `new_seen_map` includes the newly added slug.
  """
  @spec slugify(String.t(), map()) :: {String.t(), map()}
  def slugify(text, seen \\ %{})

  def slugify("", seen), do: {"", seen}

  def slugify(text, seen) when is_binary(text) do
    raw = MDEx.anchorize(text)
    find_unique(raw, seen)
  end

  # Recursively find a unique slug. If `slug` is already in `seen`, try
  # `slug-N` where N is the next available counter.
  defp find_unique(slug, seen) do
    case Map.fetch(seen, slug) do
      :error ->
        {slug, Map.put(seen, slug, 1)}

      {:ok, count} ->
        candidate = "#{slug}-#{count}"
        find_unique(candidate, Map.put(seen, slug, count + 1))
    end
  end
end
