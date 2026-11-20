defmodule SiteDeNormes.Dsfr.Transforms do
  @moduledoc """
  Orchestrates post-processing transforms on HTML content.

  Provides a single parse → strip → transform chain → serialize boundary,
  replacing the previous double-parse pattern where each transform independently
  parsed and serialized the HTML string.

  ## Pipeline

      MDEx.to_html!(doc)
      |> Dsfr.Transforms.transform()
      |> (other non-tree transforms...)

  The pipeline applies transforms in a fixed order:
  1. Parse fragment + strip html5ever wrapper → clean nodes
  2. `Tables.transform_tree/2` — table wrapping
  3. `Figures.transform_tree/1` — figure wrapping
  4. Serialize back to HTML string

  Each transform operates on pure Floki node trees, making them testable in
  isolation while the orchestrator handles the serde boundary.
  """

  @doc """
  Applies all post-processing transforms to an HTML string.

  Parses the fragment, strips the html5ever wrapper, applies each transform
  in sequence, and serializes back to a clean HTML string.
  """
  @spec transform(String.t()) :: String.t()
  def transform(html) when is_binary(html) do
    apply_transform(html, fn tree ->
      tree
      |> SiteDeNormes.Dsfr.Tables.transform_tree()
      |> SiteDeNormes.Dsfr.Figures.transform_tree()
    end)
  end

  def apply_transform(html, transform) do
    html
    |> Floki.parse_fragment!()
    |> transform.()
    |> Floki.raw_html()
  end
end
