defmodule Tesseract.ECS.EntityTest do
  alias Tesseract.ECS.Entity

  use ExUnit.Case, async: true

  test "[ECS.Entity] Correctly initializes." do
    {:ok, _} = Entity.start_link(label: make_ref(), components: [])
  end

  test "[ECS.Entity] Accepts a list of components." do
    entity_cfg =
      Entity.make_cfg(
        make_ref(),
        components: [
          health: 100,
          weapon: %{type: :sword}
        ]
      )

    {:ok, _} = Entity.start_link(entity_cfg)
  end
end
