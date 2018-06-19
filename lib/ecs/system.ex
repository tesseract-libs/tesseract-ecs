defmodule Tesseract.ECS.System do

  @callback process_action(any, any, any) :: any

  use Tesseract.Ext.MapLike, for: Tesseract.ECS.System

  defstruct label: nil,
            f: nil,
            actions: [],
            components: []

  def make(label, params \\ []) do
    params
    |> Enum.into(%__MODULE__{})
    |> Map.put(:label, label)
  end
end