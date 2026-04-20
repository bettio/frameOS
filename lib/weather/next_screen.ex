# SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
# SPDX-License-Identifier: Apache-2.0

defmodule UI.Weather.NextScreen do
  # Focusable widget for view-cycling and the blank gesture.
  @enforce_keys [:name]
  defstruct [
    :name,
    :x,
    :y,
    :width,
    :height,
    label: ">",
    color: 0x000000,
    bgcolor: 0xFFFFFF,
    # Focusable but draws nothing.
    invisible: false
  ]

  def can_be_focused?(_widget, _ui_state), do: true
  def accepts_mouse_events(_widget, _ui_state), do: true
  def state_struct_module(), do: UI.Weather.NextScreenState

  def render(%__MODULE__{invisible: true}, _name, _ui_state, _origin_x, _origin_y, acc), do: acc

  def render(widget, _name, _ui_state, origin_x, origin_y, acc) do
    %__MODULE__{x: x, y: y, label: label, color: color, bgcolor: bgcolor} = widget
    [{:text, origin_x + x, origin_y + y, :font_h1, color, bgcolor, label} | acc]
  end
end

defmodule UI.Weather.NextScreenState do
  defstruct []

  def handle_input(state, {:keyboard, :down, code}, _ts) when code in [10, 13] do
    {state, [event: :next]}
  end

  def handle_input(state, {:keyboard, :down, ?w}, _ts) do
    {state, [event: :white_screen]}
  end

  def handle_input(state, {:mouse, :released, :left, _x, _y}, _ts) do
    {state, [event: :next]}
  end

  def handle_input(_state, _event, _ts), do: :none
end
