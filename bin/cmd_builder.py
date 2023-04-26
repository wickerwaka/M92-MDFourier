#! /usr/bin/env python3

import sys
import struct
import serial
import serial.tools.list_ports
import readline
import os
import time
import random
import tempfile
import subprocess
import paramiko

class CommandException(Exception):
    pass

class CommsException(Exception):
    pass

class CmdWithResponse:
    def __init__(self, cmd_data, resp_size, handler):
        self.cmd_data = cmd_data
        self.resp_size = resp_size
        self.handler = handler

def segment(addr):
    return ( addr & 0xf0000 ) >> 4

def offset(addr):
    return addr & 0xffff

def cmd(id, fmt, *args, data=None):
    payload = struct.pack(fmt, *args)
    if data:
        payload = payload + data
    header = struct.pack("<BH", id, len(payload))
    return header + payload

def show_memory_byte(addr, count):
    return cmd(1, "<HHH", segment(addr), offset(addr), count)

def show_memory_word(addr, count):
    return cmd(2, "<HHH", segment(addr), offset(addr), count)

def write_bytes(addr, data):
    return cmd(3, "<HH", segment(addr), offset(addr), data=data)

def write_words(addr, data):
    return cmd(4, "<HH", segment(addr), offset(addr), data=data)

def read_bytes(addr, count):
    return cmd(12, "<HHH", segment(addr), offset(addr), count)

def read_words(addr, count):
    return cmd(13, "<HHH", segment(addr), offset(addr), count)

def out_byte(port, byte):
    return cmd(5, "<HB", port, byte & 0xff)

def out_word(port, word):
    return cmd(6, "<HH", port, word & 0xffff)

def in_byte(port):
    return cmd(7, "<H", port)

def in_word(port):
    return cmd(8, "<H", port)

def far_call(addr):
    return cmd(9, "<HH", offset(addr), segment(addr))

def memsetb(addr, fill, count):
    return cmd(10, "<HHHB", segment(addr), offset(addr), count, fill)

def memsetw(addr, fill, count):
    return cmd(14, "<HHHH", segment(addr), offset(addr), count, fill)

def write_audio(addr, data):
    return cmd(15, "<H", addr & 0x00ff, data=data)

def read_audio(addr, count):
    return cmd(16, "<HH", addr & 0x00ff, count)

def print_at(x, y, s, clear=False):
    str_bytes = s.upper().encode() + b'\x00'
    return cmd(11, "<?BB", clear, x, y, data=str_bytes)

def load_file_bytes(addr, fname):
    data = open(fname, 'rb').read()
    return write_bytes(addr, data)

def load_file_words(addr, fname):
    data = open(fname, 'rb').read()
    return write_words(addr, data)

def exec_script(filename):
    cmds = []
    with open(filename, "rt") as fp:
        for idx, line in enumerate(fp.readlines()):
            try:
                cmd_data = process_line(line)
                cmds.extend(cmd_data)
            except CommandException as e:
                print(f"{filename}:{idx+1} - {e}")
                return []
    return cmds

def print_hex(addr, data, sz):
    for ofs in range(0, len(data), 8):
        end = min(len(data), ofs + 8)
        b = data[ofs:end]
        ints = []
        for x in range(0,len(b),sz):
            ints.append(int.from_bytes(b[x:x+sz], byteorder='little'))

        if sz == 1:
            s = f"{addr+ofs:05X}  " + " ".join( f"{x:02X}" for x in ints )
        else:
            s = f"{addr+ofs:05X}  " + " ".join( f"{x:04X}" for x in ints )
        print(s)

def print_bytes(addr, data):
    print_hex(addr, data, 1)

def print_words(addr, data):
    print_hex(addr, data, 2)

