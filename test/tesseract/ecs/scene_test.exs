defmodule Tesseract.ECS.SceneTest do
  alias Tesseract.ECS.{Entity, Scene, System}
  alias Tesseract.ECS.System.{Health}

  use ExUnit.Case, async: true

  defmodule Health do
    @behaviour Tesseract.ECS.System

    def process_action({:take_damage, _, params}, components, _) do
      %{components | health: components[:health] - params[:damage]}
    end
  end

  setup do
    {:ok, %{
      r_a: :rand.uniform(100000000000),
      r_b: :rand.uniform(100000000000)
    }}
  end

  test "[ECS.Scene] Correctly initializes.", %{r_a: label, r_b: game_id} do
    {:ok, _} = Scene.start_link(label, [game_id: game_id])
  end

  test "[ECS.Scene] Correctly initializes with systems.", %{r_a: label, r_b: game_id} do
    scene = [
      systems: [
        System.make(:health, [f: Health, components: [:health, :shield]]),
        System.make(:weapon, [f: Weapon, components: [:weapon]])
      ],
      game_id: game_id
    ]

    {:ok, _} = Scene.start_link(label, scene)

    %{systems: systems} = Scene.get_state(label)

    assert scene[:systems] === systems
  end

  test "[ECS.Scene] Correctly initializes system actions", %{r_a: label, r_b: game_id} do 
    scene = [
      systems: [
        System.make(:health, [f: Health, components: [:health, :shield], actions: [:take_damage]]),
        System.make(:weapon, [f: Weapon, components: [:weapon], actions: [:fire]])
      ],
      game_id: game_id
    ]

    {:ok, _} = Scene.start_link(label, scene)

    %{systems_by_action: sba} = Scene.get_state(label)

    assert %{take_damage: [:health], fire: [:weapon]} == sba
  end

  test "[ECS.Scene] Correctly initializes system actions with overlaping actions.", %{r_a: label, r_b: game_id} do 
    scene = [
      systems: [
        System.make(:health, [f: Health, components: [:health, :shield], actions: [:take_damage, :foo, :bar]]),
        System.make(:weapon, [f: Weapon, components: [:weapon], actions: [:fire, :foo]])
      ],
      game_id: game_id
    ]

    {:ok, _} = Scene.start_link(label, scene)

    %{systems_by_action: sba} = Scene.get_state(label)

    assert %{
      take_damage: [:health],
      foo: [:weapon, :health], 
      bar: [:health],
      fire: [:weapon]} == sba
  end

  test "[ECS.Scene] Spawns an entity if its config was given at startup.",%{r_a: label, r_b: game_id} do
    entity_label = :rand.uniform(1000000)

    scene_cfg = [
      game_id: game_id,
      entities: [
        %Entity{label: entity_label, components: [health: 100]}
      ]
    ]

    {:ok, _} = Scene.start_link(label, scene_cfg)
  end

  test "[ECS.Scene] Dispatches an action and a system to the addressed entity.",%{r_a: label, r_b: game_id} do
    entity_cfg = %Entity{label: :rand.uniform(1000000), components: [health: 100]}
    health_sys = System.make(:health, [f: Health, components: [:health], actions: [:take_damage]])

    scene_cfg = [
      game_id: game_id,
      systems: [health_sys],
      entities: [entity_cfg]
    ]

    {:ok, _} = Scene.start_link(label, scene_cfg)

    {:via, _, entity_via_label} = Entity.via_tuple(entity_cfg.label)
    entity_pid = :gproc.where(entity_via_label)

    :erlang.trace(entity_pid, true, [:receive])

    action = {:take_damage, nil, [damage: 50]}
    Scene.dispatch(label, entity_cfg.label, action)

    assert_receive {:trace, ^entity_pid, :receive, {_, {:process, ^action, ^health_sys}}}

    entity_state = Entity.get_state(entity_cfg.label)

    assert 50 == entity_state.components[:health]
  end
end