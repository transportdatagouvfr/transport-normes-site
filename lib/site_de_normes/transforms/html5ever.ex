defmodule SiteDeNormes.Transforms.Html5ever do
  @moduledoc """
  Utilities for handling HTML5Ers parser artifacts.

  The html5ever parser (used by MDEx/Comrak) wraps fragment-level HTML in a
  full document skeleton: `<html><head></head><body>...</body></html>`. This
  module provides helpers to strip that wrapper and extract fragment content.

  ## Usage

  After parsing with `Floki.parse_fragment!/1`, call `strip_wrapper/1` on the
  result of `Floki.raw_html/1`:

      html = parsed |> Floki.raw_html() |> Html5ever.strip_wrapper()

  This replaces both the regex-based wrapper stripping and the manual `<body>`
  extraction that was duplicated across transforms.
  """

  @doc """
  Strips the `<html><head></head><body>...</body></html>` wrapper added by
  html5ever, returning the inner fragment content.

  Uses `Floki.filter/2` to find and extract `<body>` children rather than
  regex matching, making it robust against attribute variations on the
  `<html>` tag.


  """
  @spec strip_wrapper(String.t()) :: String.t()
  def strip_wrapper("") do
    ""
  end

  def strip_wrapper(html) do
    parsed = Floki.parse_fragment!(html)

    case parsed do
      [{"html", _, children}] ->
        # html5ever wrapper found — extract <body> children as raw HTML
        case Enum.find(children, fn {tag, _, _} -> tag == "body" end) do
          # malformed, return as-is
          nil ->
            html

          {"body", _, body_children} ->
            Floki.raw_html(body_children)
        end

      _ ->
        # No wrapper — return original (already a clean fragment)
        html
    end
  end
end
