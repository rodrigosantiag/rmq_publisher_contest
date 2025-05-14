defmodule RmqPublisherContest.ConnectionWorkerTest do
  use ExUnit.Case, async: false
  use Mimic

  alias RmqPublisherContest.ConnectionWorker

  setup :verify_on_exit!
  setup :set_mimic_global

  describe "initialization" do
    test "should fail with empty rabbit_url" do
      assert {:error, _} = ConnectionWorker.start_link(rabbit_url: "")
    end

    test "should fail with nil rabbit_url" do
      assert {:error, _} = ConnectionWorker.start_link(rabbit_url: nil)
    end
  end

  describe "connection" do
    test "connects successfully" do
      expect(AMQP.Connection, :open, fn _url ->
        {:ok, %{pid: self()}}
      end)

      expect(AMQP.Channel, :open, fn _conn ->
        {:ok, %{pid: self()}}
      end)

      expect(AMQP.Confirm, :select, fn _channel ->
        :ok
      end)

      {:ok, pid} = ConnectionWorker.start_link(rabbit_url: "amqp://guest:guest@localhost")

      # Give it time to connect
      Process.sleep(500)

      assert {:ok, _channel} = ConnectionWorker.get_channel(pid)

      GenServer.stop(pid)
    end

    test "should handle connection failure" do
      expect(AMQP.Connection, :open, fn _ -> {:error, :connection_failure} end)

      {:ok, pid} = ConnectionWorker.start_link(rabbit_url: "amqp://guest:guest@localhost")
      Process.sleep(100)

      assert {:error, :not_connected} = ConnectionWorker.get_channel(pid)
    end
  end

  describe "cleanup" do
    test "closes channel and connection on termination" do
      expect(AMQP.Connection, :open, fn _ -> {:ok, %{pid: self()}} end)
      expect(AMQP.Channel, :open, fn _ -> {:ok, %{pid: self()}} end)
      expect(AMQP.Confirm, :select, fn _ -> :ok end)
      expect(AMQP.Channel, :close, fn _ -> :ok end)
      expect(AMQP.Connection, :close, fn _ -> :ok end)

      {:ok, pid} = ConnectionWorker.start_link(rabbit_url: "amqp://guest:guest@localhost")
      Process.sleep(100)

      GenServer.stop(pid)
    end
  end
end
