defmodule Tesseract.ECS.SceneTest do
  alias Tesseract.ECS.{Entity, Scene, System}
  alias Tesseract.ECS.Scene.Supervisor, as: SceneSupervisor

  use ExUnit.Case, async: true

  defmodule HealthSys do
    @behaviour Tesseract.ECS.System

    def init_specs(_), do: []

    def make_cfg() do
      System.make_cfg(
        make_ref(),
        f: __MODULE__,
        actions: [:take_damage],
        components: [:health, :shield]
      )
    end

    def process_action({:take_damage, _, params}, components, _) do
      %{components | health: components[:health] - params[:damage]}
    end
  end

  defmodule WeaponSys do
    @behaviour Tesseract.ECS.System

    def make_cfg() do
      System.make_cfg(
        make_ref(),
        f: __MODULE__,
        actions: [:fire],
        components: [:weapon]
      )
    end

    def init_specs(_), do: []

    def process_action({_, _, _}, components, _) do
      components
    end
  end

  defmodule SpawnRegistry do
    use Agent

    def via(ref) do
      {:via, :gproc, {:n, :l, {:test_spawn_registry, ref}}}
    end

    def start_link(scene_ref) do
      Agent.start_link(fn -> %{} end, name: via(scene_ref))
    end

    def register(scene_ref, entity_ref) do
      Agent.update(via(scene_ref), &Map.put(&1, entity_ref, true))
    end
  end

  defmodule SpawnSys do
    @behaviour Tesseract.ECS.System

    def make_cfg() do
      System.make_cfg(
        make_ref(),
        f: __MODULE__,
        actions: [:spawn],
        components: [:spawnable]
      )
    end

    def init_specs(scene_ref), do: [{SpawnRegistry, scene_ref}]

    def process_action({:spawn, _, _}, components, %{scene_ref: scene_ref, label: label}) do
      SpawnRegistry.register(scene_ref, label)
      components
    end
  end

  test "[ECS.Scene] Correctly initializes." do
    label = make_ref()

    {:ok, _} = Scene.start_link(label: label)
  end

  test "[ECS.Scene] Correctly initializes with systems." do
    label = make_ref()

    scene =
      Scene.make_cfg(
        label,
        systems: [
          System.make_cfg(:health, f: HealthSys, components: [:health, :shield]),
          System.make_cfg(:weapon, f: WeaponSys, components: [:weapon])
        ]
      )

    {:ok, _} = SceneSupervisor.start_link(scene)

    %{systems: systems} = Scene.get_state(label)

    assert scene[:systems] === systems
  end

  test "[ECS.Scene] Correctly initializes system actions" do
    label = make_ref()

    scene =
      Scene.make_cfg(
        label,
        systems: [
          System.make_cfg(
            :health,
            f: HealthSys,
            components: [:health, :shield],
            actions: [:take_damage]
          ),
          System.make_cfg(:weapon, f: WeaponSys, components: [:weapon], actions: [:fire])
        ]
      )

    {:ok, _} = SceneSupervisor.start_link(scene)

    %{systems_by_action: sba} = Scene.get_state(label)

    assert %{take_damage: [:health], fire: [:weapon]} == sba
  end

  test "[ECS.Scene] Correctly initializes system actions with overlaping actions." do
    label = make_ref()

    scene =
      Scene.make_cfg(
        label,
        systems: [
          System.make_cfg(
            :health,
            f: HealthSys,
            components: [:health, :shield],
            actions: [:take_damage, :foo, :bar]
          ),
          System.make_cfg(:weapon, f: WeaponSys, components: [:weapon], actions: [:fire, :foo])
        ]
      )

    {:ok, _} = SceneSupervisor.start_link(scene)

    %{systems_by_action: sba} = Scene.get_state(label)

    assert %{take_damage: [:health], foo: [:weapon, :health], bar: [:health], fire: [:weapon]} ==
             sba
  end

  test "[ECS.Scene] Spawns an entity if its config was given at startup." do
    label = make_ref()
    entity_label = make_ref()

    scene_cfg =
      Scene.make_cfg(
        label,
        entities: [
          %Entity{label: entity_label, components: [health: 100]}
        ]
      )

    {:ok, _} = SceneSupervisor.start_link(scene_cfg)
  end

  test "[ECS.Scene] Dispatches an action and a system to the addressed entity." do
    label = make_ref()
    entity_cfg = Entity.make_cfg(make_ref(), components: [health: 100])

    health_sys =
      System.make_cfg(:health, f: HealthSys, components: [:health], actions: [:take_damage])

    scene_cfg =
      Scene.make_cfg(
        label,
        systems: [health_sys],
        entities: [entity_cfg]
      )

    {:ok, _} = SceneSupervisor.start_link(scene_cfg)

    {:via, _, entity_via_label} = Entity.via_tuple(entity_cfg.label)
    entity_pid = :gproc.where(entity_via_label)
    assert entity_pid !== :undefined
    :erlang.trace(entity_pid, true, [:receive])

    action = {:take_damage, nil, [damage: 50]}
    Scene.dispatch(label, entity_cfg.label, action)

    assert_receive {:trace, ^entity_pid, :receive, {_, {:process, ^action, ^health_sys}}}

    entity_state = Entity.get_state(entity_cfg.label)

    assert 50 == entity_state.components[:health]
  end

  test "[ECS.Scene] Can add an entity." do
    scene_ref = make_ref()
    entity_cfg = %Entity{label: make_ref(), components: [health: 100]}

    {:ok, _} =
      SceneSupervisor.start_link(
        Scene.make_cfg(
          scene_ref,
          systems: [],
          entities: [entity_cfg]
        )
      )

    scene_entities = Scene.get_entities(scene_ref)
    assert entity_cfg.label === Map.fetch!(scene_entities, entity_cfg.label).label

    new_entity_cfg = Entity.make_cfg(label: make_ref(), components: [health: 90])
    Scene.add_entity(scene_ref, new_entity_cfg)

    scene_entities = Scene.get_entities(scene_ref)
    assert entity_cfg.label === Map.fetch!(scene_entities, entity_cfg.label).label
    assert new_entity_cfg.label === Map.fetch!(scene_entities, new_entity_cfg.label).label
  end

  test "[ECS.Scene] {:spawn, _, _} action is dispatched to a newly started entity." do
    scene_ref = make_ref()

    entity_cfg =
      Entity.make_cfg(
        make_ref(),
        label: make_ref(),
        components: [
          spawnable: true
        ]
      )

    scene_cfg = Scene.make_cfg(scene_ref, systems: [SpawnSys.make_cfg()])
    {:ok, _} = SceneSupervisor.start_link(scene_cfg)
    :ok = Scene.add_entity(scene_ref, entity_cfg)

    assert 1 === Enum.count(Scene.get_entities(scene_ref))

    spawn_registry = Agent.get(SpawnRegistry.via(scene_ref), fn s -> s end)
    assert 1 === Enum.count(spawn_registry)
  end
end
