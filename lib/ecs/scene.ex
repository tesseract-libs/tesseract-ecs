defmodule Tesseract.ECS.Scene do
  alias Tesseract.ECS.{Entity, System}

  defstruct label: nil,
            game_id: nil,
            systems: [],
            entities: %{},
            systems_by_action: %{}

  use GenServer
  use Tesseract.Ext.MapLike, for: Tesseract.ECS.Scene

  # TODO: move into EnumExt!!
  def group_multiple_by(enum, keys_fn, value_fn \\ fn x -> x end) do
    enum
    |> Enum.reduce(%{}, fn (e, result) -> 
      keys_fn.(e)
      |> Enum.reduce(result, fn k, result -> 
        group = result |> Map.get(k, [])
        Map.put(result, k, [value_fn.(e) | group])
      end)
    end)
  end

  def via_tuple(label) do
    {:via, :gproc, {:n, :l, {:scene, label}}}
  end

  # =======================
  # == Client interface. ==
  # =======================
  def start_link(label, params \\ []) do
    params =
      params
      |> Enum.into(%__MODULE__{})
      |> Map.put(:label, label)

    {:ok, _} = GenServer.start_link(__MODULE__, params, name: via_tuple(label))
  end

  # TODO: remove.
  def get_state(label) do
    GenServer.call(via_tuple(label), :get_state)
  end

  def get_entities(label) do
    GenServer.call(via_tuple(label), :get_entities)
  end

  def dispatch(label, receiver, {_, _, _} = action) do
    GenServer.cast(via_tuple(label), {:dispatch, receiver, action})
  end

  def dispatch(label, {_, _, _} = action) do
    # TODO: broadcast.
  end

  # =============
  # == Server. ==
  # =============
  def init(%__MODULE__{} = state) do
    state = 
      state  
      |> init_entities
      |> index_system_actions()

    {:ok, state}
  end

  def handle_call(:get_state, _from, %__MODULE__{} = state) do
    {:reply, state, state}
  end

  def handle_call(:get_systems, _from, %__MODULE__{systems: systems} = state) do
    {:reply, systems, state}
  end

  def handle_call(:get_entities, _from, %__MODULE__{entities: entities} = state) do
    {:reply, entities, state}
  end

  def handle_cast({:dispatch, receiver, {action_name, _, _} = action}, %__MODULE__{} = state) do
    receiver_entity = state.entities |> Map.fetch!(receiver)
    
    state.systems_by_action
    |> Map.get(action_name, [])
    |> Enum.map(&Enum.find(state.systems, nil, fn sys -> sys.label == &1 end))
    |> Enum.filter(fn sys -> Entity.has_components?(receiver_entity, sys.components) end)
    |> Enum.each(&Entity.process(receiver, action, &1))

    {:noreply, state}
  end

  # TODO: refactor; dynamic supervisor!!
  defp init_entities(%__MODULE__{game_id: game_id} = state) do
    entities =
      state.entities
      |> Enum.reduce(%{}, fn %Entity{} = entity_cfg, entities -> 
        entity_cfg = entity_cfg |> Map.put(:game_id, game_id)
        entity_cfg = Entity.make_cfg(entity_cfg.label, entity_cfg)

        {:ok, _} = Entity.start_link(entity_cfg.label, entity_cfg)

        entities |> Map.put(entity_cfg.label, entity_cfg)
      end)

    %{state | entities: entities}
  end

  defp index_system_actions(%__MODULE__{systems: systems} = state) do
    sys_actions =  fn %System{} = sys -> sys.actions end
    sys_label = fn %System{} = sys -> sys.label end

    multi_grouped = group_multiple_by(systems, sys_actions, sys_label)
    %{state | systems_by_action: multi_grouped}
  end
end