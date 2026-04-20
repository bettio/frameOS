<!--
SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
SPDX-License-Identifier: Apache-2.0
-->

# frameOS

A small AtomVM/Elixir "OS" for ePaper digital photo/info frames.
Currently runs a single weather app pulling data from
[open-meteo.com](https://open-meteo.com).

Targets:

- **Linux + SDL** — 800×480 dev/preview window.
- **Seeed reTerminal E1002** — 800×480 e-paper + three on-board GPIO
  buttons.

Selected at compile time by `:platform` in `config/config.exs`.

## Try it

    mix deps.get
    mix atomvm.packbeam
    ./AtomVM frame_os.avm deps.avm priv.avm atomvmlib.avm

`mix atomvm.packbeam` runs `make` first to convert PNG icons to the
`rgba8888` blobs AtomGL needs — needs a working `DISPLAY` for `wxImage`.
The AtomVM runtime, `atomvmlib.avm`, and `avm_display_port_driver.so`
have to be alongside the `.avm` bundles.

Edit `config/config.exs` to set your location, refresh interval, and
WiFi credentials.

## License

Project source is **Apache-2.0** (see `LICENSE` and per-file SPDX
headers).

Assets follow the [REUSE](https://reuse.software/) spec:

- Per-file `.license` sidecars next to the icon PNGs — Weather
  Underground icons (MIT OR GPL-3.0-or-later) and Font Awesome free
  icons (CC-BY-4.0).
- `.reuse/dep5` for the bundled Noto fonts (SIL Open Font License 1.1).
