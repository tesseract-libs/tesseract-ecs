# defmodule Tesseract.ECS.System.Health do
#   alias Tesseract.Timeline
  
#   @behaviour Tesseract.ECS.System

#   def process_action({:take_damage, _, params}, components, entity_state) do
#     damage = params |> Keyword.fetch!(:damage)
#     current_health = components[:health] |> Timeline.get(0, 0)
#     new_health_state = components[:health] |> Timeline.set(current_health - damage, 0, 0)

#     %{components | health: new_health_state}
#   end
# end