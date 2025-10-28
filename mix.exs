defmodule Calque.MixProject do
  use Mix.Project

  def project do
    [
      app: :calque,
      version: "1.3.0",
      elixir: "~> 1.15",
      description:
        "A simple snapshot testing library inspired by Birdie (Gleam) and Insta (Rust).",
      package: package(),
      deps: deps(),
      source_url: "https://github.com/milaneuh/calque",
      docs: [
        main: "Calque",
        source_url: "https://github.com/milaneuh/calque",
        extras: ["README.md", "LICENSE"]
      ]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Milan Rougemont"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/milaneuh/calque"}
    ]
  end
end
