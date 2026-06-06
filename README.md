<!--
SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
SPDX-License-Identifier: Apache-2.0
-->

# frameOS

A small AtomVM/Elixir "OS" for ePaper digital photo/info frames.
Currently runs a single weather app pulling data from
[open-meteo.com](https://open-meteo.com).

Targets:

- **Linux + SDL** - 800×480 dev/preview window.
- **Seeed reTerminal E1002** - an ESP32-S3 board with an 800×480 e-paper
  display + three on-board GPIO buttons.

Selected at compile time by `:platform` in `config/config.exs`.

## Prerequisites

Build tools: Elixir `~> 1.19` and a matching Erlang/OTP (1.19.4 / OTP 28
are known-good), plus `make` and Erlang's `wx` with a working `DISPLAY`
(the icon build uses `wxImage`).

frameOS runs on an **AtomVM built with the
[AtomGL](https://github.com/atomvm/atomgl) display driver** - stock
AtomVM has no graphics, so the `AtomVM` binary,
`avm_display_port_driver.so`, and `atomvmlib.avm` aren't shipped here:
you build them yourself (next section) from
[AtomVM](https://github.com/atomvm/AtomVM) `release-0.7` and atomgl
`main` (known-good at `eb901e7`). The reTerminal additionally needs
[ESP-IDF](https://docs.espressif.com/projects/esp-idf/) + `esptool`.

## Build the runtime (Linux + SDL)

Once, to produce the three files above:

```bash
    # 1. AtomVM itself - deps: gcc/clang, cmake, make, gperf, zlib, Mbed TLS, erlc, elixir
    git clone https://github.com/atomvm/AtomVM && cd AtomVM
    git checkout release-0.7
    mkdir build && cd build && cmake .. && make -j8
    #    -> build/src/AtomVM and build/libs/atomvmlib.avm

    # 2. AtomGL's SDL display driver - deps: zlib, SDL
    git clone https://github.com/atomvm/atomgl && cd atomgl/sdl_display
    cmake -DLIBATOMVM_INCLUDE_PATH=/path/to/AtomVM/src/libAtomVM/ . && make
    #    -> avm_display_port_driver.so
```

Copy `AtomVM`, `avm_display_port_driver.so`, and `atomvmlib.avm` into the
frameOS project root.

## Try it

```bash
    mix deps.get
    mix atomvm.packbeam
    ./AtomVM frame_os.avm atomvmlib.avm
```

`mix atomvm.packbeam` runs `make` first to convert PNG icons to the
`rgba8888` blobs AtomGL needs - needs a working `DISPLAY` for `wxImage`.
The AtomVM runtime, `atomvmlib.avm`, and `avm_display_port_driver.so`
have to be alongside the `.avm` bundles.

Edit `config/config.exs` to set your location, refresh interval, and
WiFi credentials.

## On the reTerminal (ESP32-S3)

Set `platform: "reterminal-e1002"` in `config/config.exs`, build AtomVM
for the ESP32 with AtomGL as a component, and flash the VM before the
app:

```bash
    cd AtomVM/src/platforms/esp32/components/
    git clone https://github.com/atomvm/atomgl     # main branch, tested with git rev. eb901e7
    cd ..                                          # src/platforms/esp32
    idf.py set-target esp32s3
    idf.py menuconfig          # enable PSRAM - see below
    idf.py build && idf.py flash
```

- **PSRAM is required.** The 800×480 framebuffer plus fonts and icons
  don't fit in the ~300 KB of internal RAM; without it the device hits
  allocation failures and reboots. Enable external SPI RAM, **Octal**
  mode, **80 MHz** in `menuconfig`.
- **Flash >= 4 MB**, with a partition table whose app/BEAM partition is
  large enough - `main.avm` is ~1 MB and lands at `0x250000`.

Then build and flash the app - the AtomVM stdlib is bundled in the image
you just flashed, and the app's own deps are handled by `mix` and the
`atomvm.packbeam` task:

```bash
    mix deps.get && mix atomvm.packbeam
    mix atomvm.esp32.flash --port /dev/ttyACM0    # port varies
```

## Troubleshooting

- **Boot loops with `Guru Meditation Error ... Cache error / MMU entry
  fault`** - PSRAM isn't enabled, or the flash/partition is too small.
- **Boots but the screen stays white** (atomgl allocation failures in the
  log) - same RAM pressure; also check your atomgl build supports the
  panel (the reTerminal uses `good-display/gdep073e01`).
- **`{badmatch, undefined}` from `:atomvm.read_priv`** - `make` didn't run
  or `priv.avm` wasn't repacked; the icon step needs `wx` + `DISPLAY`.

## License

Project source is **Apache-2.0** (see `LICENSE` and per-file SPDX
headers).

Assets follow the [REUSE](https://reuse.software/) spec:

- Per-file `.license` sidecars next to the icon PNGs - Weather
  Underground icons (MIT OR GPL-3.0-or-later) and Font Awesome free
  icons (CC-BY-4.0).
- `.reuse/dep5` for the bundled Noto fonts (SIL Open Font License 1.1).
