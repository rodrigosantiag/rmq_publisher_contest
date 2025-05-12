defmodule RmqPublisherContest.MixProject do
  use Mix.Project

  def project do
    [
      app: :rmq_publisher_contest,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 4.0"},
      {:jason, "~> 1.4"},
      {:poolboy, "~> 1.5"},
      {:telemetry, "~> 1.0"}
    ]
  end
end
