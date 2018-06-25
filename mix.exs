defmodule TesseractEcs.MixProject do
  use Mix.Project

  def project do
    [
      app: :tesseract_ecs,
      version: "0.1.7",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/tesseract-libs/tesseract-ecs",
      homepage_url: "http://tesseract.games"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:gproc, "~> 0.6.1"},
      {:tesseract_ext, "~> 0.1.2"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description() do
    "Simple entity-component system implemented in Elixir."
  end

  defp package() do
    [
      name: "tesseract_ecs",
      maintainers: ["Urban Soban"],
      licenses: ["MIT"],
      links: %{
        "github" => "https://github.com/tesseract-libs/tesseract-ecs",
        "tesseract.games" => "http://tesseract.games"
      },
      organisation: "tesseract",
      files: ["lib", "test", "config", "mix.exs", "README*", "LICENSE*"]
    ]
  end
end
