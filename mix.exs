defmodule GettextRedact.MixProject do
  use Mix.Project

  def project do
    [
      app: :gettext_redact,
      version: "0.0.0",
      elixir: "~> 1.16",
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
      {:gettext, "~> 0.24"}
    ]
  end
end
