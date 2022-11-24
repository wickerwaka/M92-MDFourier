#! /usr/bin/env python3

import sys
import struct
import serial
import serial.tools.list_ports
import readline
import os
import time

class CommandException(Exception):
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

def process_line(line):
    line = line.strip()
    parts = line.split()
    if len(parts) == 0:
        return b''

    name = parts[0]

    args = []
    for i, x in enumerate(parts[1:]):
        try:
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
        else:
            raise CommandException(f"Unknown command '{name}'")
    except IndexError:
        raise CommandException(f"Insufficient arguments for '{name}'")

    return data

def send_data(ser, data):
    PREAMBLE = b'\x00\x99\x11\x22\x33\x44\x55\x66\x77\x88\xFF\xAA\xBB\xCC\xDD\xFF'
    length = struct.pack("<H", len(data))
    ser.write(PREAMBLE)
    ser.write(length)
    ser.write(data)

def find_port(device_path=None):
    if device_path:
        print(f"Using {device_path}")
        return serial.Serial(device_path)
    
    ports = list(serial.tools.list_ports.grep(".*usbmodem"))
    if len(ports) > 0:
        port = ports[0].device
        print(f"Using {port}")
        return serial.Serial(port, timeout=2)
    
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
                send_data(ser, cmd_data)
                resp = ser.read_until().decode('utf-8', errors='replace').strip()
                print(f"RESPONSE: {resp}")

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
    resp = ser.read_until().decode('utf-8', errors='replace').strip()
    print(f"RESPONSE: {resp}")
    return True

if __name__ == '__main__':
    if len(sys.argv) == 1:
        interactive()
    else:
        script(sys.argv[1])

