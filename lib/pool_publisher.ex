defmodule RmqPublisherContest.PoolPublisher do
  @moduledoc """
  A module that provides a simple interface for publishing messages to RabbitMQ.
  """

  use GenServer

  require Logger

  alias RmqPublisherContest.ConnectionWorker

  @default_pool_size 5
  @pool_name :rmq_publisher_pool
  @timeout 5000

  # Client API

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def publish(exchange, routing_key, payload, options \\ []) do
    options =
      if Keyword.has_key?(options, :persistent),
        do: options,
        else: Keyword.put(options, :persistent, true)

    try do
      :poolboy.transaction(
        @pool_name,
        fn worker_pid ->
          case ConnectionWorker.get_channel(worker_pid) do
            {:ok, channel} ->
              try do
                AMQP.Basic.publish(channel, exchange, routing_key, payload, options)
              catch
                kind, reason ->
                  Logger.error("Failed to publish message: #{inspect(kind)}, #{inspect(reason)}")
                  {:error, reason}
              end

            {:error, reason} ->
              Logger.error("Failed to get channel: #{inspect(reason)}")
              {:error, reason}
          end
        end,
        @timeout
      )
    catch
      :exit, {:timeout, _} ->
        Logger.error("Poolboy transaction timed out")
        {:error, :timeout}

      :exit, reason ->
        Logger.error("Poolboy transaction failed: #{inspect(reason)}")
        {:error, {:poolboy_error, reason}}

      kind, reason ->
        Logger.error("Unexpected error in publish: #{inspect(kind)}, #{inspect(reason)}")
        {:error, {kind, reason}}
    end
  end

  # Server callbacks

  @impl true
  def init(opts) do
    rabbit_url = Keyword.fetch!(opts, :rabbit_url)
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)

    pool_opts = [
      name: {:local, @pool_name},
      worker_module: ConnectionWorker,
      size: pool_size,
      max_overflow: 0,
      strategy: :fifo,
      overflow_ttl: 1000
    ]

    worker_opts = [
      rabbit_url: rabbit_url
    ]

    children = [
      :poolboy.child_spec(@pool_name, pool_opts, worker_opts)
    ]

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)

    Logger.info("Publisher started with pool size: #{pool_size}")

    {:ok, %{pool_size: pool_size}}

  end
end
