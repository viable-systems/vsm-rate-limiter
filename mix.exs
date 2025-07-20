defmodule VsmRateLimiter.MixProject do
  use Mix.Project

  def project do
    [
      app: :vsm_rate_limiter,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "VSM variety attenuation rate limiter with adapters for ex_rated and hammer",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {VsmRateLimiter.Application, []}
    ]
  end

  defp deps do
    [
      # Rate limiting libraries
      {:ex_rated, "~> 2.1"},
      {:hammer, "~> 6.2"},
      
      # VSM and monitoring
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},
      
      # Config and utilities
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      
      # Dev and test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.1", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/viable-systems/vsm-rate-limiter"
      },
      maintainers: ["Viable Systems"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        "Core": [
          VsmRateLimiter,
          VsmRateLimiter.Core,
          VsmRateLimiter.TokenBucket
        ],
        "Adapters": [
          VsmRateLimiter.Adapters.ExRated,
          VsmRateLimiter.Adapters.Hammer
        ],
        "VSM Integration": [
          VsmRateLimiter.Algedonic,
          VsmRateLimiter.Subsystem,
          VsmRateLimiter.VarietyAttenuation
        ]
      ]
    ]
  end
end
