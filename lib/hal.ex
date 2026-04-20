# SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
# SPDX-License-Identifier: Apache-2.0

defmodule HAL do
  @compile {:no_warn_undefined, :gpio}
  @compile {:no_warn_undefined, :spi}
  @compile {:no_warn_undefined, :buttons}

  @platform Application.compile_env!(:frame_os, :platform)

  def init() do
    init(@platform)
  end

  def init("linux") do
    open_sdl_display()
  end

  def init("reterminal-e1002") do
    {:ok, %{display: display}} = open_spi_display("reterminal-e1002")

    {:ok, buttons} = :buttons.start_link()
    # GPIO 3 (green) + GPIO 4 (right white) → Enter; GPIO 5 (left white) → ?w.
    :ok = :gen_server.call(buttons, {:open, %{3 => 13, 4 => 13, 5 => ?w}})

    {:ok, %{display: Map.put(display, :keyboard_server, [buttons])}}
  end

  defp open_sdl_display do
    display_opts = [
      width: 800,
      height: 480
    ]

    case :erlang.open_port({:spawn, "display"}, display_opts) do
      display when is_port(display) ->
        {:ok,
         %{
           display: %{
             display_server: {:port, display},
             width: display_opts[:width],
             height: display_opts[:height]
           }
         }}

      _ ->
        IO.puts("Failed to open display")
        :error
    end
  end

  defp get_spi_display_opts("reterminal-e1002") do
    [
      width: 800,
      height: 480,
      compatible: "good-display/gdep073e01",
      cs: 10,
      dc: 11,
      reset: 12,
      busy: 13
    ]
  end

  defp open_display_spi_host("reterminal-e1002") do
    spi_opts = %{
      bus_config: %{sclk: 7, mosi: 9, miso: 8, peripheral: "spi2"},
      device_config: %{}
    }

    spi = :spi.open(spi_opts)

    true = :erlang.register(:main_spi, spi)

    spi
  end

  defp open_spi_display(platform) do
    spi_host = open_display_spi_host(platform)

    spi_display_opts =
      [spi_host: spi_host] ++ get_spi_display_opts(platform)

    case :erlang.open_port({:spawn, "display"}, spi_display_opts) do
      display when is_port(display) ->
        {:ok,
         %{
           display: %{
             display_server: {:port, display},
             width: spi_display_opts[:width],
             height: spi_display_opts[:height]
           }
         }}

      _ ->
        IO.puts("Failed to open display")
        :error
    end
  end
end
