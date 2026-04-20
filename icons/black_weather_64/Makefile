# SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
# SPDX-License-Identifier: Apache-2.0

PRIV := ../../priv
DEST_PATH := $(PRIV)/icons/black_weather_64
MINRGB := escript ../../tools/minrgb.erl

.PHONY: directories

all: \
		directories \
		$(DEST_PATH)/chance_thunderstorm.rgba \
		$(DEST_PATH)/clear_sky_day.rgba \
		$(DEST_PATH)/clear_sky_night.rgba \
		$(DEST_PATH)/fog.rgba \
		$(DEST_PATH)/overcast.rgba \
		$(DEST_PATH)/partly_cloudy_day.rgba \
		$(DEST_PATH)/partly_cloudy_night.rgba \
		$(DEST_PATH)/rain.rgba \
		$(DEST_PATH)/sleet.rgba \
		$(DEST_PATH)/slight_rain.rgba \
		$(DEST_PATH)/slight_sleet.rgba \
		$(DEST_PATH)/slight_snow.rgba \
		$(DEST_PATH)/slight_snow_showers.rgba \
		$(DEST_PATH)/snow.rgba \
		$(DEST_PATH)/snow_showers.rgba \
		$(DEST_PATH)/thunderstorm.rgba \
		$(DEST_PATH)/unknown.rgba

directories: $(DEST_PATH)

MKDIR_P := mkdir -p

$(DEST_PATH):
	$(MKDIR_P) $(DEST_PATH)

$(DEST_PATH)/%.rgba: %.png
	$(MINRGB) rgba8888 $< $@
