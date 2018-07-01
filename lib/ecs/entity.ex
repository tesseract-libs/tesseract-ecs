defmodule Tesseract.ECS.Entity do
  alias Tesseract.ECS.System

  defstruct label: nil,
            game_id: nil,
            scene_ref: nil,
            components: %{}

  use Tesseract.Ext.MapLike, for: Tesseract.ECS.Entity
  use Tesseract.Ext.MapAccess
  use GenServer

  def via_tuple(label) do
    {:via, :gproc, {:n, :l, {:entity, label}}}
  end

  def has_components?(%__MODULE__{components: %{} = ec}, cc) do
    ec = MapSet.new(Map.keys(ec))
    cc = MapSet.new(cc)

    cc |> MapSet.subset?(ec)
  end

  def normalize_cfg(%__MODULE__{} = cfg) do
    %{cfg | components: Enum.into(cfg.components, %{})}
  end

  def make_cfg(label, params \\ []) do
    params
    |> Enum.into(%__MODULE__{})
    |> Map.put(:label, label)
    |> normalize_cfg()
  end

  def start_link(label, params \\ []) do
    params = make_cfg(label, params)

    GenServer.start_link(__MODULE__, params, name: via_tuple(label))
  end

  def get_state(label) do
    GenServer.call(via_tuple(label), :get_state)
  end

  def get_component(label, component) do
    GenServer.call(via_tuple(label), {:get_component_state, component})
  end

  def process(label, action, system) do
    GenServer.cast(via_tuple(label), {:process, action, system})
  end

  # ============================
  # == Server implementation. ==
  # ============================
  def init(%__MODULE__{} = state) do
    {:ok, state}
  end

  def handle_call(:get_state, _from, %__MODULE__{} = state) do
    {:reply, state, state}
  end

  def handle_call(
        {:get_component_state, component},
        __from,
        %__MODULE__{components: components} = state
      ) do
    {:reply, Map.fetch(components, component), state}
  end

  def handle_cast({:process, action, %System{} = sys}, %__MODULE__{} = state) do
    components =
      sys.components
      |> Enum.map(fn comp -> {comp, Map.fetch!(state.components, comp)} end)
      |> Enum.into(%{})

    new_components =
      case sys.f.process_action(action, components, state) do
        nil ->
          state.components

        %{} = updates ->
          Map.merge(state.components, updates)

        s ->
          IO.inspect(s)
          raise "Invalid state returned from system.."
      end

    {:noreply, %{state | components: new_components}}
  end
end
