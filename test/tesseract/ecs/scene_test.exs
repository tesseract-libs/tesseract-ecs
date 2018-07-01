defmodule Tesseract.ECS.SceneTest do
  alias Tesseract.ECS.{Entity, Scene, System}
  alias Tesseract.ECS.System.{Health}
  alias Tesseract.ECS.Scene.Supervisor, as: SceneSupervisor

  use ExUnit.Case, async: true

  defmodule Health do
    @behaviour Tesseract.ECS.System

    def process_action({:take_damage, _, params}, components, _) do
      %{components | health: components[:health] - params[:damage]}
    end
  end

  setup do
    {:ok,
     %{
       r_a: make_ref(),
       r_b: make_ref()
     }}
  end

  test "[ECS.Scene] Correctly initializes.", %{r_a: label, r_b: game_id} do
    {:ok, _} = Scene.start_link(label: label, game_id: game_id)
  end

  test "[ECS.Scene] Correctly initializes with systems.", %{r_a: label, r_b: game_id} do
    scene =
      Scene.make(
        label,
        systems: [
          System.make(:health, f: Health, components: [:health, :shield]),
          System.make(:weapon, f: Weapon, components: [:weapon])
        ],
        game_id: game_id
      )

    {:ok, _} = SceneSupervisor.start_link(scene)

    %{systems: systems} = Scene.get_state(label)

    assert scene[:systems] === systems
  end

  test "[ECS.Scene] Correctly initializes system actions", %{r_a: label, r_b: game_id} do
    scene =
      Scene.make(
        label,
        systems: [
          System.make(:health, f: Health, components: [:health, :shield], actions: [:take_damage]),
          System.make(:weapon, f: Weapon, components: [:weapon], actions: [:fire])
        ],
        game_id: game_id
      )

    {:ok, _} = SceneSupervisor.start_link(scene)

    %{systems_by_action: sba} = Scene.get_state(label)

    assert %{take_damage: [:health], fire: [:weapon]} == sba
  end

  test "[ECS.Scene] Correctly initializes system actions with overlaping actions.", %{
    r_a: label,
    r_b: game_id
  } do
    scene =
      Scene.make(
        label,
        systems: [
          System.make(
            :health,
            f: Health,
            components: [:health, :shield],
            actions: [:take_damage, :foo, :bar]
          ),
          System.make(:weapon, f: Weapon, components: [:weapon], actions: [:fire, :foo])
        ],
        game_id: game_id
      )

    {:ok, _} = SceneSupervisor.start_link(scene)

    %{systems_by_action: sba} = Scene.get_state(label)

    assert %{take_damage: [:health], foo: [:weapon, :health], bar: [:health], fire: [:weapon]} ==
             sba
  end

  @tag :kek
  test "[ECS.Scene] Spawns an entity if its config was given at startup.", %{
    r_a: label,
    r_b: game_id
  } do
    entity_label = make_ref()

    scene_cfg =
      Scene.make(
        label,
        game_id: game_id,
        entities: [
          %Entity{label: entity_label, components: [health: 100]}
        ]
      )

    {:ok, _} = SceneSupervisor.start_link(scene_cfg)
  end

  test "[ECS.Scene] Dispatches an action and a system to the addressed entity.", %{
    r_a: label,
    r_b: game_id
  } do
    entity_cfg = Entity.make_cfg(make_ref(), components: [health: 100])
    health_sys = System.make(:health, f: Health, components: [:health], actions: [:take_damage])

    scene_cfg =
      Scene.make(
        label,
        game_id: game_id,
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
        Scene.make(
          scene_ref,
          game_id: make_ref(),
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
end
