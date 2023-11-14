from serial import Serial, STOPBITS_ONE, SEVENBITS
from serial.tools import list_ports
import time

print('Serial Ports:\n' + '='*30)
for port in list_ports.comports():
    print(port.device)
print('='*30)
port = input('Enter the FPGA Port: ')

# The following is reconstructed from manta's source code
# chunk_size = 256
ser_module = Serial(port=str(port), baudrate=3_000_000, timeout=1)

with ser_module as ser: 
    print(f"Starting Serial Write at port {port}")
    data = [4, 2]
    ports = [1, 2]
    for idx, i in enumerate(ports):
        outbound_bytes = f"W{i:04X}{data[idx]:04X}\r\n".encode('ascii')
        ser.write(outbound_bytes)

    time.sleep(3)
    print(f"Starting Serial Read at port {port}")
    while(True):
        inbound = b""
        for i in range(1, 3):
            outbound = f"R{i:04X}\r\n".encode('ascii')
            ser_module.write(outbound)

            inbound += ser.read(len(outbound))
        print('Serial In: ', inbound)
        # time.sleep(0.01)
        