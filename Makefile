# SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
# SPDX-License-Identifier: Apache-2.0

SUBDIRS = icons

.PHONY: subdirs $(SUBDIRS) clean

subdirs: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean:
	rm -f priv/icons/black_weather_128/*.rgba
	rm -f priv/icons/black_weather_64/*.rgba
	rm -f priv/icons/data_icons_32/*.rgba
