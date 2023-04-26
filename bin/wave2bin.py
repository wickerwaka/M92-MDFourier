import wave
import sys

def read_data(name) -> bytearray:
    w = wave.open(name, "r")
    assert w.getsampwidth() == 1
    assert w.getnchannels() == 1
    data = w.readframes(w.getnframes())
    return [ x for x in data ]

data = read_data(sys.argv[1])

for i, v in enumerate(data):
    if v != 128:
        data = data[i:]
        break

for i, v in reversed(list(enumerate(data))):
    if v != 128:
        data = data[:i]
        break

preamble = [ 0x80 ] + ( [ 0x00 ] * 15 )
silence = [ 0x80 ] * 128

final = preamble + silence

for d in data:
    if d == 0:
        final.append(1)
    else:
        final.append(d)

final = final + silence

pad = ( 256 * 1024 ) - len(final)

final = final + ( [ 0x00 ] * pad )

open(sys.argv[2], 'wb').write(bytes(final))

