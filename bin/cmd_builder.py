#! /usr/bin/env python3

import sys
import struct
import serial
import serial.tools.list_ports
import readline
import os
import time
import random

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
    return cmd(5, "<HB", port, byte)

def out_word(port, word):
    return cmd(6, "<HH", port, word)

def in_byte(port):
    return cmd(7, "<H", port)

def in_word(port):
    return cmd(8, "<H", port)

def far_call(addr):
    return cmd(9, "<HH", offset(addr), segment(addr))

def memset(addr, fill, count):
    return cmd(10, "<HHHB", segment(addr), offset(addr), count, fill)

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
    for ofs in range(0, len(data), 16):
        end = min(len(data), ofs + 16)
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
        elif name == "memset":
            return [ memset(args[0], args[1], args[2]) ]
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

def expect_resp(ser, seq, expected):
    while True:
        resp = ser.read_until().decode('utf-8', errors='replace').strip()
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

    

def send_data(ser, data, resp_len = 0):
    seq = random.randint(0, 127)
    for ofs in range(0, len(data), 32):
        end = min(len(data), ofs+32)
        chunk = data[ofs:end]
        pkt = struct.pack("<BBBBBBH", MAGIC[0], MAGIC[1], MAGIC[2], MAGIC[3], seq & 0x7f, len(chunk) + 2, ofs & 0xffff) + chunk
        ser.write(pkt)
        expect_resp(ser, seq, "ACK")
        seq = ( seq + 1 ) & 0x7f
    
    pkt = struct.pack("<BBBBBBHHH", MAGIC[0], MAGIC[1], MAGIC[2], MAGIC[3], seq & 0x7f, 6, 0xffff, len(data), resp_len)
    ser.write(pkt)
    expect_resp(ser, seq, "SENT")

    if resp_len:
        resp = ser.read(resp_len)
        # expect_resp(ser, seq, "RESP")
        return resp
    else:
        return None

def find_port(device_path=None):
    if device_path:
        print(f"Using {device_path}")
        return serial.Serial(device_path)
    
    ports = list(serial.tools.list_ports.grep(".*usbmodem"))
    if len(ports) > 0:
        port = ports[0].device
        print(f"Using {port}")
        return serial.Serial(port, timeout=5, baudrate=115200)
    
    raise Exception("Could not find a serial port")

def interactive(device_path=None):
    ser = find_port(device_path)

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
                        resp_data = send_data(ser, cmd.cmd_data, cmd.resp_size)
                    else:
                        send_data(ser, cmd)
                except CommsException as e:
                    print( f"ERROR: {e}")
                else:
                    print( "OK" )

                    if type(cmd) == CmdWithResponse:
                        cmd.handler(resp_data)



if __name__ == '__main__':
    if len(sys.argv) == 1:
        interactive()

