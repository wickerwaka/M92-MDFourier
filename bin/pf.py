import cmd_builder
from cmd_builder import out_byte, out_word, M92, FillWord
from obj import OBJ
import time

from typing import List

class Playfield:
    def __init__(self, m92: M92, index: int, addr: int, wide: bool):
        self.m92 = m92
        self.index = index
        self.addr = addr
        self.wide = wide
    
    def enable(self, en: bool, row_scroll=False):
        if en:
            reg = 0x00
            if row_scroll:
                reg |= 0x40
            if self.wide:
                reg |= 0x04
            reg |= (self.addr >> 14) & 0x03
            self.m92.conn.send(out_byte(0x98 + (self.index * 2), reg))
        else:
            self.m92.conn.send(out_byte(0x98 + (self.index * 2), 0x10))

    def set_xy(self, x: int, y: int):
        base_addr = 0x80 + (self.index * 8)
        cmds = out_word(base_addr, y) + out_word(base_addr + 4, x)
        self.m92.conn.send(cmds)

    def set_rowscroll(self, start_y: int, offsets: List[int]):
        start_addr = 0xdf400 + (0x400 * self.index) + (start_y * 2)
        data = b''
        for offset in offsets:
            data += offset.to_bytes(2, 'little')
        self.m92.mem[start_addr:] = data
    
    def set_tile(self, x: int, y: int, code: int, color: int, prio=0, flip_x=False, flip_y=False):
        attrib = (color & 0x7f) | ((prio & 3) << 7)
        if flip_x:
            attrib |= 0x20
        if flip_y:
            attrib |= 0x40
        data = code.to_bytes(2, 'little') + attrib.to_bytes(2, 'little')
        stride = 128 * 4 if self.wide else 64 * 4

        addr = 0xd0000 + self.addr + (stride * y) + (x * 4)
        self.m92.mem[addr:] = data


m92 = M92()

m92.mem[0xf8800:] = open('data/rtl-pal-small.bin', 'rb').read()
m92.mem[0xf9008] = 0

pf1 = Playfield(m92, 0, 0x4000, False)
pf2 = Playfield(m92, 1, 0x4000, False)
pf3 = Playfield(m92, 2, 0x4000, False)

pf1.enable(True)
pf2.enable(True)
pf3.enable(True)

m92.mem[0xd4000:0xd8000] = FillWord(0)

pf1.set_xy(0,0)
pf2.set_xy(0,16)
pf3.set_xy(0,32)

pf1.set_tile(10, 17, 0x10, 0x3, prio=2)
pf1.set_tile(49, 17, 0x12, 0x3, prio=2)
pf1.set_tile(10, 46, 0x11, 0x3, prio=2)
pf1.set_tile(49, 46, 0x13, 0x3, prio=2)

pf1.set_tile(11, 17, 0x18, 0x3, prio=2)
pf1.set_tile(48, 17, 0x18, 0x3, prio=2)
pf1.set_tile(11, 46, 0x18, 0x3, prio=2)
pf1.set_tile(48, 46, 0x18, 0x3, prio=2)

pf1.set_tile(10, 18, 0x18, 0x3, prio=2)
pf1.set_tile(49, 18, 0x18, 0x3, prio=2)
pf1.set_tile(10, 45, 0x18, 0x3, prio=2)
pf1.set_tile(49, 45, 0x18, 0x3, prio=2)


m92.mem[0xf9000] = 0xffe0
m92.mem[0xf9002] = 0
m92.mem[0xf9004] = 0x0000

objs = []
obj = OBJ(108, 176, 0x26a, 0, cols=1, rows=1)
objs.append(obj)

data_to_send = b''.join( x.to_bytes() for x in objs)
# load sprite data
m92.mem[0xf8000:0xf8800] = FillWord(0xe000)
m92.mem[0xf8000:] = data_to_send

# initiate dma
m92.mem[0xf9008] = 0
