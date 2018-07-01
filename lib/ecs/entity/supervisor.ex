defmodule Tesseract.ECS.Entity.Supervisor do
  alias Tesseract.ECS.Entity

  use DynamicSupervisor

  def via_tuple(scene_ref) do
    {:via, :gproc, {:n, :l, {:entity_supervisor, scene_ref}}}
  end

  def start_link(scene_ref) do
    DynamicSupervisor.start_link(__MODULE__, [], name: via_tuple(scene_ref))
  end

  def start_child(scene_ref, %Entity{} = entity_cfg) do
    entity_cfg = entity_cfg |> Map.put(:scene_ref, scene_ref)

    spec = %{
      id: entity_cfg.label,
      start: {Entity, :start_link, [entity_cfg.label, entity_cfg]}
    }

    DynamicSupervisor.start_child(via_tuple(scene_ref), spec)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
