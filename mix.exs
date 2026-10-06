defmodule SiteDeNormes.MixProject do
  use Mix.Project

  def project do
    [
      app: :site_de_normes,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mdex, "~> 0.14"},
      {:lumis, "~> 0.10"},
      {:lumis_wasm_yaml, "~> 0.26"},
      {:phoenix_live_view, "~> 1.2"},
      {:lazy_html, "~> 0.1", only: :test}
    ]
  end
end
