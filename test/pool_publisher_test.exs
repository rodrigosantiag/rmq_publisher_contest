defmodule RmqPublisherContest.PoolPublisherTest do
  use ExUnit.Case, async: false
  use Mimic

  alias RmqPublisherContest.PoolPublisher
  alias RmqPublisherContest.ConnectionWorker

  setup :verify_on_exit!
  setup :set_mimic_global

  setup do
    stub(Supervisor, :start_link, fn _children, _opts ->
      {:ok, spawn(fn -> Process.sleep(1000) end)}
    end)

    stub(:poolboy, :transaction, fn _pool_name, fun, _timeout ->
      worker_pid = spawn(fn -> :ok end)
      fun.(worker_pid)
    end)

    stub(:poolboy, :child_spec, fn _name, _pool_opts, _worker_opts ->
      %{
        id: :poolboy,
        start: {:poolboy, :start_link, [[]]},
        type: :worker,
        restart: :permanent,
        shutdown: 5000
      }
    end)

    :ok
  end

  describe "initialization" do
    test "starts with default pool size" do
      {:ok, _pid} = PoolPublisher.start_link(rabbit_url: "amqp://guest:guest@localhost")
    end

    test "starts with custom pool size" do
      {:ok, _pid} = PoolPublisher.start_link(rabbit_url: "amqp://guest:guest@localhost", pool_size: 10)
    end
  end

  describe "publish" do
    test "successfully publishes message" do
      stub(ConnectionWorker, :get_channel, fn _worker_pid ->
        {:ok, %{pid: self()}}
      end)

      expect(AMQP.Basic, :publish, fn _ch, "test_exchange", "test_key", "test_payload", _opts -> :ok end)

      {:ok, _pid} = PoolPublisher.start_link(rabbit_url: "amqp://guest:guest@localhost")

      assert :ok = PoolPublisher.publish("test_exchange", "test_key", "test_payload")
    end

    test "should respect provided persistent option" do
      stub(ConnectionWorker, :get_channel, fn _worker_pid ->
        {:ok, %{pid: self()}}
      end)

      expect(AMQP.Basic, :publish, fn _ch, "test_exchange", "test_key", "test_payload", opts ->
        assert Keyword.get(opts, :persistent) == false
        :ok
      end)

      {:ok, _pid} = PoolPublisher.start_link(rabbit_url: "amqp://guest:guest@localhost")

      PoolPublisher.publish("test_exchange", "test_key", "test_payload", [persistent: false])
    end

    test "adds persistent option by default" do
      stub(ConnectionWorker, :get_channel, fn _worker_pid ->
        {:ok, %{pid: self()}}
      end)

      expect(AMQP.Basic, :publish, fn _ch, "test_exchange", "test_key", "test_payload", opts ->
        assert Keyword.get(opts, :persistent) == true
        :ok
      end)

      {:ok, _pid} = PoolPublisher.start_link(rabbit_url: "amqp://guest:guest@localhost")

      PoolPublisher.publish("test_exchange", "test_key", "test_payload")
    end

    test "should handle channel error" do
      stub(ConnectionWorker, :get_channel, fn _worker_pid ->
        {:error, :test_error}
      end)

      {:ok, _pid} = PoolPublisher.start_link(rabbit_url: "amqp://guest:guest@localhost")

      assert {:error, :test_error} = PoolPublisher.publish("test_exchange", "test_key", "test_payload")
    end

    test "should handle poolboy transaction errors" do
      {:ok, _pid} = PoolPublisher.start_link(rabbit_url: "amqp://guest:guest@localhost")

      stub(:poolboy, :transaction, fn _pool_name, _fun, _timeout ->
        exit({:timeout, nil})
      end)

      assert {:error, :timeout} = PoolPublisher.publish("test_exchange", "test_key", "test_payload")
    end
  end
end
