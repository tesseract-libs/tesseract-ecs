defmodule Tesseract.ECS.Entity.Process do
  def get_state(label) do
    GenServer.call(via(label), :get_state)
  end

  def get_component(label, component) do
    GenServer.call(via(label), {:get_component_state, component})
  end

  def process(label, action, system) do
    GenServer.cast(via(label), {:process, action, system})
  end

end