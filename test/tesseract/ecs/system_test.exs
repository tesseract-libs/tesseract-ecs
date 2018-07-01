# defmodule Tesseract.ECS.SystemTest do
#   alias Tesseract.ECS.System
#   alias Tesseract.ECS.Entity
#   alias Tesseract.ECS.Component

#   use ExUnit.Case, async: true

#   setup do
#     rand_id = :rand.uniform(1000000)

#     {:ok, %{game_id: "game_#{rand_id}"}}
#   end

#   test "[ECS.System] Correctly initializes.", %{game_id: game_id} do
#     assert {:ok, _} = System.start_link(game_id, "test")
#   end

#   test "[ECS.System] Initialize system with components.", %{game_id: game_id} do
#     sys_cfg = %System{components: [
#       a: %Component{f: nil, name: :a, actions: [:clock_tick]}
#     ]}

#     assert {:ok, _} = System.start_link(game_id, :test, sys_cfg)
#   end

#   test "[ECS.System] Keeps track of registered entities per-component.", %{game_id: game_id} do
#     health_component = Component.Health.make_cfg()
#     weapon_component = Component.Weapon.make_cfg()

#     entities = [
#       e1 = make_entity(game_id, [health: health_component, weapon: weapon_component]),
#       e2 = make_entity(game_id, [weapon: weapon_component]),
#       e3 = make_entity(game_id, [health: health_component, weapon: weapon_component])
#     ]

#     sys_cfg = [components: [health: health_component, weapon: weapon_component]]

#     {:ok, _} = System.start_link(game_id, :test, sys_cfg)

#     entities
#     |> Enum.each(fn %Entity{} = e -> 
#       e.components
#       |> Enum.each(fn {component_name, %Component{}} -> 
#         System.register_entity_component(game_id, :test, e.label, component_name)
#       end)
#     end)

#     health_component_entities = System.get_registered_component_entities(game_id, :test, :health)
#     weapon_component_entities = System.get_registered_component_entities(game_id, :test, :weapon)

#     assert MapSet.new([e1.label, e3.label]) == MapSet.new(health_component_entities)
#     assert MapSet.new([e1.label, e2.label, e3.label]) == MapSet.new(weapon_component_entities)
#   end

#   defp make_entity(game_id, components) do
#     Entity.make_config(game_id, :rand.uniform(100000000), %{components: components})
#   end
# end
