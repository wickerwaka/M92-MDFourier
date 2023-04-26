from cmd_builder import M92
import time
import sys

def find_sounds(filename: str):
    data = open(filename, 'rb').read()
    start_ofs = 0
    in_sound = True

    sounds = []

    for ofs, sample in enumerate(data):
        if in_sound and sample == 0:
            in_sound = False
            sounds.append((start_ofs, ofs))
        if not in_sound and sample != 0:
            in_sound = True
            start_ofs = ofs
    
    if in_sound:
        sounds.append((start_ofs, len(data)))
    
    return sounds

class Channel:
    def __init__(self, m92: M92, index: int):
        self.mem = m92.audio
        self.index = index
        self.addr = index << 4

    def start(self, offset: int) -> 'Channel':
        self.mem[self.addr:] = bytes([ (offset >> 4) & 0xff, (offset >> 12) & 0xff ])
        return self

    def end(self, offset: int) -> 'Channel':
        self.mem[self.addr + 4:] = bytes([ (offset >> 4) & 0xff, (offset >> 12) & 0xff ])
        return self

    def rate(self, rate: int) -> 'Channel':
        self.mem[self.addr + 8] = rate & 0xff
        return self

    def volume(self, volume: int) -> 'Channel':
        self.mem[self.addr + 10] = volume & 0xff
        return self

    def key_on(self, flags: int = 0x02):
        self.mem[self.addr + 12] = flags
    
    def key_off(self):
        self.mem[self.addr + 12] = 0x00

    def playing(self) -> bool:
        return self.mem[self.addr + 14] != 0 
    

if __name__ == '__main__':
    #sounds = find_sounds('data/mdfourier-dac-16000.bin')
    #for s in sounds:
    #    print(hex(s[0]), hex(s[1]))
    #idx = int(sys.argv[1] or "1")
    #print(sounds[idx])
    m92 = M92()

    m92.audio[0xff] = int(sys.argv[1])

    #m92.mem[0xf9008] = 1
    #ch0 = Channel(m92, 0)
    #ch0.volume(0x3f).rate(0xc7).end(sounds[idx][1]).start(sounds[idx][0])

    #ch0.key_on(0x2)



# 0x00 - 700mv
# 0x07 - 1000mv
# 0x0f - 1450mv
# 0x17 - 1900mv
# 0x1f - 2400mv
# 0x27 - 2900mv
# 0x2f - 3300mv
# 0x37 - 3800mv
# 0x3f - 4300mv






