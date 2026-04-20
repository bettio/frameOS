# SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
# SPDX-License-Identifier: Apache-2.0

alias PhotonUI.Widgets.HorizontalLayout
alias PhotonUI.Widgets.Image
alias PhotonUI.Widgets.Rectangle
alias PhotonUI.Widgets.Text
alias PhotonUI.Widgets.VerticalLayout
alias PhotonUI.UIServer

alias UI.Weather.NextScreen

defmodule UI.Weather do
  @configured_place (
                      cfg = Application.compile_env!(:frame_os, :location)
                      name = Keyword.get(cfg, :name)
                      lat = Keyword.get(cfg, :latitude)
                      lon = Keyword.get(cfg, :longitude)

                      cond do
                        lat && lon ->
                          {:fixed,
                           %{
                             name: name,
                             country: nil,
                             latitude: lat,
                             longitude: lon,
                             elevation: nil
                           }}

                        name ->
                          {:by_name, name}

                        true ->
                          raise "config :frame_os, :location requires either :name or :latitude+:longitude"
                      end
                    )
  @refresh_interval_ms Application.compile_env!(:frame_os, :refresh_interval_minutes) * 60_000
  @first_refresh_ms 60_00
  @platform Application.compile_env!(:frame_os, :platform)
  @nav_widget_invisible @platform != "linux"

  @nav_widgets_splash [
    %NextScreen{
      name: :next_screen,
      x: 745,
      y: 425,
      width: 50,
      height: 50,
      label: ">",
      color: 0x000000,
      bgcolor: 0xFFFFFF,
      invisible: @nav_widget_invisible
    }
  ]

  @ui [
        %VerticalLayout{
          name: :vl,
          x: 5,
          y: 5,
          width: 790,
          height: 470,
          spacing: 8,
          children: [
            %Text{
              name: :line1,
              x: 0,
              y: 0,
              width: 790,
              height: 45,
              text: "Weather Data from",
              style: :h1
            },
            %Text{
              name: :line2,
              x: 0,
              y: 0,
              width: 790,
              height: 45,
              text: "open-meteo.com",
              style: :h1
            }
          ]
        }
      ] ++ @nav_widgets_splash

  def start_link(args, opts) do
    PhotonUI.UIServer.start_link(__MODULE__, args, opts)
  end

  def start_monitor(args, opts) do
    PhotonUI.UIServer.start_monitor(__MODULE__, args, opts)
  end

  def init(_opts) do
    {:ok, {@ui, %{}}, %{place: nil, weather: nil, view: :current}}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :error, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_event(:ui, :shown, _ui, state) do
    :erlang.send_after(@first_refresh_ms, self(), :refresh)
    {:noreply, state}
  end

  # Splash up — record the desired view; the first :refresh will paint it.
  def handle_event(:next_screen, :next, _ui, %{weather: nil} = state) do
    {:noreply, %{state | view: next_view(state.view)}}
  end

  def handle_event(:next_screen, :next, ui, state) do
    new_view = next_view(state.view)

    {:noreply, UIServer.replace_ui(ui, build_view(new_view, state.weather, state.place)),
     %{state | view: new_view}}
  end

  # Blank to white; held until the next :refresh repaints.
  def handle_event(:next_screen, :white_screen, ui, state) do
    {:noreply, UIServer.replace_ui(ui, white_screen_ui()), state}
  end

  def handle_event(_name, _what, _ui, state) do
    {:noreply, state}
  end

  # :refresh always lands back on the :current view.
  def handle_info(:refresh, ui, state) do
    result =
      with {:ok, place} <- ensure_place(state),
           {:ok, weather} <- fetch_weather(place.latitude, place.longitude) do
        {:ok, UIServer.replace_ui(ui, build_view(:current, weather, place)),
         %{state | place: place, weather: weather, view: :current}}
      end

    :erlang.send_after(@refresh_interval_ms, self(), :refresh)

    case result do
      {:ok, new_ui, new_state} -> {:noreply, new_ui, new_state}
      _ -> {:noreply, state}
    end
  end

  def handle_info(_msg, _ui, state) do
    {:noreply, state}
  end

  defp next_view(:current), do: :hours
  defp next_view(:hours), do: :forecast
  defp next_view(:forecast), do: :current

  defp build_view(:current, weather, place), do: build_weather_ui(weather, place)

  defp build_view(:hours, weather, _place),
    do: build_hours_ui(weather) ++ nav_widgets_top_right(0xFFFFFF, 0x000000)

  defp build_view(:forecast, weather, _place),
    do: build_forecast_ui(weather.daily) ++ nav_widgets_top_right()

  defp white_screen_ui do
    [%Rectangle{name: :blank, x: 0, y: 0, width: 800, height: 480, color: 0xFFFFFF}]
  end

  defp ensure_place(%{place: place}) when not is_nil(place), do: {:ok, place}

  defp ensure_place(_state) do
    case @configured_place do
      {:fixed, place} -> {:ok, place}
      {:by_name, name} -> geocode(name)
    end
  end

  defp build_weather_ui(weather, place) do
    current = weather.current
    condition = current.condition
    period = current.period
    description = condition_description(condition, period)
    icon_path = "icons/black_weather_128/#{icon_filename(condition, period)}"

    {:celsius, temp_c} = current.temperature_2m
    temp_headline = "#{round(temp_c)}°C"
    feels_like = "Feels like #{format_measurement(current.apparent_temperature)}"

    {:degrees, wind_dir_deg} = current.wind_direction_10m

    humidity = "Humidity: #{format_measurement(current.relative_humidity_2m)}"

    wind =
      "Wind: #{format_measurement(current.wind_speed_10m)} #{compass_cardinal(wind_dir_deg)}"

    pressure = "Pressure: #{format_measurement(current.pressure_msl)}"

    {status_color, status_fg} = condition_color(condition)
    status_text = status_line(current, place)

    hero_children = [
      %Image{
        name: :weather_icon,
        x: 0,
        y: 0,
        width: 128,
        height: 128,
        source: {:frame_os, icon_path}
      },
      %VerticalLayout{
        name: :hero_text,
        x: 0,
        y: 0,
        width: 646,
        height: 151,
        spacing: 8,
        children: [
          %Text{
            name: :temp,
            x: 0,
            y: 0,
            width: 646,
            height: 45,
            text: temp_headline,
            style: :h1
          },
          %Text{
            name: :description,
            x: 0,
            y: 0,
            width: 646,
            height: 45,
            text: description,
            style: :h1
          },
          %Text{
            name: :feels_like,
            x: 0,
            y: 0,
            width: 646,
            height: 45,
            text: feels_like,
            style: :h1
          }
        ]
      }
    ]

    vlayout_children =
      [
        %HorizontalLayout{
          name: :hero,
          x: 0,
          y: 0,
          width: 790,
          height: 151,
          spacing: 16,
          children: hero_children
        },
        %Text{name: :humidity, x: 0, y: 0, width: 790, height: 45, text: humidity, style: :h1},
        %Text{name: :wind, x: 0, y: 0, width: 790, height: 45, text: wind, style: :h1},
        %Text{name: :pressure, x: 0, y: 0, width: 790, height: 45, text: pressure, style: :h1}
      ] ++ extra_row_widgets(current)

    [
      %VerticalLayout{
        name: :vl,
        x: 5,
        y: 5,
        width: 790,
        height: 405,
        spacing: 16,
        children: vlayout_children
      },
      %Rectangle{
        name: :status_bg,
        x: 0,
        y: 420,
        width: 800,
        height: 60,
        color: status_color
      },
      %Text{
        name: :status,
        x: 8,
        y: 427,
        width: 784,
        height: 45,
        text: status_text,
        style: :h1,
        color: status_fg,
        bgcolor: status_color
      }
    ] ++ nav_widgets_current(status_fg, status_color)
  end

  defp nav_widgets_current(color, bgcolor) do
    [
      %NextScreen{
        name: :next_screen,
        x: 745,
        y: 425,
        width: 50,
        height: 50,
        label: ">",
        color: color,
        bgcolor: bgcolor,
        invisible: @nav_widget_invisible
      }
    ]
  end

  defp nav_widgets_top_right(color \\ 0x000000, bgcolor \\ 0xFFFFFF) do
    [
      %NextScreen{
        name: :next_screen,
        x: 745,
        y: 5,
        width: 50,
        height: 50,
        label: ">",
        color: color,
        bgcolor: bgcolor,
        invisible: @nav_widget_invisible
      }
    ]
  end

  defp build_forecast_ui(daily) do
    build_forecast_columns(daily, 0, [])
  end

  defp build_forecast_columns([], _i, acc), do: acc

  defp build_forecast_columns([day | rest], i, acc) do
    build_forecast_columns(rest, i + 1, acc ++ forecast_column(day, i))
  end

  # 12-hour table: 2 columns × 6 rows, hours alternate L/R per index.
  defp build_hours_ui(weather) do
    current_hour_iso = zero_minutes(weather.current.time)
    hours = slice_next_n(weather.hourly || [], current_hour_iso, 12)

    hours_table_headers() ++ build_hour_rows(hours, 0, [])
  end

  defp hours_table_headers do
    [
      %Rectangle{name: :hr_hdr_bg, x: 0, y: 0, width: 800, height: 60, color: 0x000000}
    ] ++ hours_header_icons(0) ++ hours_header_icons(400)
  end

  defp hours_header_icons(col_x) do
    side = if col_x == 0, do: :l, else: :r

    [
      %Image{
        name: :"hr_hdr_temp_#{side}",
        x: col_x + 145,
        y: 14,
        width: 32,
        height: 32,
        source: {:frame_os, "icons/data_icons_32/temperature-low-solid-full-white.rgba"},
        bgcolor: 0x000000
      },
      %Image{
        name: :"hr_hdr_prob_#{side}",
        x: col_x + 222,
        y: 14,
        width: 32,
        height: 32,
        source: {:frame_os, "icons/data_icons_32/umbrella-solid-full-white.rgba"},
        bgcolor: 0x000000
      },
      %Image{
        name: :"hr_hdr_prec_#{side}",
        x: col_x + 300,
        y: 14,
        width: 32,
        height: 32,
        source: {:frame_os, "icons/data_icons_32/droplet-solid-full-white.rgba"},
        bgcolor: 0x000000
      }
    ]
  end

  defp build_hour_rows([], _i, acc), do: acc

  defp build_hour_rows([hour | rest], i, acc) do
    build_hour_rows(rest, i + 1, acc ++ hour_row(hour, i))
  end

  defp hour_row(hour, index) do
    col_idx = rem(index, 2)
    row_idx = div(index, 2)
    col_x = col_idx * 400
    row_y = 60 + row_idx * 70

    {:celsius, temp_c} = hour.temperature
    {_, prob} = hour.precipitation_probability
    {_, prec} = hour.precipitation

    {accent_bg, _} = condition_color(hour.condition)
    body_bg = body_shade(accent_bg, row_idx)

    icon_path = "icons/black_weather_64/" <> icon_filename(hour.condition, hour.period)

    base = [
      %Rectangle{
        name: :"hr_bg_#{index}",
        x: col_x,
        y: row_y,
        width: 400,
        height: 70,
        color: body_bg
      },
      %Text{
        name: :"hr_time_#{index}",
        x: col_x + 8,
        y: row_y + 16,
        width: 55,
        height: 35,
        text: hour_label(hour.time),
        style: :h2,
        color: 0x000000,
        bgcolor: body_bg
      },
      %Image{
        name: :"hr_icon_#{index}",
        x: col_x + 72,
        y: row_y + 3,
        width: 64,
        height: 64,
        source: {:frame_os, icon_path},
        bgcolor: body_bg
      },
      %Text{
        name: :"hr_temp_#{index}",
        x: col_x + 145,
        y: row_y + 16,
        width: 70,
        height: 35,
        text: "#{round(temp_c)}°",
        style: :h2,
        color: 0x000000,
        bgcolor: body_bg
      }
    ]

    base ++ hourly_precip_widgets(prob, prec, hour, index, col_x, row_y, body_bg)
  end

  defp hourly_precip_widgets(prob, prec, hour, index, col_x, row_y, body_bg)
       when prob > 0 or prec > 0 do
    [
      %Text{
        name: :"hr_prob_#{index}",
        x: col_x + 222,
        y: row_y + 16,
        width: 70,
        height: 35,
        text: "#{prob}%",
        style: :h2,
        color: 0x000000,
        bgcolor: body_bg
      },
      %Text{
        name: :"hr_prec_#{index}",
        x: col_x + 300,
        y: row_y + 16,
        width: 95,
        height: 35,
        text: format_measurement(hour.precipitation),
        style: :h2,
        color: 0x000000,
        bgcolor: body_bg
      }
    ]
  end

  defp hourly_precip_widgets(_, _, _, _, _, _, _), do: []

  defp hour_label(iso) do
    case :binary.split(iso, "T") do
      [_, time_part] ->
        case :binary.split(time_part, ":") do
          [hh, _] -> hh <> "h"
          _ -> time_part
        end

      _ ->
        iso
    end
  end

  defp zero_minutes(iso) do
    case :binary.split(iso, "T") do
      [date, time] ->
        case :binary.split(time, ":") do
          [hh, _] -> date <> "T" <> hh <> ":00"
          _ -> iso
        end

      _ ->
        iso
    end
  end

  defp slice_next_n(hourly, current_hour_iso, n) do
    case find_hour_index(hourly, current_hour_iso, 0) do
      nil -> take_first(hourly, n, [])
      i -> drop_take(hourly, i, n, [])
    end
  end

  defp find_hour_index([], _, _), do: nil
  defp find_hour_index([%{time: t} | _], t, i), do: i
  defp find_hour_index([_ | rest], target, i), do: find_hour_index(rest, target, i + 1)

  defp drop_take(_list, _, 0, acc), do: :lists.reverse(acc)
  defp drop_take([], _, _, acc), do: :lists.reverse(acc)
  defp drop_take([h | t], 0, n, acc), do: drop_take(t, 0, n - 1, [h | acc])
  defp drop_take([_ | t], i, n, acc), do: drop_take(t, i - 1, n, acc)

  defp take_first(_, 0, acc), do: :lists.reverse(acc)
  defp take_first([], _, acc), do: :lists.reverse(acc)
  defp take_first([h | t], n, acc), do: take_first(t, n - 1, [h | acc])

  defp forecast_column(day, index) do
    column_x = index * 160
    {accent_bg, accent_fg} = condition_color(day.condition)
    body_bg = body_shade(accent_bg, index)
    body_fg = 0x000000
    icon_path = "icons/black_weather_128/" <> icon_filename(day.condition, :day)
    {:celsius, max_c} = day.temperature_max
    {:celsius, min_c} = day.temperature_min
    date_text = if index == 0, do: "Today", else: day_label(day.time)
    temps_text = "#{round(max_c)}° - #{round(min_c)}°"

    [
      %Rectangle{
        name: :"col_accent_#{index}",
        x: column_x,
        y: 0,
        width: 160,
        height: 50,
        color: accent_bg
      },
      %Rectangle{
        name: :"col_body_#{index}",
        x: column_x,
        y: 50,
        width: 160,
        height: 430,
        color: body_bg
      },
      %Text{
        name: :"col_date_#{index}",
        x: column_x + 8,
        y: 4,
        width: 144,
        height: 45,
        text: date_text,
        style: :h1,
        color: accent_fg,
        bgcolor: accent_bg
      },
      %Image{
        name: :"col_icon_#{index}",
        x: column_x + 16,
        y: 56,
        width: 128,
        height: 128,
        source: {:frame_os, icon_path},
        bgcolor: body_bg
      },
      %Text{
        name: :"col_temps_#{index}",
        x: column_x + 8,
        y: 200,
        width: 144,
        height: 45,
        text: temps_text,
        style: :h1,
        color: body_fg,
        bgcolor: body_bg
      }
    ] ++ precip_widgets(day, index, column_x, body_fg, body_bg)
  end

  defp precip_widgets(day, index, column_x, fg, bg) do
    {_, prob} = day.precipitation_probability_max
    {_, sum} = day.precipitation_sum
    {_, hours} = day.precipitation_hours

    if prob > 0 or sum > 0 or hours > 0 do
      precip_row(
        :chance,
        index,
        column_x,
        260,
        "umbrella-solid-full.rgba",
        format_measurement(day.precipitation_probability_max),
        fg,
        bg
      ) ++
        precip_row(
          :total,
          index,
          column_x,
          315,
          "droplet-solid-full.rgba",
          format_measurement(day.precipitation_sum),
          fg,
          bg
        ) ++
        precip_row(
          :hours,
          index,
          column_x,
          370,
          "stopwatch-solid-full.rgba",
          format_measurement(day.precipitation_hours),
          fg,
          bg
        )
    else
      []
    end
  end

  defp precip_row(name, index, column_x, row_y, icon_file, text, fg, bg) do
    [
      %Image{
        name: :"col_#{name}_icon_#{index}",
        x: column_x + 8,
        y: row_y + 1,
        width: 32,
        height: 32,
        source: {:frame_os, "icons/data_icons_32/" <> icon_file},
        bgcolor: bg
      },
      %Text{
        name: :"col_#{name}_#{index}",
        x: column_x + 44,
        y: row_y,
        width: 108,
        height: 35,
        text: text,
        style: :h2,
        color: fg,
        bgcolor: bg
      }
    ]
  end

  defp day_label(iso_date) do
    case :binary.split(iso_date, "-", [:global]) do
      [year_bin, month_bin, day_bin] ->
        y = :erlang.binary_to_integer(year_bin)
        m = :erlang.binary_to_integer(month_bin)
        d = :erlang.binary_to_integer(day_bin)
        day_of_week_short(:calendar.day_of_the_week({y, m, d}))

      _ ->
        iso_date
    end
  end

  defp day_of_week_short(1), do: "Mon"
  defp day_of_week_short(2), do: "Tue"
  defp day_of_week_short(3), do: "Wed"
  defp day_of_week_short(4), do: "Thu"
  defp day_of_week_short(5), do: "Fri"
  defp day_of_week_short(6), do: "Sat"
  defp day_of_week_short(7), do: "Sun"

  def icon_filename(:clear_sky, :day), do: "clear_sky_day.rgba"
  def icon_filename(:clear_sky, :night), do: "clear_sky_night.rgba"

  # The iconset collapses :mainly_clear and :partly_cloudy to the same visual.
  def icon_filename(:mainly_clear, :day), do: "partly_cloudy_day.rgba"
  def icon_filename(:mainly_clear, :night), do: "partly_cloudy_night.rgba"
  def icon_filename(:partly_cloudy, :day), do: "partly_cloudy_day.rgba"
  def icon_filename(:partly_cloudy, :night), do: "partly_cloudy_night.rgba"

  def icon_filename(condition, _) do
    case condition do
      :clear_sky ->
        "clear_sky_day.rgba"

      condition when condition in [:mainly_clear, :partly_cloudy] ->
        "partly_cloudy_day.rgba"

      :overcast ->
        "overcast.rgba"

      condition when condition in [:fog, :depositing_rime_fog] ->
        "fog.rgba"

      condition when condition in [:light_drizzle, :slight_rain, :slight_rain_showers] ->
        "slight_rain.rgba"

      condition
      when condition in [
             :moderate_drizzle,
             :dense_drizzle,
             :moderate_rain,
             :heavy_rain,
             :moderate_rain_showers,
             :violent_rain_showers
           ] ->
        "rain.rgba"

      condition when condition in [:light_freezing_drizzle, :light_freezing_rain] ->
        "slight_sleet.rgba"

      condition when condition in [:dense_freezing_drizzle, :heavy_freezing_rain] ->
        "sleet.rgba"

      condition when condition in [:slight_snow, :snow_grains] ->
        "slight_snow.rgba"

      condition when condition in [:moderate_snow, :heavy_snow] ->
        "snow.rgba"

      :slight_snow_showers ->
        "slight_snow_showers.rgba"

      :heavy_snow_showers ->
        "snow_showers.rgba"

      :thunderstorm ->
        "chance_thunderstorm.rgba"

      condition
      when condition in [:thunderstorm_with_slight_hail, :thunderstorm_with_heavy_hail] ->
        "thunderstorm.rgba"

      :unknown ->
        "unknown.rgba"

      _ ->
        "unknown.rgba"
    end
  end

  @spec condition_description(atom(), :day | :night | nil) :: String.t()
  def condition_description(condition, period \\ nil)

  def condition_description(:clear_sky, :night), do: "Clear"
  def condition_description(:mainly_clear, :night), do: "Mostly clear"
  def condition_description(:partly_cloudy, :night), do: "Partly cloudy"

  def condition_description(condition, _) do
    case condition do
      :clear_sky -> "Sunny"
      :mainly_clear -> "Mostly sunny"
      :partly_cloudy -> "Partly cloudy"
      :overcast -> "Cloudy"
      :fog -> "Foggy"
      :depositing_rime_fog -> "Icy fog"
      :light_drizzle -> "Light drizzle"
      :moderate_drizzle -> "Drizzle"
      :dense_drizzle -> "Heavy drizzle"
      :light_freezing_drizzle -> "Light freezing drizzle"
      :dense_freezing_drizzle -> "Heavy freezing drizzle"
      :slight_rain -> "Light rain"
      :moderate_rain -> "Rain"
      :heavy_rain -> "Heavy rain"
      :light_freezing_rain -> "Light freezing rain"
      :heavy_freezing_rain -> "Heavy freezing rain"
      :slight_snow -> "Light snow"
      :moderate_snow -> "Snow"
      :heavy_snow -> "Heavy snow"
      :snow_grains -> "Snow grains"
      :slight_rain_showers -> "Light showers"
      :moderate_rain_showers -> "Rain showers"
      :violent_rain_showers -> "Heavy showers"
      :slight_snow_showers -> "Light snow showers"
      :heavy_snow_showers -> "Heavy snow showers"
      :thunderstorm -> "Thunderstorm"
      :thunderstorm_with_slight_hail -> "Thunderstorm with hail"
      :thunderstorm_with_heavy_hail -> "Severe thunderstorm with hail"
      :unknown -> "Unknown"
      _ -> "Unknown"
    end
  end

  @spec normalize(map()) :: map()
  def normalize(%{"current" => current, "current_units" => current_units} = payload) do
    daily = Map.get(payload, "daily")
    daily_units = Map.get(payload, "daily_units")
    hourly = Map.get(payload, "hourly")
    hourly_units = Map.get(payload, "hourly_units")

    normalized =
      payload
      |> Map.delete("current")
      |> Map.delete("current_units")
      |> Map.delete("daily")
      |> Map.delete("daily_units")
      |> Map.delete("hourly")
      |> Map.delete("hourly_units")
      |> Enum.map(fn {key, value} -> {top_level_key!(key), value} end)
      |> Map.new()
      |> Map.put(:current, normalize_current(current, current_units))
      |> maybe_put_daily(daily, daily_units)
      |> maybe_put_hourly(hourly, hourly_units)

    {:ok, normalized}
  end

  def normalize(_other) do
    :error
  end

  defp maybe_put_daily(map, nil, _), do: map
  defp maybe_put_daily(map, daily, units), do: Map.put(map, :daily, normalize_daily(daily, units))

  defp maybe_put_hourly(map, nil, _), do: map

  defp maybe_put_hourly(map, hourly, units),
    do: Map.put(map, :hourly, normalize_hourly(hourly, units))

  @spec format_measurement({atom(), number()}) :: String.t()
  def format_measurement({unit, value}) when is_atom(unit) and is_number(value) do
    "#{format_number(value)} #{display_unit(unit)}"
  end

  defp normalize_current(current, current_units) do
    Enum.reduce(current, %{}, fn {key, value}, acc ->
      Map.put(
        acc,
        current_key!(key),
        normalize_current_value(key, value, Map.get(current_units, key))
      )
    end)
  end

  defp normalize_current_value("weather_code", code, _unit), do: wmo_code_to_condition(code)
  defp normalize_current_value("is_day", 1, _unit), do: :day
  defp normalize_current_value("is_day", 0, _unit), do: :night
  defp normalize_current_value("time", value, _unit), do: value

  defp normalize_current_value(_key, value, unit) do
    {unit_to_atom!(unit), value}
  end

  defp normalize_daily(daily, units) do
    times = Map.get(daily, "time", [])
    codes = Map.get(daily, "weather_code", [])
    maxes = Map.get(daily, "temperature_2m_max", [])
    mins = Map.get(daily, "temperature_2m_min", [])
    probs = Map.get(daily, "precipitation_probability_max", [])
    sums = Map.get(daily, "precipitation_sum", [])
    hours = Map.get(daily, "precipitation_hours", [])

    max_unit = unit_to_atom!(Map.get(units, "temperature_2m_max"))
    min_unit = unit_to_atom!(Map.get(units, "temperature_2m_min"))
    prob_unit = unit_to_atom!(Map.get(units, "precipitation_probability_max"))
    sum_unit = unit_to_atom!(Map.get(units, "precipitation_sum"))
    hours_unit = unit_to_atom!(Map.get(units, "precipitation_hours"))

    zip_daily(times, codes, maxes, mins, probs, sums, hours, [])
    |> Enum.reverse()
    |> Enum.map(fn {time, code, max_v, min_v, prob_v, sum_v, hours_v} ->
      %{
        time: time,
        condition: wmo_code_to_condition(code),
        temperature_max: {max_unit, max_v},
        temperature_min: {min_unit, min_v},
        precipitation_probability_max: {prob_unit, prob_v},
        precipitation_sum: {sum_unit, sum_v},
        precipitation_hours: {hours_unit, hours_v}
      }
    end)
  end

  defp zip_daily([t | ts], [c | cs], [mx | mxs], [mn | mns], [p | ps], [s | ss], [h | hs], acc) do
    zip_daily(ts, cs, mxs, mns, ps, ss, hs, [{t, c, mx, mn, p, s, h} | acc])
  end

  defp zip_daily(_, _, _, _, _, _, _, acc), do: acc

  defp normalize_hourly(hourly, units) do
    times = Map.get(hourly, "time", [])
    temps = Map.get(hourly, "temperature_2m", [])
    codes = Map.get(hourly, "weather_code", [])
    probs = Map.get(hourly, "precipitation_probability", [])
    precs = Map.get(hourly, "precipitation", [])
    days = Map.get(hourly, "is_day", [])

    temp_unit = unit_to_atom!(Map.get(units, "temperature_2m"))
    prob_unit = unit_to_atom!(Map.get(units, "precipitation_probability"))
    prec_unit = unit_to_atom!(Map.get(units, "precipitation"))

    zip_hourly(times, temps, codes, probs, precs, days, [])
    |> :lists.reverse()
    |> Enum.map(fn {time, temp_v, code, prob_v, prec_v, day_v} ->
      %{
        time: time,
        condition: wmo_code_to_condition(code),
        period: if(day_v == 1, do: :day, else: :night),
        temperature: {temp_unit, temp_v},
        precipitation_probability: {prob_unit, prob_v},
        precipitation: {prec_unit, prec_v}
      }
    end)
  end

  defp zip_hourly([t | ts], [tp | tps], [c | cs], [p | ps], [pr | prs], [d | ds], acc) do
    zip_hourly(ts, tps, cs, ps, prs, ds, [{t, tp, c, p, pr, d} | acc])
  end

  defp zip_hourly(_, _, _, _, _, _, acc), do: acc

  defp top_level_key!(key) do
    case key do
      "current" -> :current
      "current_units" -> :current_units
      "elevation" -> :elevation
      "generationtime_ms" -> :generation_time_ms
      "latitude" -> :latitude
      "longitude" -> :longitude
      "timezone" -> :timezone
      "timezone_abbreviation" -> :timezone_abbreviation
      "utc_offset_seconds" -> :utc_offset_seconds
      "daily" -> :daily
      "daily_units" -> :daily_units
      "hourly" -> :hourly
      "hourly_units" -> :hourly_units
      _ -> raise ArgumentError, "unsupported top-level key: #{inspect(key)}"
    end
  end

  defp current_key!(key) do
    case key do
      "apparent_temperature" -> :apparent_temperature
      "cloud_cover" -> :cloud_cover
      "interval" -> :interval
      "is_day" -> :period
      "precipitation" -> :precipitation
      "pressure_msl" -> :pressure_msl
      "rain" -> :rain
      "relative_humidity_2m" -> :relative_humidity_2m
      "showers" -> :showers
      "snowfall" -> :snowfall
      "surface_pressure" -> :surface_pressure
      "temperature_2m" -> :temperature_2m
      "time" -> :time
      "weather_code" -> :condition
      "wind_direction_10m" -> :wind_direction_10m
      "wind_gusts_10m" -> :wind_gusts_10m
      "wind_speed_10m" -> :wind_speed_10m
      _ -> raise ArgumentError, "unsupported current key: #{inspect(key)}"
    end
  end

  defp unit_to_atom!(unit) do
    case unit do
      "°C" -> :celsius
      "°" -> :degrees
      "%" -> :percent
      "mm" -> :mm
      "cm" -> :cm
      "hPa" -> :hpa
      "km/h" -> :km_h
      "seconds" -> :seconds
      "h" -> :hours
      _ -> raise ArgumentError, "unsupported unit: #{inspect(unit)}"
    end
  end

  defp display_unit(:celsius), do: "°C"
  defp display_unit(:degrees), do: "°"
  defp display_unit(:percent), do: "%"
  defp display_unit(:mm), do: "mm"
  defp display_unit(:cm), do: "cm"
  defp display_unit(:hpa), do: "hPa"
  defp display_unit(:km_h), do: "km/h"
  defp display_unit(:seconds), do: "s"
  defp display_unit(:hours), do: "h"

  defp format_number(value) when is_integer(value) do
    Integer.to_string(value)
  end

  defp format_number(value) when is_float(value) do
    bin = :erlang.float_to_binary(value, [:short])

    case :binary.split(bin, ".") do
      [int_part, "0"] -> int_part
      _ -> bin
    end
  end

  @spec wmo_code_to_condition(integer()) :: atom()
  defp wmo_code_to_condition(code) do
    case code do
      0 -> :clear_sky
      1 -> :mainly_clear
      2 -> :partly_cloudy
      3 -> :overcast
      45 -> :fog
      48 -> :depositing_rime_fog
      51 -> :light_drizzle
      53 -> :moderate_drizzle
      55 -> :dense_drizzle
      56 -> :light_freezing_drizzle
      57 -> :dense_freezing_drizzle
      61 -> :slight_rain
      63 -> :moderate_rain
      65 -> :heavy_rain
      66 -> :light_freezing_rain
      67 -> :heavy_freezing_rain
      71 -> :slight_snow
      73 -> :moderate_snow
      75 -> :heavy_snow
      77 -> :snow_grains
      80 -> :slight_rain_showers
      81 -> :moderate_rain_showers
      82 -> :violent_rain_showers
      85 -> :slight_snow_showers
      86 -> :heavy_snow_showers
      95 -> :thunderstorm
      96 -> :thunderstorm_with_slight_hail
      99 -> :thunderstorm_with_heavy_hail
      # Not implemented from open-meteo
      17 -> :thunderstorm
      41 -> :fog
      42 -> :fog
      43 -> :fog
      44 -> :fog
      46 -> :fog
      47 -> :fog
      49 -> :depositing_rime_fog
      50 -> :light_drizzle
      52 -> :moderate_drizzle
      54 -> :dense_drizzle
      60 -> :slight_rain
      62 -> :moderate_rain
      64 -> :heavy_rain
      70 -> :slight_snow
      72 -> :moderate_snow
      74 -> :heavy_snow
      97 -> :thunderstorm
      _ -> :unknown
    end
  end

  defp extra_row_widgets(current) do
    {_, snowfall} = current.snowfall
    {_, precipitation} = current.precipitation
    {_, cloud_cover} = current.cloud_cover

    text =
      cond do
        snowfall > 0 -> "Snowfall: #{format_measurement(current.snowfall)}"
        precipitation > 0 -> "Precipitation: #{format_measurement(current.precipitation)}"
        cloud_cover > 0 -> "Cloud cover: #{format_measurement(current.cloud_cover)}"
        true -> nil
      end

    case text do
      nil -> []
      t -> [%Text{name: :extra, x: 0, y: 0, width: 790, height: 45, text: t, style: :h1}]
    end
  end

  defp status_line(current, place) do
    update_time =
      case :binary.split(current.time, "T") do
        [_, hhmm] -> hhmm
        _ -> current.time
      end

    display =
      cond do
        place.name && place.country ->
          "#{place.name}, #{place.country}"

        place.name ->
          place.name

        true ->
          "#{format_number(place.latitude)}°, #{format_number(place.longitude)}°"
      end

    "Update #{update_time} | #{display}"
  end

  defp geocode(name) do
    url = "/v1/search?name=#{name}&count=1&language=en&format=json"

    with {:ok, %{"results" => [first | _]}} <-
           HTTP.get_json(:http, "geocoding-api.open-meteo.com", 80, url) do
      {:ok,
       %{
         name: first["name"],
         country: first["country"],
         latitude: first["latitude"],
         longitude: first["longitude"],
         elevation: first["elevation"]
       }}
    else
      _ -> :error
    end
  end

  defp fetch_weather(lat, lon) do
    lat_str = :erlang.float_to_binary(lat, [:short])
    lon_str = :erlang.float_to_binary(lon, [:short])

    url =
      "/v1/forecast?latitude=#{lat_str}&longitude=#{lon_str}" <>
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day," <>
        "wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,rain,showers," <>
        "snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure" <>
        "&hourly=temperature_2m,weather_code,precipitation_probability,precipitation,is_day" <>
        "&daily=weather_code,temperature_2m_max,temperature_2m_min," <>
        "precipitation_probability_max,precipitation_sum,precipitation_hours" <>
        "&forecast_days=5" <>
        "&timezone=auto"

    with {:ok, payload} <- HTTP.get_json(:http, "api.open-meteo.com", 80, url) do
      normalize(payload)
    end
  end

  defp compass_cardinal(degrees) when degrees < 22.5 or degrees >= 337.5, do: "N"
  defp compass_cardinal(degrees) when degrees < 67.5, do: "NE"
  defp compass_cardinal(degrees) when degrees < 112.5, do: "E"
  defp compass_cardinal(degrees) when degrees < 157.5, do: "SE"
  defp compass_cardinal(degrees) when degrees < 202.5, do: "S"
  defp compass_cardinal(degrees) when degrees < 247.5, do: "SW"
  defp compass_cardinal(degrees) when degrees < 292.5, do: "W"
  defp compass_cardinal(_degrees), do: "NW"

  # {background, text} per condition group.
  defp condition_color(c) when c in [:clear_sky, :mainly_clear], do: {0xCC8800, 0x000000}
  defp condition_color(:partly_cloudy), do: {0x336699, 0xFFFFFF}
  defp condition_color(:overcast), do: {0x555555, 0xFFFFFF}
  defp condition_color(c) when c in [:fog, :depositing_rime_fog], do: {0x707070, 0xFFFFFF}

  defp condition_color(c)
       when c in [
              :light_drizzle,
              :moderate_drizzle,
              :dense_drizzle,
              :slight_rain,
              :slight_rain_showers
            ],
       do: {0x4682B4, 0xFFFFFF}

  defp condition_color(c)
       when c in [:moderate_rain, :heavy_rain, :moderate_rain_showers, :violent_rain_showers],
       do: {0x1F4E79, 0xFFFFFF}

  defp condition_color(c)
       when c in [
              :light_freezing_drizzle,
              :dense_freezing_drizzle,
              :light_freezing_rain,
              :heavy_freezing_rain
            ],
       do: {0x008B8B, 0xFFFFFF}

  defp condition_color(c)
       when c in [
              :slight_snow,
              :moderate_snow,
              :heavy_snow,
              :snow_grains,
              :slight_snow_showers,
              :heavy_snow_showers
            ],
       do: {0x6080A0, 0xFFFFFF}

  defp condition_color(c)
       when c in [
              :thunderstorm,
              :thunderstorm_with_slight_hail,
              :thunderstorm_with_heavy_hail
            ],
       do: {0x4B0082, 0xFFFFFF}

  defp condition_color(_), do: {0x404040, 0xFFFFFF}

  # Alternating pastels so adjacent same-condition columns stay distinct.
  defp body_shade(accent_bg, index) do
    case rem(index, 2) do
      0 -> lighten(accent_bg, 3, 4)
      _ -> lighten(accent_bg, 5, 8)
    end
  end

  defp lighten(color, num, den) do
    r = :erlang.band(:erlang.bsr(color, 16), 0xFF)
    g = :erlang.band(:erlang.bsr(color, 8), 0xFF)
    b = :erlang.band(color, 0xFF)

    r2 = r + div((255 - r) * num, den)
    g2 = g + div((255 - g) * num, den)
    b2 = b + div((255 - b) * num, den)

    :erlang.bor(:erlang.bor(:erlang.bsl(r2, 16), :erlang.bsl(g2, 8)), b2)
  end
end
