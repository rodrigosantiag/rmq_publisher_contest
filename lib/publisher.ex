defmodule Publisher do
  @moduledoc """
  A module that provides a simple interface for publishing messages to RabbitMQ.
  """

  use GenServer

  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def publish(exchange, routing_key, payload, options \\ []) do
    # TODO: implement this considering using poolboy
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # TODO: with the connection worker, we can use the connection pool
  end
end
