defmodule Tesseract.ECS.Scene.Supervisor do
  alias Tesseract.ECS.{Scene, System}

  use Supervisor

  def via_tuple(scene_ref) do
    {:via, :gproc, {:n, :l, {:scene_supervisor, scene_ref}}}
  end

  def start_link(%Scene{} = scene_cfg) do
    Supervisor.start_link(__MODULE__, scene_cfg, name: via_tuple(scene_cfg.label))
  end

  @impl true
  def init(%Scene{} = scene_cfg) do
    scene_ref = scene_cfg.label

    system_children =
      scene_cfg[:systems]
      |> Enum.flat_map(fn %System{} = sys -> sys.f.init_specs(scene_cfg.label) end)

    children = 
      system_children ++ [
        Supervisor.child_spec({Tesseract.ECS.Entity.Supervisor, scene_ref}, type: :supervisor),
        {Tesseract.ECS.Scene, scene_cfg}
      ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
