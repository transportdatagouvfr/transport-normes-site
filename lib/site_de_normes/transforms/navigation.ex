defmodule SiteDeNormes.Transforms.Navigation do
  @moduledoc """
  MDEx plugin that enables native Comrak header ID generation.

  Sets `header_id_prefix: ""` so that Comrak generates anchor IDs without any prefix.
  The actual TOC extraction is handled by `SiteDeNormes.ToC` as a post-processing step.
  """

  alias MDEx.Document

  @doc """
  Attaches the header ID generation option to the document.
  """
  @spec attach(Document.t()) :: Document.t()
  def attach(document) do
    document
    |> Document.put_extension_options(header_id_prefix: "")
  end
end
