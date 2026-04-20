# SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
# SPDX-License-Identifier: Apache-2.0

import Config

# Target platform — `"linux"` (SDL dev surface) or `"reterminal-e1002"`
# (Seeed E-paper hardware). Selected at compile time; HAL picks the
# matching display init and weather.ex hides on-screen affordances
# (the > chevron) on hardware.
config :frame_os, platform: "reterminal-e1002"

# Either a name (geocoding looks up lat/lon and the canonical display name)…
config :frame_os, :location, name: "Padova"

# …or fixed coordinates (no geocoding; status bar shows the coords):
# config :frame_os, :location, latitude: 45.4064, longitude: 11.8768

# Optionally combine both — coords used directly, name used in the status bar:
# config :frame_os, :location, latitude: 45.4064, longitude: 11.8768, name: "Padova"

config :frame_os, refresh_interval_minutes: 20

# WiFi credentials. Comment out (or remove the entry) to skip network
# bring-up at boot — useful when running on a host that already has
# connectivity, or for the SDL dev surface.
config :frame_os, :wifi,
  ssid: "TYPE_WIFI_SSID_HERE",
  psk: "TYPE_WIFI_PASSWORD_HERE"
