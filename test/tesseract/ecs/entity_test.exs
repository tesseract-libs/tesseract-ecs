defmodule Tesseract.ECS.EntityTest do
    alias Tesseract.ECS.Entity
    
    use ExUnit.Case, async: true

    setup do
        {:ok, %{label: :rand.uniform(1000000)}}
    end

    test "[ECS.Entity] Correctly initializes.", %{label: label} do
        {:ok, _} = Entity.start_link(label, [game_id: :rand.uniform(1000000), components: []])
    end

    test "[ECS.Entity] Accepts a list of components.", %{label: label} do
        entity_cfg = [
            components: [
                health: 100,
                weapon: %{type: :sword}
            ],
            game_id: :rand.uniform(100000000)
        ]

        {:ok, _} = Entity.start_link(label, entity_cfg)
    end
end