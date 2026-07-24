defmodule Alva.MixProject do
  use Mix.Project

  def project do
    [
      app: :alva,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      name: "Alva",
      source_url: "https://github.com/hopewithoute/alva",
      homepage_url: "https://hex.pm/packages/alva",
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      test_coverage: [tool: ExCoveralls],
      docs: &docs/0
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "Alva",
      extras: [
        "README.md",
        "guides/01-getting-started.md",
        "guides/02-ash-backend-setup.md",
        "guides/03-liveview-integration.md",
        "guides/04-queries-and-actions.md",
        "guides/05-forms-and-mutations.md",
        "guides/06-frontend-composables.md",
        "guides/07-uploads.md",
        "guides/08-streams.md",
        "guides/09-signals.md"
      ],
      extra_section: "GUIDES",
      groups_for_modules: [
        "Core",
        ~r/^Alva\.(Resource|LiveView|Dispatcher|Serializer|Result|Error|Test)$/,
        "Codegen",
        ~r/^Alva\.Codegen\./,
        "Introspection",
        ~r/^Alva\.(Registry|Domain)(\.|$)/
      ],
      groups_for_extras: [
        "Getting Started",
        ~r/^guides\/01-/,
        "Core Concepts",
        ~r/^guides\/0[2-5]-/,
        "Advanced",
        ~r/^guides\/0[6-9]-/
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sourceror, "~> 1.7", only: [:dev, :test]},
      {:picosat_elixir, "~> 0.2", only: [:dev, :test]},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
