defmodule Tesseract.ECS.System do
  @callback process_action(any, any, any) :: any
  @callback init_specs(any) :: any

  defstruct label: nil,
            f: nil,
            actions: [],
            components: []

  use Tesseract.Ext.MapLike, for: Tesseract.ECS.System

  def make_cfg(label, params \\ []) do
    params
    |> Enum.into(%__MODULE__{})
    |> Map.put(:label, label)
  end
end
