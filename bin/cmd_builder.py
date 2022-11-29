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

def load_file(addr, fname):
    data = open(fname, 'rb').read()
    return write_bytes(addr, data)

def process_line(line):
    line = line.strip()
    parts = line.split()
    if len(parts) == 0:
        return b''

    name = parts[0]

    str_args = name in [ 'load' ]

    args = []
    for i, x in enumerate(parts[1:]):
        try:
            if str_args:
                args.append(x)
            else:
                args.append(int(x, 0))
        except ValueError:
            raise CommandException(f"Could not parse arg {i+1} '{x}'")
        
    data = b''

    try:
        if name == "memb":
            data = show_memory_byte(args[0], args[1])
        elif name == "memw":
            data = show_memory_word(args[0], args[1])
        elif name == "writeb":
            data = write_bytes(args[0], b''.join([x.to_bytes(1, byteorder='little') for x in args[1:]]))
        elif name == "writew":
            data = write_words(args[0], b''.join([x.to_bytes(2, byteorder='little') for x in args[1:]]))
        elif name == "outb":
            data = out_byte(args[0], args[1])
        elif name == "outw":
            data = out_word(args[0], args[1])
        elif name == "inb":
            data = in_byte(args[0])
        elif name == "inw":
            data = in_word(args[0])
        elif name == "call":
            data = far_call(args[0])
        elif name == "memset":
            data = memset(args[0], args[1], args[2])
        elif name == "load":
            data = load_file(int(args[0], 0), args[1])
        else:
            raise CommandException(f"Unknown command '{name}'")
    except IndexError:
        raise CommandException(f"Insufficient arguments for '{name}'")
    except ValueError:
        raise CommandException(f"Could not parse arguments")

    return data

MAGIC = [ 0xfa, 0x23, 0x68, 0xaf ]

def expect_resp(ser, seq, expected):
    resp = ser.read_until().decode('utf-8', errors='replace').strip()
    sequence_str, _, status = resp.partition(' ')
    
    try:
        sequence = int(sequence_str)
    except ValueError:
        raise CommsException(f"Unrecognized sequence number: {resp}")
    
    if sequence != seq:
        raise CommsException(f"Unexpected sequence number: {sequence} != {seq}")
    
    if status != expected:
        raise CommandException(f"Unexpected status: {status} != {expected}")

    

def send_data(ser, data):
    seq = random.randint(0, 255)
    for ofs in range(0, len(data), 32):
        end = min(len(data), 32)
        chunk = data[ofs:end]
        pkt = struct.pack("<BBBBBBH", MAGIC[0], MAGIC[1], MAGIC[2], MAGIC[3], seq & 0xff, len(chunk) + 2, ofs & 0xffff) + chunk
        ser.write(pkt)
        expect_resp(ser, seq, "ACK")
        seq = seq + 1
    
    pkt = struct.pack("<BBBBBBHH", MAGIC[0], MAGIC[1], MAGIC[2], MAGIC[3], seq & 0xff, 4, 0xffff, len(data))
    ser.write(pkt)
    expect_resp(ser, seq, "SENT")


def find_port(device_path=None):
    if device_path:
        print(f"Using {device_path}")
        return serial.Serial(device_path)
    
    ports = list(serial.tools.list_ports.grep(".*usbmodem"))
    if len(ports) > 0:
        port = ports[0].device
        print(f"Using {port}")
        return serial.Serial(port, timeout=5)
    
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
            cmd_data = process_line(cmd_line)
        except CommandException as e:
            print(e)
        else:
            if len(cmd_data):
                try:
                    send_data(ser, cmd_data)
                except CommsException as e:
                    print( f"ERROR: {e}")
                else:
                    print( "OK" )

def script(filename, device_path=None):
    ser = find_port(device_path)

    cmd_data = b''

    with open(filename, "rt") as fp:
        for idx, line in enumerate(fp.readlines()):
            try:
                line_data = process_line(line)
            except CommandException as e:
                print(f"{filename}:{idx+1} - {e}")
                return False
            if line_data:
                print(line)
            cmd_data = cmd_data + line_data

    time.sleep(1) # serial writes seem to fail without this?

    send_data(ser, cmd_data)
    return True

if __name__ == '__main__':
    if len(sys.argv) == 1:
        interactive()
    else:
        script(sys.argv[1])

