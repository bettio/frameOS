# SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
# SPDX-License-Identifier: Apache-2.0

defmodule HTTP do
  @moduledoc """
  Minimal HTTP client wrapper around `:ahttp_client`.

  Streams the response body chunk-by-chunk into the OTP `:json` incremental
  decoder (`:json.decode_start/3` + `:json.decode_continue/2`) so the full
  response is never accumulated as a binary.

      HTTP.get_json(:http,  "api.open-meteo.com",       80,  "/v1/forecast?...")
      HTTP.get_json(:https, "geocoding-api.open-meteo.com", 443, "/v1/search?name=Padova")
  """

  @compile {:no_warn_undefined, :ahttp_client}
  @compile {:no_warn_undefined, :json}

  @type scheme :: :http | :https
  @type host :: binary | charlist

  @doc """
  GET `path` from `host:port` over `scheme` and decode the JSON body.

  Options:
    * `:user_agent` — overrides the default UA string
    * `:headers`    — extra request headers, list of `{name, value}` binaries
  """
  @spec get_json(scheme, host, 1..65535, binary, keyword) ::
          {:ok, term} | {:error, term}
  def get_json(scheme, host, port, path, opts \\ []) do
    headers = build_headers(opts)

    {:ok, conn} = :ahttp_client.connect(scheme, host, port, active: false)

    {:ok, conn, _ref} =
      :ahttp_client.request(conn, "GET", path, headers, :undefined)

    pump(conn, :start)
  end

  defp build_headers(opts) do
    user_agent = opts[:user_agent] || "frame_os/0.1.0"
    [{"User-Agent", user_agent}] ++ (opts[:headers] || [])
  end

  defp pump(conn, decoder_state) do
    {:ok, conn, responses} = :ahttp_client.recv(conn, 0)

    case consume(responses, decoder_state) do
      {:done, term} -> {:ok, term}
      {:cont, new_state} -> pump(conn, new_state)
      {:error, _} = err -> err
    end
  end

  defp consume([], state), do: {:cont, state}

  defp consume([{:data, _ref, chunk} | rest], state) do
    case feed(state, chunk) do
      {:continue, new_state} -> consume(rest, new_state)
      {term, _acc, _rest_bin} -> {:done, term}
    end
  end

  defp consume([{:done, _ref} | _rest], :start), do: {:error, :empty_response}

  defp consume([{:done, _ref} | _rest], state) do
    case :json.decode_continue(:end_of_input, state) do
      {term, _acc, _rest_bin} -> {:done, term}
      {:continue, _} -> {:error, :incomplete}
    end
  end

  defp consume([_other | rest], state), do: consume(rest, state)

  defp feed(:start, chunk), do: :json.decode_start(chunk, nil, %{})
  defp feed(state, chunk), do: :json.decode_continue(chunk, state)
end
