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
		rtl-da.bin \
		rtl-h1-d.bin rtl-l1-d.bin

SRCS = $(SRC_DIR)/main.asm $(SRC_DIR)/util.asm $(SRC_DIR)/constants.asm $(SRC_DIR)/text.asm $(SRC_DIR)/comms.asm $(SRC_DIR)/cmd.asm


GAME_DIR = $(BUILD_DIR)/$(GAME)
COPIED_BINS = $(addprefix $(GAME_DIR)/, $(ORIGINAL_BINS))
BUILT_BINS = $(addprefix $(GAME_DIR)/, rtl-h0-c.bin rtl-l0-c.bin)


all: $(COPIED_BINS) $(BUILT_BINS)


$(COPIED_BINS): $(GAME_DIR)/%.bin: $(ORIGINAL_DIR)/$(GAME)/%.bin | $(GAME_DIR)
	cp $< $@

$(BUILD_DIR)/main.rom: $(SRCS) | $(BUILD_DIR)
	$(NASM) -f bin -o $@ $<

$(GAME_DIR)/rtl-h0-c.bin: $(BUILD_DIR)/main.rom
	$(SPLIT_ROM) $@ $< 0x00001 0x80000

$(GAME_DIR)/rtl-l0-c.bin: $(BUILD_DIR)/main.rom
	$(SPLIT_ROM) $@ $< 0x00000 0x80000

#$(GAME_DIR)/rtl-h1-d.bin: $(BUILD_DIR)/main.rom#
#	$(SPLIT_ROM) $@ $< 0x80001 0x40000

#$(GAME_DIR)/rtl-l1-d.bin: $(BUILD_DIR)/main.rom
#	$(SPLIT_ROM) $@ $< 0x80000 0x40000

$(BUILD_DIR):
	mkdir -p $@

$(GAME_DIR):
	mkdir -p $@

.PHONY: original flash_low flash_high run debug

debug: $(COPIED_BINS) $(BUILT_BINS)
	$(MAME) -window -nomaximize -resolution0 640x480 -debug -rompath $(BUILD_DIR) $(GAME)

run: $(COPIED_BINS) $(BUILT_BINS)
	$(MAME) -window -rompath $(BUILD_DIR) $(GAME)

flash_low: $(GAME_DIR)/rtl-l0-c.bin
	minipro -p W27C020 -w $<

flash_high: $(GAME_DIR)/rtl-h0-c.bin
	minipro -p W27C020 -w $<

original:
	$(MAME) -debug -rompath $(ORIGINAL_DIR) $(GAME)

