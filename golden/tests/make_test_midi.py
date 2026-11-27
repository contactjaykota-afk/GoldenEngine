#!/usr/bin/env python3
"""Write a small Standard MIDI File for tests: format 1, 480 ticks/quarter, 120 BPM, 4/4.
Track 1 "Lead": 8 quarter notes C4 D4 E4 F4 C4 D4 E4 F4 (keys 60..65 -> lanes 0..3 with key mod 4),
the last one held for 2 beats. Track 2 "Bass": 4 half notes. Usage: make_test_midi.py <out.mid>"""
import struct, sys

def vlq(v):
    out = [v & 0x7F]; v >>= 7
    while v: out.insert(0, (v & 0x7F) | 0x80); v >>= 7
    return bytes(out)

def track(events):
    data = b"".join(vlq(d) + bytes(b) for d, b in events) + b"\x00\xff\x2f\x00"
    return b"MTrk" + struct.pack(">I", len(data)) + data

tempo = track([(0, [0xFF, 0x51, 3, 0x07, 0xA1, 0x20]), (0, [0xFF, 0x58, 4, 4, 2, 24, 8])])
lead = [(0, [0xFF, 0x03, 4] + list(b"Lead"))]
keys = [60, 62, 64, 65, 60, 62, 64, 65]
for i, k in enumerate(keys):
    length = 960 if i == len(keys) - 1 else 240
    lead += [(0 if i == 0 else 240, [0x90, k, 100]), (length, [0x80, k, 0])]
bass = [(0, [0xFF, 0x03, 4] + list(b"Bass"))]
for i, k in enumerate([36, 41, 43, 36]):
    bass += [(0, [0x91, k, 90]), (960, [0x81, k, 0])]
hdr = b"MThd" + struct.pack(">IHHH", 6, 1, 3, 480)
open(sys.argv[1], "wb").write(hdr + tempo + track(lead) + track(bass))
