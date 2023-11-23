from serial import Serial, STOPBITS_ONE, SEVENBITS
from serial.tools import list_ports
import time
import struct


# print('Serial Ports:\n' + '='*30)
# for port in list_ports.comports():
#     print(port.device)
# print('='*30)
# port = input('Enter the FPGA Port: ')
port = "COM4"

# The following is reconstructed from manta's source code

ser_module = Serial(port=str(port), baudrate=12_000_000, timeout=1)

with ser_module as ser: 
    while (True):
        for i in range(1,256):
            # to_write = bytes([16*8+1])
            to_write = bytes([i])
            print(f"Writing {i} ({to_write})")
            ser.write(to_write)
            time.sleep(0.01)
        