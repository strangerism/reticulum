defmodule Ret.RoomAssigner do
  use GenServer

  import Ret.Stats

  def init(state) do
    {:ok, state}
  end

  def get_available_host(existing_host \\ nil) do
    GenServer.call({:global, __MODULE__}, {:get_available_host, existing_host})
  end

  def handle_call({:get_available_host, existing_host}, _pid, state) do
    {:ok, host_to_ccu} = Cachex.get(:janus_load_status, :host_to_ccu)
    is_alive = host_to_ccu |> Keyword.keys() |> Enum.find(&(Atom.to_string(&1) == existing_host)) != nil

    host =
      if is_alive do
        existing_host
      else
        pick_host()
      end

    {:reply, host, state}
  end

  defp pick_host do
    {:ok, host_to_ccu} = Cachex.get(:janus_load_status, :host_to_ccu)

    hosts_by_weight =
      host_to_ccu |> Enum.filter(&(elem(&1, 1) != nil)) |> Enum.map(fn {host, ccu} -> {host, ccu |> weight_for_ccu} end)

    hosts_by_weight |> weighted_sample |> Atom.to_string()
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end

  # Gets the load balancing weight for the given CCU, which is the first entry in
  # the balancer_weights config that the CCU exceeds.
  defp weight_for_ccu(ccu) do
    module_config(:balancer_weights) |> Enum.find(&(ccu >= elem(&1, 0))) |> elem(1) || 1
  end
end