def process_line(line):
    line = line.strip()
    parts = line.split()
    if len(parts) == 0:
        return b''

    name = parts[0]

    str_args = name in [ 'loadb', 'loadw', 'exec' ]

    args = []
    for i, x in enumerate(parts[1:]):
        try:
            if str_args:
                args.append(x)
            else:
                args.append(int(x, 0))
        except ValueError:
            raise CommandException(f"Could not parse arg {i+1} '{x}'")
        
    try:
        if name == "memb":
            return [ show_memory_byte(args[0], args[1]) ]
        elif name == "memw":
            return [ show_memory_word(args[0], args[1]) ]
        elif name == "writeb":
            return [ write_bytes(args[0], b''.join([x.to_bytes(1, byteorder='little') for x in args[1:]])) ]
        elif name == "writew":
            return [ write_words(args[0], b''.join([x.to_bytes(2, byteorder='little') for x in args[1:]])) ]
        elif name == "outb":
            return [ out_byte(args[0], args[1]) ]
        elif name == "outw":
            return [ out_word(args[0], args[1]) ]
        elif name == "inb":
            return [ in_byte(args[0]) ]
        elif name == "inw":
            return [ in_word(args[0]) ]
        elif name == "call":
            return [ far_call(args[0]) ]
        elif name == "memsetb":
            return [ memsetb(args[0], args[1], args[2]) ]
        elif name == "memsetw":
            return [ memsetw(args[0], args[1], args[2]) ]
        elif name == "writea":
            return [ write_audio(args[0], b''.join([x.to_bytes(1, byteorder='little') for x in args[1:]])) ]
        elif name == "reada":
            count = min(args[1], 256)
            return [ CmdWithResponse( read_audio(args[0], count), count, lambda x: print_bytes(args[0], x) ) ]
        elif name == "loadb":
            return [ load_file_bytes(int(args[0], 0), args[1]) ]
        elif name == "loadw":
            return [ load_file_words(int(args[0], 0), args[1]) ]
        elif name == "exec":
            return exec_script(args[0])
        elif name == "readb":
            count = min(args[1], 256)
            return [ CmdWithResponse( read_bytes(args[0], count), count, lambda x: print_bytes(args[0], x) ) ]
        elif name == "readw":
            count = min(args[1], 128)
            return [ CmdWithResponse( read_words(args[0], count), count * 2, lambda x: print_words(args[0], x) ) ]



        else:
            raise CommandException(f"Unknown command '{name}'")
    except IndexError:
        raise CommandException(f"Insufficient arguments for '{name}'")
    except ValueError:
        raise CommandException(f"Could not parse arguments")

    return []


MAGIC = [ 0xfa, 0x23, 0x68, 0xaf ]
STROBE = 0x10
BLK_START = 0x20
BLK_END = 0x40

