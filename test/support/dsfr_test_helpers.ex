defmodule DsfrTestHelpers do
  @moduledoc """
  Shared test helpers for DSFR-related tests.

  Provides `is_present?/1` and `texts_of/2` to avoid duplication across
  `test/site_de_normes/dsfr/*_test.exs`.

  Each consuming test should still import LazyHTML explicitly:

      import LazyHTML, only: [from_fragment: 1, query: 2, text: 1]
  """

  @doc """
  Returns `true` when the value represents a non-empty LazyHTML query result.

  Accepts:
  - `%LazyHTML{}` — converts to tree and checks for content
  - `[]` — always false
  - anything else — truthy check (covers maps, strings, etc.)
  """
  def is_present?(%LazyHTML{} = lazy_html) do
    case LazyHTML.to_tree(lazy_html) do
      [] -> false
      _ -> true
    end
  end

  def is_present?([]), do: false
  def is_present?(_), do: true

  @doc """
  Queries CSS selectors and returns a list of text content.

  Accepts either raw HTML (binary) or a LazyHTML fragment as the first argument.
  """
  def texts_of(html, selector) when is_binary(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> Enum.map(&LazyHTML.text/1)
  end

  def texts_of(lazy_html, selector) do
    lazy_html
    |> LazyHTML.query(selector)
    |> Enum.map(&LazyHTML.text/1)
  end
end
