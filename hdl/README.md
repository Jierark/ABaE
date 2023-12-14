# Message Specification
## Data packages
Data packages consist of a 32-bit header and a 512-bit body.
If less than 512 bits of data are to be sent, the body must be padded to 512 bits with zeros leftward
such that the message begins at the LSB.

The header consists of the following information, by bits:

0     (31)    : data flag
1     (30)    : start flag
2     (29)    : raw flag
3-6   (25:28) : reserved
7-14  (17:24) : transmission ID 
15-22 (9:16)  : packet #
23-31 (0:8)   : packet data length - 1



At the beginning of a transmission, the laptop should send a 'start' packet
which contains the following information about the number of packets to send in its body,
by bits:

0-7   : data type
8-15  : reserved
16:   : number of packets

The 'start' packet's header should have a 1 for 'start flag' and 1 for 'data flag'
and specify the size of the 'numer of packets' field by its 'packet data length' field.

## Signals
Signals are only sent from the FPGA to its connected computer.
They use the same header format, but are not followed by any data.

### Stall Signal
Sent to the computer when the RX pipeline is unable to receive more data.

data flag  : 0
start flag : 0
raw flag   : 0
transm. id : 8'b1
packet #   : 0
pt dta len : 0

INV:     0_0_0_0000_00000001_00000000_000000000
VERILOG: 000000000_00000000_10000000_0000_0_0_0

### Unstall Signal
Sent to the computer when the RX pipeline is able to receive data again.

data flag  : 0
start flag : 0
raw flag   : 0
transm. id : 8'b2
packet #   : 0
pt dta len : 0

INV:     0_0_0_0000_00000010_00000000_000000000
VERILOG: 000000000_00000000_01000000_0000_0_0_0

