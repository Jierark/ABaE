from serial import Serial
from serial.tools import list_ports
import time

# print('Serial Ports:\n' + '='*30)
# for port in list_ports.comports():
#     print(port.device)
# print('='*30)
# port = input('Enter the FPGA Port: ')
port = "COM4"

# The following is reconstructed from manta's source code

ser_module = Serial(port=str(port), baudrate=3_000_000, timeout=1)

with ser_module as ser: 
    count = 0
    prev_val = None
    while (True):
       
        # val = ser.read(ser_module.in_waiting)

        val = ser.read()
        true_val = int.from_bytes(val)
        # true_val = 0
        if val != prev_val and val: print(count,":", true_val, ":", val)

        # print(count,":",int.from_bytes(val), ":", val)
        count += 1
        prev_val = val if val else prev_val
        