class Connection:
    def __init__(self, ser=None, mister=None):
        self.ser = ser
        self.mister_client = None
        self.mister_stdin = None

        client = paramiko.client.SSHClient()
        client.load_system_host_keys()
        client.connect('mister-dev', username='root')
        stdin, stdout, stderr = client.exec_command("cat > /dev/MiSTer_dbg")
        self.mister_client = client
        self.mister_stdin = stdin


    def expect_resp(self, seq, expected):
        while True:
            resp = self.ser.read_until().decode('utf-8', errors='replace').strip()
            if not resp.startswith("DEBUG:"):
                break
            print(resp)
        
        sequence_str, _, status = resp.partition(' ')
        
        try:
            sequence = int(sequence_str)
        except ValueError:
            raise CommsException(f"Unrecognized sequence number: {resp}")
        
        if sequence != seq:
            raise CommsException(f"Unexpected sequence number: {sequence} != {seq} '{resp}'")
        
        if status != expected:
            raise CommandException(f"Unexpected status: {status} != {expected} '{resp}'")

    
    def send(self, data, resp_len = 0):
        if self.ser:
            seq = random.randint(0, 127)
            for ofs in range(0, len(data), 32):
                end = min(len(data), ofs+32)
                chunk = data[ofs:end]
                pkt = struct.pack("<BBBBBBH", MAGIC[0], MAGIC[1], MAGIC[2], MAGIC[3], seq & 0x7f, len(chunk) + 2, ofs & 0xffff) + chunk
                self.ser.write(pkt)
                self.expect_resp(seq, "ACK")
                seq = ( seq + 1 ) & 0x7f
            
            pkt = struct.pack("<BBBBBBHHH", MAGIC[0], MAGIC[1], MAGIC[2], MAGIC[3], seq & 0x7f, 6, 0xffff, len(data), resp_len)
            self.ser.write(pkt)
            self.expect_resp(seq, "SENT")

            if resp_len:
                resp = self.ser.read(resp_len)
                # expect_resp(ser, seq, "RESP")
                return resp
        
        if self.mister_stdin and resp_len == 0:
            self.send_mister_data(data)
            return None

    def send_mister_data(self, data):
        enc = []

        enc.append(BLK_START)
        enc.append(0)

        for b in data:
            enc.append(STROBE | (b & 0x0f))
            enc.append(0)
            enc.append(STROBE | (b >> 4))
            enc.append(0)

        enc.append(BLK_END)
        enc.append(0)

        out = b''.join( ((x ^ 0xf0) & 0xff).to_bytes(1, 'little') for x in enc )

        self.mister_stdin.write(out)
        self.mister_stdin.flush()

        time.sleep(.1)
        
        #subprocess.run(["ssh", "root@mister-dev", "cat > /dev/MiSTer_dbg"], input=out)



class FillWord:
    def __init__(self, value):
        self.value = value

class FillByte:
    def __init__(self, value):
        self.value = value


class MemoryByteView:
    def __init__(self, conn: Connection):
        self.conn = conn
    
    def __len__(self):
        return 0x100000
    
    def __getitem__(self, key):
        if type(key) == int:
            if key < 0 or key >= 0x100000:
                raise IndexError()
            resp = self.conn.send(read_words(key, 1), 2)
            return int.from_bytes(resp, 'little')
        elif type(key) == slice:
            full_data = b''
            for start in range(key.start, key.stop, 256):
                end = min(start+256, key.stop)
                sz = end - start
                if ( start & 1 ) == 0 and ( sz & 1 ) == 0:
                    cmd = read_words(start, int(sz / 2))
                else:
                    cmd = read_bytes(start, sz)
                full_data += self.conn.send(cmd, sz)
            
            return full_data[::key.step]
        else:
            raise TypeError()

    def __setitem__(self, key, value):
        if type(key) == int:
            if key < 0 or key >= 0x100000:
                raise IndexError()
            self.conn.send(write_words(key, value.to_bytes(2, 'little')))
        elif type(key) == slice:
            if type(value) == FillWord:
                self.conn.send(memsetw(key.start, value.value, int((key.stop - key.start) / 2)))
            elif type(value) == FillByte:
                self.conn.send(memsetb(key.start, value.value, key.stop - key.start))
            else:
                for start in range(0, len(value), 1024):
                    end = min(start+1024, len(value))
                    sz = end - start
                    if ( key.start & 1 ) == 0 and ( sz & 1 ) == 0:
                        self.conn.send(write_words(key.start + start, value[start:end]))
                    else:
                        self.conn.send(write_bytes(key.start + start, value[start:end]))
        else:
            raise TypeError()

class AudioMemoryView:
    def __init__(self, conn: Connection):
        self.conn = conn
    
    def __len__(self):
        return 0x80
    
    def __getitem__(self, key):
        if type(key) == int:
            if key < 0 or key >= 0x80:
                raise IndexError()
            resp = self.conn.send(read_audio(key, 1), 1)
            return int.from_bytes(resp, 'little')
        elif type(key) == slice:
            full_data = b''
            start = key.start & 0xfe
            end = key.stop
            sz = int(( end - start ) / 2)
            return self.conn.send(read_audio(start, sz), sz)
        else:
            raise TypeError()

    def __setitem__(self, key, value):
        if type(key) == int:
            if key < 0 or key > 0xff:
                raise IndexError()
            self.conn.send(write_audio(key, value.to_bytes(1, 'little')))
        elif type(key) == slice:
            self.conn.send(write_audio(key.start, value))
        else:
            raise TypeError()

