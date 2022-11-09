NASM = nasm
MAME = ~/Downloads/mame0249-arm64/mame
SPLIT_ROM = bin/split_rom.py

BUILD_DIR = build
ORIGINAL_DIR = original
SRC_DIR = src
GAME = rtypeleo

ORIGINAL_BINS = rtl-sh0a.bin rtl-sl0a.bin \
       	rtl-c0.bin rtl-c1.bin rtl-c2.bin rtl-c3.bin \
        rtl-000.bin rtl-010.bin rtl-020.bin rtl-030.bin \
		rtl-da.bin



GAME_DIR = $(BUILD_DIR)/$(GAME)
COPIED_BINS = $(addprefix $(GAME_DIR)/, $(ORIGINAL_BINS))
BUILT_BINS = $(addprefix $(GAME_DIR)/, rtl-h0-c.bin rtl-l0-c.bin rtl-h1-d.bin rtl-l1-d.bin)


all: $(COPIED_BINS) $(BUILT_BINS)


$(COPIED_BINS): $(GAME_DIR)/%.bin: $(ORIGINAL_DIR)/$(GAME)/%.bin | $(GAME_DIR)
	cp $< $@

$(BUILD_DIR)/main.rom: $(SRC_DIR)/main.asm | $(BUILD_DIR)
	$(NASM) -f bin -o $@ $<

$(GAME_DIR)/rtl-h0-c.bin: $(BUILD_DIR)/main.rom
	$(SPLIT_ROM) $@ $< 0x00001 0x80000

$(GAME_DIR)/rtl-l0-c.bin: $(BUILD_DIR)/main.rom
	$(SPLIT_ROM) $@ $< 0x00000 0x80000

$(GAME_DIR)/rtl-h1-d.bin: $(BUILD_DIR)/main.rom
	$(SPLIT_ROM) $@ $< 0x80001 0x40000

$(GAME_DIR)/rtl-l1-d.bin: $(BUILD_DIR)/main.rom
	$(SPLIT_ROM) $@ $< 0x80000 0x40000

$(BUILD_DIR):
	mkdir -p $@

$(GAME_DIR):
	mkdir -p $@

run: $(COPIED_BINS) $(BUILT_BINS)
	$(MAME) -debug -rompath $(BUILD_DIR) $(GAME)