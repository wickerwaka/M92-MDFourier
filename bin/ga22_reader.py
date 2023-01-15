
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
    
    def __str__(self):
        if self.value:
            return "High"
        else:
            return "Low"


def parse_buffer_address(row):
    names = [ 'a3', 'a0', 'a4', 'a1', 'a2', 'a5', 'a6', 'a7', 'a8', 'a9', 'a10', 'a11', 'a12' ]
    addr = 0
    for n in names:
        if row[n]:
            addr = (addr << 1) | 1
        else:
            addr = (addr << 1)
    return addr

def parse_hcount(row):
    names = [ 'H0', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'H7', 'H8', 'H9' ]
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

def parse_pf_addr(row):
    names = [ 'A14', 'A13', 'A12', 'A11', 'A10', 'A9', 'A8', 'A7', 'A6', 'A5', 'A4', 'A3', 'A2', 'A1', 'A0' ]
    addr = 0
    for n in names:
        if row[n]:
            addr = (addr << 1) | 1
        else:
            addr = (addr << 1)
    return addr << 1

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
            row['time'] = float(values[0])
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

def hcount(fname):
    rows = read_csv(fname)
    prev_count = -1

    for row in rows:
        count = parse_hcount(row)
        if count != prev_count:
            print(count)
        prev_count = count

def pf_addrs(fname):
    rows = read_csv(fname)
    cyc = 0
    frame_count = 0
    for row in rows:
        if row['V_PULSE'].negedge():
            frame_count += 1

        if frame_count != 2:
            continue

        if not row['CLK_PIXEL'].posedge():
            continue

        if not row['H_PULSE']:
            cyc = 0
        else:
            cyc += 1
        
        if cyc >= 0:
            x = cyc - 1
            addr = parse_pf_addr(row)
            print(f'X: {x} {addr:04x}, {row["V_PULSE"]}, {row["VBLANK"]}, {row["SYNC"]}')

        


#obj_transfer_log(sys.argv[1])
#hcount(sys.argv[1])
pf_addrs(sys.argv[1])