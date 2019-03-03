# Map JSON data

MAPS_DIR = data/maps
LAYOUTS_DIR = data/layouts

MAP_DIRS := $(dir $(wildcard $(MAPS_DIR)/*/))
MAP_CONNECTIONS := $(patsubst $(MAPS_DIR)/%/,$(MAPS_DIR)/%/connections.inc,$(MAP_DIRS))
MAP_EVENTS := $(patsubst $(MAPS_DIR)/%/,$(MAPS_DIR)/%/events.inc,$(MAP_DIRS))
MAP_HEADERS := $(patsubst $(MAPS_DIR)/%/,$(MAPS_DIR)/%/header.inc,$(MAP_DIRS))

$(BUILD_DIR)/data/maps.o: data/maps.s $(LAYOUTS_DIR)/layouts.inc $(LAYOUTS_DIR)/layouts_table.inc $(MAPS_DIR)/headers.inc $(MAPS_DIR)/groups.inc $(MAPS_DIR)/connections.inc $(MAP_CONNECTIONS) $(MAP_HEADERS)
	$(PREPROC) $< charmap.txt | $(CPP) -I include | $(AS) $(ASFLAGS) -o $@
$(BUILD_DIR)/data/map_events.o: data/map_events.s $(MAPS_DIR)/events.inc $(MAP_EVENTS)
	$(PREPROC) $< charmap.txt | $(CPP) -I include | $(AS) $(ASFLAGS) -o $@

$(MAPS_DIR)/%/header.inc: $(MAPS_DIR)/%/map.json
	$(MAPJSON) map ruby $< $(LAYOUTS_DIR)/layouts.json
$(MAPS_DIR)/%/events.inc: $(MAPS_DIR)/%/header.inc ;
$(MAPS_DIR)/%/connections.inc: $(MAPS_DIR)/%/events.inc ;

$(MAPS_DIR)/groups.inc: $(MAPS_DIR)/map_groups.json
	$(MAPJSON) groups ruby $<
$(MAPS_DIR)/connections.inc: $(MAPS_DIR)/groups.inc ;
$(MAPS_DIR)/events.inc: $(MAPS_DIR)/connections.inc ;
$(MAPS_DIR)/headers.inc: $(MAPS_DIR)/events.inc ;
include/constants/map_groups.h: $(MAPS_DIR)/headers.inc ;

$(LAYOUTS_DIR)/layouts.inc: $(LAYOUTS_DIR)/layouts.json
	$(MAPJSON) layouts ruby $<
$(LAYOUTS_DIR)/layouts_table.inc: $(LAYOUTS_DIR)/layouts.inc ;
include/constants/layouts.h: $(LAYOUTS_DIR)/layouts_table.inc ;
