defmodule HttpCookie.MixProject do
  use Mix.Project

  @version "0.8.0"
  @source_url "https://github.com/reisub/http_cookie"

  def project do
    [
      app: :http_cookie,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
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

  defp description do
    "Standards-compliant HTTP Cookie implementation."
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/http_cookie/changelog.html"
      },
      exclude_patterns: ~w[priv/plts]
    ]
  end

  defp deps do
    [
      {:idna, "~> 6.1"},
      {:public_sufx, "~> 0.5.0"},
      {:nimble_parsec, "~> 1.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:req, "~> 0.5.0", optional: true},
      {:plug, "~> 1.0", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0", only: [:dev, :test]},
      {:doctor, "~> 0.22.0", only: [:dev, :test]}
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

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end
end
