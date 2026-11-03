defmodule SiteDeNormes.PostProcessing.ToC do
  @moduledoc """
  Extracts a table of contents from rendered HTML using Floki.

  Parses the output of `MDEx.to_html!/1`, extracts only h1 and h2 headings
  with their anchor IDs, and builds a nested structure where h2 entries
  are children of the most recent preceding h1.

  ## Example

      iex> SiteDeNormes.PostProcessing.ToC.extract(~s(<h1 id="hello">Hello</h1><h2 id="world">World</h2>))
      [%{id: "hello", text: "Hello", children: [%{id: "world", text: "World", children: []}]}]
  """

  @doc """
  Extracts a TOC tree from rendered HTML.

  Only h1 and h2 headings are included. h3+ are ignored. Orphaned h2s
  (those appearing before any h1) are also ignored.

  ## Parameters

    * `html` — the rendered HTML string from `MDEx.to_html!/1`

  ## Returns

  A list of maps, each representing an h1 entry:

      [
        %{
          id: "section-1",
          text: "Section 1",
          children: [
            %{id: "subsection", text: "Sub section", children: []}
          ]
        }
      ]
  """
  @spec extract(String.t()) :: list(map())
  def extract(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("h1, h2")
    |> Enum.reduce([], &nest/2)
    |> Enum.reverse()
    |> Enum.map(&%{&1 | children: Enum.reverse(&1.children)})
  end

  # Builds the h1 entries in reverse order, each with its h2 children in reverse order.
  # Orphaned h2s (before any h1) are dropped.
  defp nest({"h1", _, _} = h1, roots), do: [entry(h1) | roots]
  defp nest({"h2", _, _}, []), do: []

  defp nest({"h2", _, _} = h2, [parent | roots]),
    do: [%{parent | children: [entry(h2) | parent.children]} | roots]

  defp entry(element) do
    %{
      id: element |> Floki.attribute("id") |> List.first(),
      text: Floki.text(element),
      children: []
    }
  end
end