class MemoryWordView:
    def __init__(self, conn: Connection):
        self.conn = conn
    
    def __len__(self):
        return 0x100000
    
    def __getitem__(self, key):
        if type(key) == int:
            if key < 0 or key >= 0x100000:
                raise IndexError()
            data = self.conn.send(read_words(key, 1), 2)
            return int.from_bytes(data[0:2], 'little')
        else:
            raise TypeError()

    def __setitem__(self, key, value):
        if type(key) == int:
            if key < 0 or key >= 0x100000:
                raise IndexError()
            self.conn.send(write_words(key, value.to_bytes(2, 'little')))
        else:
            raise TypeError()

class AssemblyException(Exception):
    pass

class Code:
    def __init__(self, org: int, code: str):
        self.org = org
        self.code = code
        self.assembled = self.assemble()
    
    def assemble(self):
        # Run Nasm
        fd, source = tempfile.mkstemp(".S", "assembly", os.getcwd())
        os.write(fd, f"CPU 186\nBITS 16\n\nORG 0x{self.org:x}\n".encode("utf-8"))
        os.write(fd, self.code.encode("utf-8"))
        os.close(fd)
        target = os.path.splitext(source)[0]
        try:
            subprocess.check_output(["nasm", "-f", "bin", "-o", target, source], stderr=subprocess.STDOUT )
        except subprocess.CalledProcessError as e:
            lines = e.output.decode('utf-8').split('\n')
            errors = ''
            for line in lines:
                parts = line.split(':', 2)
                if len(parts) == 3:
                    errors += f"\n{int(parts[1]) - 3}: {parts[2].strip()}"
            raise AssemblyException(errors)

        os.unlink(source)
        assembled = open(target,"rb").read()
        os.unlink(target)
        return assembled


class M92:
    def __init__(self, device_path=None):
        self.conn = find_port(device_path)
        time.sleep(0.1) 
        self.mem = MemoryByteView(self.conn)
        self.memw = MemoryWordView(self.conn)
        self.audio = AudioMemoryView(self.conn)
    
    def execute(self, code: Code):
        self.memb[code.org:] = code.assembled
        self.conn.send(far_call(code.org))




def find_port(device_path=None) -> Connection:
    if device_path:
        print(f"Using {device_path}")
        return Connection(serial.Serial(device_path))
    
    ports = list(serial.tools.list_ports.grep(".*usbmodem"))
    if len(ports) > 0:
        port = ports[0].device
        print(f"Using {port}")
        return Connection(serial.Serial(port, timeout=5, baudrate=115200, dsrdtr=True))
    
    print("Could not find a serial port")
    return Connection(None, None)



def interactive(device_path=None):
    conn = find_port(device_path)

    histfile = os.path.join(os.path.expanduser("~"), ".m92con_history")
    try:
        readline.read_history_file(histfile)
        readline.set_history_length(1000)
    except FileNotFoundError:
        pass

    while True:
        try:
            cmd_line = input("> ")
        except KeyboardInterrupt:
            print("Quit")
            readline.write_history_file(histfile)
            return

        try:
            cmds = process_line(cmd_line)
        except CommandException as e:
            print(e)
        else:
            for cmd in cmds:
                resp_data = None
                try:
                    if type(cmd) == CmdWithResponse:
                        resp_data = conn.send(cmd.cmd_data, cmd.resp_size)
                    else:
                        conn.send(cmd)
                except CommsException as e:
                    print( f"ERROR: {e}")
                else:
                    print( "OK" )

                    if type(cmd) == CmdWithResponse:
                        cmd.handler(resp_data)



if __name__ == '__main__':
    # send_mister_data(b'')
    if len(sys.argv) == 1:
        interactive()

