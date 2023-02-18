NASM = nasm
MAME = bin/irem_emu
SPLIT_ROM = bin/split_rom.py

BUILD_DIR = build
ORIGINAL_DIR = original
SRC_DIR = src
GAME = rtypeleo
MISTER_HOSTNAME=mister-dev

ORIGINAL_BINS_rtypeleo = rtl-c0.bin rtl-c1.bin rtl-c2.bin rtl-c3.bin \
        rtl-000.bin rtl-010.bin rtl-020.bin rtl-030.bin \
		rtl-da.bin \
		rtl-h1-d.bin rtl-l1-d.bin

ORIGINAL_BINS_gunforce = gf_h1-c.5l gf_l1-c.5j \
		gf_c0.rom gf_c1.rom gf_c2.rom gf_c3.rom \
		gf_000.rom gf_010.rom gf_020.rom gf_030.rom \
		gf-da.rom

MAIN_LOW_BIN_rtypeleo = rtl-l0-c.bin
MAIN_HIGH_BIN_rtypeleo = rtl-h0-c.bin
AUDIO_LOW_BIN_rtypeleo = rtl-sl0a.bin
AUDIO_HIGH_BIN_rtypeleo = rtl-sl0a.bin

MAIN_LOW_BIN_gunforce = gf_l0-c.5f
MAIN_HIGH_BIN_gunforce = gf_h0-c.5m
AUDIO_LOW_BIN_gunforce = gf_sl0.rom
AUDIO_HIGH_BIN_gunforce = gf_sh0.rom

MAIN_LOW_BIN = $(MAIN_LOW_BIN_$(GAME))
MAIN_HIGH_BIN = $(MAIN_HIGH_BIN_$(GAME))
AUDIO_LOW_BIN = $(AUDIO_LOW_BIN_$(GAME))
AUDIO_HIGH_BIN = $(AUDIO_HIGH_BIN_$(GAME))

GAME_DIR = $(BUILD_DIR)/$(GAME)
BUILT_BINS = $(addprefix $(GAME_DIR)/, $(MAIN_LOW_BIN) $(MAIN_HIGH_BIN) $(AUDIO_LOW_BIN) $(AUDIO_HIGH_BIN))
ORIGINAL_BINS = $(ORIGINAL_BINS_$(GAME))
COPIED_BINS = $(addprefix $(GAME_DIR)/, $(ORIGINAL_BINS))


all: $(COPIED_BINS) $(BUILT_BINS)

mister: $(GAME_DIR)/m92test.zip
	scp $< root@$(MISTER_HOSTNAME):/media/fat/games/mame/

$(COPIED_BINS): $(GAME_DIR)/%: $(ORIGINAL_DIR)/$(GAME)/% | $(GAME_DIR)
	cp $< $@

$(BUILD_DIR)/main.rom: src/main.asm | $(BUILD_DIR)
	$(NASM) -f bin -o $@ -MD ${BUILD_DIR}/main.dep -l $(BUILD_DIR)/main.lst $<

$(BUILD_DIR)/audio.rom: src/audio.asm | $(BUILD_DIR)
	$(NASM) -f bin -o $@ -MD ${BUILD_DIR}/audio.dep -l $(BUILD_DIR)/audio.lst $<

$(GAME_DIR)/$(MAIN_HIGH_BIN): $(BUILD_DIR)/main.rom
	$(SPLIT_ROM) $@ $< 0x00001 0x80000

$(GAME_DIR)/$(MAIN_LOW_BIN): $(BUILD_DIR)/main.rom
	$(SPLIT_ROM) $@ $< 0x00000 0x80000

$(GAME_DIR)/$(AUDIO_HIGH_BIN): $(BUILD_DIR)/audio.rom
	$(SPLIT_ROM) $@ $< 0x00001 0x20000

$(GAME_DIR)/$(AUDIO_LOW_BIN): $(BUILD_DIR)/audio.rom
	$(SPLIT_ROM) $@ $< 0x00000 0x20000

$(GAME_DIR)/m92test.zip: $(BUILD_DIR)/main.rom
	zip -j - $< > $@

$(BUILD_DIR):
	mkdir -p $@

$(GAME_DIR):
	mkdir -p $@

.PHONY: original flash_low flash_high run debug


debug: $(COPIED_BINS) $(BUILT_BINS)
	mkdir -p mame
	cd mame && ../$(MAME) -window -nomaximize -resolution0 640x480 -debug -rompath ../$(BUILD_DIR) $(GAME)

run: $(COPIED_BINS) $(BUILT_BINS)
	mkdir -p mame
	cd mame && ../$(MAME) -window -rompath ../$(BUILD_DIR) $(GAME)

flash_low: $(GAME_DIR)/$(MAIN_LOW_BIN)
	minipro -p W27C020 -w $<

flash_high: $(GAME_DIR)/$(MAIN_HIGH_BIN)
	minipro -p W27C020 -w $<

original:
	mkdir mame
	cd mame
	$(MAME) -debug -rompath $(ORIGINAL_DIR) $(GAME)

-include $(BUILD_DIR)/main.dep
-include $(BUILD_DIR)/audio.dep
