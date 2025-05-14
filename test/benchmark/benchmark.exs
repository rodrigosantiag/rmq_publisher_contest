defmodule RmqPublisherContest.Benchmark do
  def run(publisher_module, queue_name, message_count \\ 50_000, payload_size \\ 1000, concurrency \\ 50, options \\ []) do
    # Generate test payload
    payload = generate_payload(payload_size)

    opts_str = inspect(options)
    IO.puts("Starting benchmark: #{message_count} messages, size #{payload_size} bytes, concurrency #{concurrency}, options #{opts_str}")

    # Run the test
    {time_micro, _} = :timer.tc(fn ->
      1..message_count
      |> Task.async_stream(
        fn _ ->
          publisher_module.publish("", queue_name, payload, options)  # Pass options here
        end,
        max_concurrency: concurrency,
        ordered: false
      )
      |> Stream.run()
    end)

    # Calculate and print results
    time_sec = time_micro / 1_000_000
    throughput = message_count / time_sec

    IO.puts("Completed in #{Float.round(time_sec, 3)} seconds")
    IO.puts("Throughput: #{Float.round(throughput, 2)} messages/second")

    IO.inspect(%{
      messages: message_count,
      payload_size: payload_size,
      concurrency: concurrency,
      options: options,
      time_seconds: time_sec,
      throughput: throughput
    }, label: "Benchmark Results")
  end

  defp generate_payload(size) do
    # Simple payload generation
    data = :crypto.strong_rand_bytes(size - 50) |> Base.encode64
    Jason.encode!(%{"data" => data, "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()})
  end
end

Application.ensure_all_started(:rmq_publisher_contest)

case Process.whereis(RmqPublisherContest.Publisher) do
  nil ->
    # Start the publisher with default settings
    rabbit_url = "rabbit_mq_connection_string"
    {:ok, _} = RmqPublisherContest.Publisher.start_link(rabbit_url: rabbit_url)
  _ -> :ok
end

case Process.whereis(RmqPublisherContest.PoolPublisher) do
  nil ->
    # Start the pool publisher with default settings
    rabbit_url ="rabbit_mq_connection_string"
    {:ok, _} = RmqPublisherContest.PoolPublisher.start_link(rabbit_url: rabbit_url)
  _ -> :ok
end

# Wait a moment for connections to establish
Process.sleep(1000)

IO.puts("\n=== Single-Connection Publisher ===\n")
RmqPublisherContest.Benchmark.run(
  RmqPublisherContest.Publisher,
  "queue_name"
)

IO.puts("\n=== Connection-Pool Publisher ===\n")
RmqPublisherContest.Benchmark.run(
  RmqPublisherContest.PoolPublisher,
  "queue_name"
)
