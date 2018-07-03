defmodule Tesseract.ECS.SystemTest do
  alias Tesseract.ECS.{System, Scene}
  alias Tesseract.ECS.Scene.Supervisor, as: SceneSupervisor

  use ExUnit.Case, async: true

  defmodule TestState do
    use Agent

    def via(label) do
      {:via, :gproc, {:n, :l, {:test_ping, label}}}
    end

    def start_link(label) do
      Agent.start_link(fn -> %{} end, name: via(label))
    end
  end

  defmodule TestSystem do
    @behaviour System

    def make_cfg() do
      System.make_cfg(
        make_ref(),
        f: __MODULE__,
        components: [:test],
        actions: []
      )
    end

    def init_specs(scene_ref) do
      [{TestState, scene_ref}]
    end

    def process_action(_, _, _), do: nil
  end

  test "[ECS.System] init_specs/1 can return list of tuples which are scene supervisor child specs; processes for these specs are spawned.." do
    sys = TestSystem.make_cfg()
    scene = Scene.make_cfg(make_ref(), systems: [sys])
    {:ok, _} = SceneSupervisor.start_link(scene)

    {:via, _, state_via} = TestState.via(scene.label)
    state_pid = :gproc.where(state_via)
    assert state_pid !== :undefined
  end

  # setup do
  #   rand_id = :rand.uniform(1000000)

  #   {:ok, %{game_id: "game_#{rand_id}"}}
  # end

  # test "[ECS.System] Correctly initializes.", %{game_id: game_id} do
  #   assert {:ok, _} = System.start_link(game_id, "test")
  # end

  # test "[ECS.System] Initialize system with components.", %{game_id: game_id} do
  #   sys_cfg = %System{components: [
  #     a: %Component{f: nil, name: :a, actions: [:clock_tick]}
  #   ]}

  #   assert {:ok, _} = System.start_link(game_id, :test, sys_cfg)
  # end

  # test "[ECS.System] Keeps track of registered entities per-component.", %{game_id: game_id} do
  #   health_component = Component.Health.make_cfg()
  #   weapon_component = Component.Weapon.make_cfg()

  #   entities = [
  #     e1 = make_entity(game_id, [health: health_component, weapon: weapon_component]),
  #     e2 = make_entity(game_id, [weapon: weapon_component]),
  #     e3 = make_entity(game_id, [health: health_component, weapon: weapon_component])
  #   ]

  #   sys_cfg = [components: [health: health_component, weapon: weapon_component]]

  #   {:ok, _} = System.start_link(game_id, :test, sys_cfg)

  #   entities
  #   |> Enum.each(fn %Entity{} = e -> 
  #     e.components
  #     |> Enum.each(fn {component_name, %Component{}} -> 
  #       System.register_entity_component(game_id, :test, e.label, component_name)
  #     end)
  #   end)

  #   health_component_entities = System.get_registered_component_entities(game_id, :test, :health)
  #   weapon_component_entities = System.get_registered_component_entities(game_id, :test, :weapon)

  #   assert MapSet.new([e1.label, e3.label]) == MapSet.new(health_component_entities)
  #   assert MapSet.new([e1.label, e2.label, e3.label]) == MapSet.new(weapon_component_entities)
  # end

  # defp make_entity(game_id, components) do
  #   Entity.make_config(game_id, :rand.uniform(100000000), %{components: components})
  # end
end
