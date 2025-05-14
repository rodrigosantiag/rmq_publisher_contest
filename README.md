# RMQ Publisher Contest

I implemented two publishers to find the fastest and most reliable publisher implementation.

## Features

- **Single-Connection Publisher**: Simple publisher with one connection
- **Connection-Pooled Publisher**: More resilient with connection pool
- **Auto-Reconnection**: Both handle connection failures
- **Publisher Confirms**: For reliable message delivery
- **Tests**: Unit tests with Mimic

## Benchmark Results

| Publisher | Messages/sec |
|-----------|--------------|
| Single | ~48000 |
| Pool | ~30000 |

## Implementation

### Single-Connection Publisher

- One connection/channel for all messages
- Good for higher performance
- Auto-reconnects when connection fails

### Connection-Pool Publisher

- Multiple connections for better resilience
- Uses poolboy for connection pool
- Better when reliability is more important
- Can scale with pool size config (on my computer the max pool size was 10. more than that it doesn't work)

### Connection Worker

- Manages individual RabbitMQ connections
- Monitors connection state

## Configuration

In your `config.exs`:

```elixir
config :your_app, :rmq_publisher,
  rabbit_url: "amqp://guest:guest@localhost",
  pool_size: 5
```

## Usage in Your Application
Add both publishers to your application's supervision tree:

```elixir
# In your application.ex
def start(_type, _args) do
  publisher_opts = Application.get_env(:your_app, :rmq_publisher, [])
  
  children = [
    # ... your other children
    {RmqPublisherContest.Publisher, publisher_opts},
    {RmqPublisherContest.PoolPublisher, publisher_opts}
  ]

  opts = [strategy: :one_for_one, name: YourApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

You can also pass options directly when starting the publishers:

```elixir
# For custom options
{RmqPublisherContest.Publisher, [rabbit_url: "amqp://user:pass@rabbitmq.example.com"]}
{RmqPublisherContest.PoolPublisher, [rabbit_url: "amqp://user:pass@rabbitmq.example.com", pool_size: 10]}
```
