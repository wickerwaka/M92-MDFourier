NASM = nasm
MAME = bin/irem_emu
SPLIT_ROM = python3 bin/split_rom.py
WAVE2BIN = python3 bin/wave2bin.py

BUILD_DIR = build
ORIGINAL_DIR = original
SRC_DIR = src
DATA_DIR = data
GAME = nogame
MISTER_HOSTNAME=mister-dev

ORIGINAL_BINS_rtypeleo = rtl-c0.bin rtl-c1.bin rtl-c2.bin rtl-c3.bin \
		rtl-h0-c.bin rtl-l0-c.bin \
        rtl-000.bin rtl-010.bin rtl-020.bin rtl-030.bin \
		rtl-h1-d.bin rtl-l1-d.bin

ORIGINAL_BINS_gunforce = gf_h1-c.5l gf_l1-c.5j \
		gf_c0.rom gf_c1.rom gf_c2.rom gf_c3.rom \
		gf_000.rom gf_010.rom gf_020.rom gf_030.rom

ORIGINAL_BINS_nogame =


AUDIO_LOW_BIN_rtypeleo = rtl-sl0a.bin
AUDIO_HIGH_BIN_rtypeleo = rtl-sh0a.bin
SAMPLE_BIN_rtypeleo = rtl-da.bin

AUDIO_LOW_BIN_gunforce = gf_sl0.rom
AUDIO_HIGH_BIN_gunforce = gf_sh0.rom
SAMPLE_BIN_gunforce = gf-da.rom

AUDIO_LOW_BIN_nogame = mdfourier-sl0.bin
AUDIO_HIGH_BIN_nogame = mdfourier-sh0.bin
SAMPLE_BIN_nogame = mdfourier-da.bin

AUDIO_LOW_BIN = $(AUDIO_LOW_BIN_$(GAME))
AUDIO_HIGH_BIN = $(AUDIO_HIGH_BIN_$(GAME))
SAMPLE_BIN = $(SAMPLE_BIN_$(GAME))

GAME_DIR = $(BUILD_DIR)/$(GAME)
BUILT_BINS = $(addprefix $(GAME_DIR)/, $(AUDIO_LOW_BIN) $(AUDIO_HIGH_BIN) $(SAMPLE_BIN))
ORIGINAL_BINS = $(ORIGINAL_BINS_$(GAME))
COPIED_BINS = $(addprefix $(GAME_DIR)/, $(ORIGINAL_BINS))


all: $(COPIED_BINS) $(BUILT_BINS)

mister: $(GAME_DIR)/m92_mdfourier.zip
	scp $< root@$(MISTER_HOSTNAME):/media/fat/games/mame/

$(COPIED_BINS): $(GAME_DIR)/%: $(ORIGINAL_DIR)/$(GAME)/% | $(GAME_DIR)
	cp $< $@

$(BUILD_DIR)/audio.rom: src/audio.asm | $(BUILD_DIR)
	$(NASM) -f bin -o $@ -MD ${BUILD_DIR}/audio.dep -l $(BUILD_DIR)/audio.lst $<

$(GAME_DIR)/$(AUDIO_HIGH_BIN): $(BUILD_DIR)/audio.rom | $(GAME_DIR)
	$(SPLIT_ROM) $@ $< 0x00001 0x20000

$(GAME_DIR)/$(AUDIO_LOW_BIN): $(BUILD_DIR)/audio.rom | $(GAME_DIR)
	$(SPLIT_ROM) $@ $< 0x00000 0x20000

$(GAME_DIR)/$(SAMPLE_BIN): $(DATA_DIR)/mdfourier-dac-16000_nosync.wav | $(GAME_DIR)
	$(WAVE2BIN) $@ $<

$(GAME_DIR)/m92_mdfourier.zip: $(BUILT_BINS)
	zip -j - $^ > $@

$(BUILD_DIR):
	mkdir -p $@

$(GAME_DIR):
	mkdir -p $@

.PHONY: original flash_low flash_high run debug

debug: $(COPIED_BINS) $(BUILT_BINS)
	mkdir -p mame
	cd mame && ../$(MAME) -window -nomaximize -resolution0 640x480 -debug -rompath ../$(BUILD_DIR) $(GAME)

flash_low: $(GAME_DIR)/$(AUDIO_LOW_BIN)
	cat $< $< $< $< > $<.4x
	minipro -p W27C020 -w $<.4x

flash_high: $(GAME_DIR)/$(AUDIO_HIGH_BIN)
	cat $< $< $< $< > $<.4x
	minipro -p W27C020 -w $<.4x

flash_sample: $(GAME_DIR)/$(SAMPLE_BIN)
	minipro -p W27C020 -w $<

-include $(BUILD_DIR)/audio.dep
