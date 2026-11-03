defmodule SiteDeNormes.Transforms.Navigation do
  @moduledoc """
  MDEx plugin that configures Comrak to generate header IDs without a prefix.

  Sets `header_id_prefix: ""` so that anchor IDs match the heading text directly.
  The actual TOC extraction is handled by `SiteDeNormes.PostProcessing.ToC` as a post-processing step.
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
