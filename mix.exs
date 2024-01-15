defmodule HttpCookie.MixProject do
  use Mix.Project

  def project do
    [
      app: :http_cookie,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer()
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
      {:nimble_parsec, "~> 1.0", optional: true},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      compile_parser: "nimble_parsec.compile lib/http_cookie/date_parser.ex.exs"
    ]
  end

  def dialyzer do
    [
      # Put the project-level PLT in the priv/ directory (instead of the default _build/ location)
      plt_file: {:no_warn, "priv/plts/project.plt"},

      # Also put the core Erlang/Elixir PLT into the priv/ directory like so:
      plt_core_path: "priv/plts/core.plt"
    ]
  end
end
