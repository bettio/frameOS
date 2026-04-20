# SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
# SPDX-License-Identifier: Apache-2.0

PRIV := ../../priv
DEST_PATH := $(PRIV)/icons/data_icons_32
MINRGB := escript ../../tools/minrgb.erl

.PHONY: directories

all: \
		directories \
		$(DEST_PATH)/droplet-solid-full.rgba \
		$(DEST_PATH)/droplet-solid-full-white.rgba \
		$(DEST_PATH)/stopwatch-solid-full.rgba \
		$(DEST_PATH)/temperature-low-solid-full-white.rgba \
		$(DEST_PATH)/umbrella-solid-full.rgba \
		$(DEST_PATH)/umbrella-solid-full-white.rgba

directories: $(DEST_PATH)

MKDIR_P := mkdir -p

$(DEST_PATH):
	$(MKDIR_P) $(DEST_PATH)

$(DEST_PATH)/%.rgba: %.png
	$(MINRGB) rgba8888 $< $@
