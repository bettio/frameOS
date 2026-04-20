# SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
# SPDX-License-Identifier: Apache-2.0

defmodule Main do
  @compile {:no_warn_undefined, :alisp}
  @compile {:no_warn_undefined, :ahttp_client}
  @compile {:no_warn_undefined, :atomvm}
  @compile {:no_warn_undefined, :avm_pubsub}
  @compile {:no_warn_undefined, :network}
  @compile {:no_warn_undefined, :port}

  @wifi_creds Application.compile_env(:frame_os, :wifi, [])

  def start() do
    :erlang.display("Hello.")

    {:ok, _pubsub} = :avm_pubsub.start(:avm_pubsub)

    with {:ok, initialized} <- HAL.init(),
         %{display: initialized_display} <- initialized,
         %{display_server: display_server, width: width, height: height} <- initialized_display do
      opts = [
        width: width,
        height: height,
        display_server: display_server,
        keyboard_server: Map.get(initialized_display, :keyboard_server, [])
      ]

      {:port, disp} = display_server

      :port.call(
        disp,
        {:register_font, :font_h1, :atomvm.read_priv(:frame_os, "font-h1.ufont")}
      )

      :port.call(
        disp,
        {:register_font, :font_h2, :atomvm.read_priv(:frame_os, "font-h2.ufont")}
      )

      {:ok, _ui} = UI.start(opts, [display_server: display_server] ++ opts)
    else
      _ ->
        IO.puts("Failed HAL init.")
    end

    maybe_start_network()

    recv_loop()
  end

  defp recv_loop() do
    recv_loop()
  end

  defp maybe_start_network() do
    case @wifi_creds[:ssid] do
      nil ->
        IO.puts("No wifi configured, skipping network bring-up.")
        :ok

      ssid ->
        IO.puts(~s(Will connect to "#{ssid}".))

        case :network.wait_for_sta(@wifi_creds) do
          :ok ->
            IO.puts("WLAN AP ready. Waiting connections.\n")
            :ok

          {:ok, {_address, _netmask, _gateway} = ips} ->
            IO.puts("Acquired IP address: #{inspect(ips)}\n")
            :ok

          error ->
            IO.puts("An error occurred starting network: #{inspect(error)}\n")
            :ok
        end
    end
  end
end
