
import sys

class State:
    def __init__(self, value : bool, prev_value = None):
        self.value = value
        self.prev_value = prev_value

    def __bool__(self):
        return self.value
    
    def posedge(self) -> bool:
        if self.prev_value is None:
            return False
        return self.value and not self.prev_value
    
    def negedge(self) -> bool:
        if self.prev_value is None:
            return False
        return self.prev_value and not self.value
    
    def edge(self) -> bool:
        if self.prev_value is None:
            return False
        return self.value != self.prev_value


def parse_buffer_address(row):
    names = [ 'a3', 'a0', 'a4', 'a1', 'a2', 'a5', 'a6', 'a7', 'a8', 'a9', 'a10', 'a11', 'a12' ]
    addr = 0
    for n in names:
        if row[n]:
            addr = (addr << 1) | 1
        else:
            addr = (addr << 1)
    return addr

def parse_obj_address(row):
    names = [ 'obj_a10', 'obj_a9','obj_a8','obj_a7','obj_a6','obj_a5','obj_a4','obj_a3','obj_a2','obj_a1', 'obj_a0']
    addr = 0
    for n in names:
        if row[n]:
            addr = (addr << 1) | 1
        else:
            addr = (addr << 1)
    return addr

def read_csv(fname):
    with open(fname) as fp:
        while True:
            line = fp.readline()
            if line.startswith(';'):
                continue
            names = [ x.strip() for x in line.split(',') ]
            break

        rows = []
        prev_row = None
        while True:
            line = fp.readline().strip()
            if len(line) == 0:
                break
            values = line.split(',')
            row = {}
            for k, v in zip(names[1:], values[1:]):
                if prev_row:
                    prev_value = prev_row[k].value
                else:
                    prev_value = None
                row[k] = State(v == "1", prev_value)
            rows.append(row)
            prev_row = row
        
        return rows

def obj_transfer_log(fname):
    rows = read_csv(fname)
    prev_addr = -1

    for i, row in enumerate(rows):
        print( f"Rast: {parse_obj_address(row):03x}")
        if not row['DMA_BUSY']:
            continue
        if row['a4']:
            continue

        src_addr = parse_buffer_address(row)
        if prev_addr != src_addr:
            print(f"Read {src_addr:03x}")
            prev_addr = src_addr

        if row['/obj_we'].posedge():
            dest_addr = parse_obj_address(row)
            print(f"Write {dest_addr:03x}")

        #src_addr = parse_buffer_address(rows[i-4])
        #print(f"{src_addr:03x} ({int(src_addr / 4)}) -> {dest_addr:03x}")

obj_transfer_log(sys.argv[1])
