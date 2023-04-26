import struct
import math
import cmd_builder
import time

from cmd_builder import M92, Code, FillWord

num_codes = [ 24951, 24954, 24955, 24956, 24957, 24958, 24959, 24960, 24961, 24962 ]

class OBJ:
    def __init__(self, x, y, code, layer, cols=1, rows=1, color=0, prio=False, flip_x=False, flip_y=False):
        self.x = x
        self.y = y
        self.code = code
        self.layer = layer
        self.cols = cols
        self.rows = rows
        self.color = color
        self.prio = prio
        self.flip_x = flip_x
        self.flip_y = flip_y

    @staticmethod
    def from_bytes(bytes):
        #a, b, c, d = struct.unpack("<HHHH", bytes)
        d, c, b, a = struct.unpack(">HHHH", bytes)
        y = a & 0x1ff
        x = d & 0x1ff
        cols = 1 << ( ( a >> 11 ) & 3 )
        rows = 1 << ( ( a >>  9 ) & 3 )
        layer = ( ( a >>  13 ) & 7 )
        code = b
        color = c & 0x7f
        prio = ((c >> 7) & 1) == 1
        flip_x = ((c >> 8) & 1) == 1
        flip_y = ((c >> 9) & 1) == 1

        return OBJ(x, y, code, layer, cols, rows, color, prio, flip_x, flip_y)
    
    def to_bytes(self):
        cols = int(math.log2(self.cols))
        rows = int(math.log2(self.rows))
        a = ( ( self.layer & 7 ) << 13 ) | ( ( cols & 3 ) << 11 ) | ( ( rows & 3 ) << 9 ) | ( ( self.y & 0x1ff ) )
        b = self.code
        c = self.color & 0x7f
        if self.prio:
            c = c | ( 1 << 7 )
        if self.flip_x:
            c = c | ( 1 << 8 )
        if self.flip_y:
            c = c | ( 1 << 9 )
        d = self.x & 0x1ff
        return struct.pack("<HHHH", a, b, c, d) + bytearray((self.cols - 1) * 8)

    def __str__(self):
        return f"X:{self.x} Y:{self.y} Cols:{self.cols} Rows:{self.rows} Code:{self.code} Layer:{self.layer} Color:{self.color} Prio:{self.prio} FlipX:{self.flip_x} FlipY:{self.flip_y}"

    def to_csv(self):
        return f"{self.x},{self.y},{self.cols},{self.rows},{self.code},{self.layer},{self.color},{self.prio},{self.flip_x},{self.flip_y}"

"""
class CopySim:
    def __init__(self):
        self.regs = [ 0, 0, 0, 0 ]
        self.buffer = bytearray(0x800)

    def copy(self) -> bytearray:
        ram = 
"""
    

    


def write_obj_data(bytes):
    with open('data/obj.bin', 'wb') as fp:
        fp.write(bytes)

def obj_sheet(index):
    obj_data = b''
    for y in range(180, 340, 16):
        for x in range(96, 416, 16):
            obj = OBJ(x, y, index, 3, color = 0)
            obj_data = obj_data + obj.to_bytes()
            index = index + 1
    return obj_data

def layer_test(x = 160):
    obj_data = b''
    for num in range(0, 8):
        obj = OBJ(x, 288, num_codes[num], num, color = 2)
        obj_data = obj_data + obj.to_bytes()
        x = x + 16

    for num in range(0, 8):
        obj = OBJ(x, 280, num_codes[num], num, color = 0)
        obj_data = obj_data + obj.to_bytes()
        x = x - 16

    for num in range(0, 8):
        obj = OBJ(x, 260, num_codes[num], num, color = 2, cols=2)
        obj_data = obj_data + obj.to_bytes()
        x = x + 16


    return obj_data

if __name__ == '__main__':

    m92 = M92()

    # load palette
    # m92.mem[0xf8800:] = open('data/rtl-pal-small.bin', 'rb').read()
    # clear sprite memory
    # m92.mem[0xf8000:0xf8800] = FillWord(0)

    # setup sprite copy mode
    m92.mem[0xf9000] = 0xffe0
    m92.mem[0xf9002] = 0
    m92.mem[0xf9004] = 0x0011

    objs = []
    for ofs in range(0, 128, 8):
        obj = OBJ(104 + ofs, 250, 8 + ofs, 0, cols=1, rows=1)
        objs.append(obj)

    data_to_send = b''.join( x.to_bytes() for x in objs)
    # load sprite data
    m92.mem[0xf8000:0xf8800] = FillWord(0xe000)
    m92.mem[0xf8000:] = layer_test()

    # initiate dma
    m92.mem[0xf9008] = 0

    m92.mem[0xf9002] = 1

    print( "OBJ" )
    cmd_builder.print_words(0, m92.mem[0xf8000:0xf8100])

    m92.mem[0xf9002] = 0


    """
    print( "Buffer" )
    cmd_builder.print_words(0, m92.mem[0xf8000:0xf8040])

    m92.mem[0xf9002] = 1

    print( "OBJ" )
    cmd_builder.print_words(0, m92.mem[0xf8000:0xf8040])

    m92.mem[0xf9002] = 0
    """



