# SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
# SPDX-License-Identifier: Apache-2.0

defmodule FrameOS.MixProject do
  use Mix.Project

  def project do
    [
      app: :frame_os,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      deps: deps(),
      atomvm: [
        start: Main,
        flash_offset: 0x250000
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exatomvm, github: "AtomVM/exatomvm", runtime: false},
      {:elixir_make, "~> 0.4", runtime: false},
      {:avm_scene, github: "AtomVM/avm_scene"},
      {:photon_ui, github: "bettio/photon_ui"}
    ]
  end
end
