defmodule HttpCookie.MixProject do
  use Mix.Project

  def project do
    [
      app: :http_cookie,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:idna, "~> 6.1"},
      {:public_suffix, github: "axelson/publicsuffix-elixir"},
      {:nimble_parsec, "~> 1.0", optional: true}
    ]
  end

  defp aliases do
    [
      compile_parser: "nimble_parsec.compile lib/http_cookie/date_parser.ex.exs"
    ]
  end
end
