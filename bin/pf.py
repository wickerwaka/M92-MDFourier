import cmd_builder
from cmd_builder import out_byte, send_data, out_word, M92, FillWord
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
            send_data(self.m92.conn, out_byte(0x98 + (self.index * 2), reg))
        else:
            send_data(self.m92.conn, out_byte(0x98 + (self.index * 2), 0x10))

    def set_xy(self, x: int, y: int):
        base_addr = 0x80 + (self.index * 8)
        cmds = out_word(base_addr, y) + out_word(base_addr + 4, x)
        send_data(self.m92.conn, cmds)

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

pf1 = Playfield(m92, 0, 0x4000, False)
pf2 = Playfield(m92, 1, 0x4000, False)
pf3 = Playfield(m92, 2, 0x4000, False)

pf1.enable(True)
pf2.enable(False)
pf3.enable(False)

m92.mem[0xd4000:0xd8000] = FillWord(0)

pf1.set_xy(0,0)

pf1.set_tile(10, 17, 5, 0x0, prio=2)
pf1.set_tile(49, 17, 5, 0x0, prio=2)
pf1.set_tile(10, 46, 5, 0x0, prio=2)
pf1.set_tile(49, 46, 5, 0x0, prio=2)

pf1.set_tile(11, 17, 5, 0x2, prio=2)
pf1.set_tile(48, 17, 5, 0x2, prio=2)
pf1.set_tile(11, 46, 5, 0x2, prio=2)
pf1.set_tile(48, 46, 5, 0x2, prio=2)

pf1.set_tile(10, 18, 5, 0x2, prio=2)
pf1.set_tile(49, 18, 5, 0x2, prio=2)
pf1.set_tile(10, 45, 5, 0x2, prio=2)
pf1.set_tile(49, 45, 5, 0x2, prio=2)
