from bitstring import Bits, BitArray

class Message:
    HEADER_SIZE_BITS = 32
    MESSAGE_SIZE_BITS = 64
    HEADER_SIZE_BYTES = int(HEADER_SIZE_BITS / 8)
    MESSAGE_SIZE_BYTES = int(MESSAGE_SIZE_BITS / 8)

    START_BYTE = 0xbb
    
    def __init__(self, header, message, repeats):
        """
        Assumes message is a bytes object of size MESSAGE_SIZE_BYTES.
        and header is a Header object or a bytes object of size HEADER_SIZE_BYTES.

        Also assumes repeats is > 0 or 'inf' for infinite repeats.
        """
        if isinstance(header, Header):
            self.header = header.to_bytes()
            self.parsed_header = header
        else:
            assert isinstance(header, bytes)
            self.header = header # header is bytes object
            self.parsed_header = Header(header)
            
        self.message = message
        self.repeats = repeats
        
        self.header_idx = 0
        self.message_idx = 0

        self.start = True

    def repeats_remaining(self):
        return self.repeats == 'inf' or self.repeats > 0
    
    def decrement_repeats(self):
        assert self.repeats == 'inf' or self.repeats > 0
        if self.repeats != 'inf': self.repeats -= 1

    def get_next_byte(self):
        """
        Returns byte, continue flag, just_finished flag.
        byte is None if out of repeats
        """
        if self.start:  # Send start byte first
            self.start = False
            return self.START_BYTE, True, False
        
        if self.header_idx < self.HEADER_SIZE_BYTES:
            self.header_idx += 1
            return self.header[self.HEADER_SIZE_BYTES - 1 - (self.header_idx - 1)], True, False
        elif self.message_idx < self.MESSAGE_SIZE_BYTES - 1:
            self.message_idx += 1
            return self.message[self.MESSAGE_SIZE_BYTES - 1 - (self.message_idx - 1)], True, False
        elif self.message_idx == self.MESSAGE_SIZE_BYTES - 1:
            self.message_idx += 1
            return self.final_check()
        
        return None, False, False # out of repeats
    
    def final_check(self):
        """Return byte, continue, just_finished"""
        self.decrement_repeats()
        if self.repeats_remaining():
            self.header_idx = 0
            self.message_idx = 0
            self.start = True
            return self.message[0], True, True
        
        return self.message[0], False, True
    
    def __str__(self):
        return 'header: ' + str(self.parsed_header) + "\n" + 'contents: ' + str(self.message.decode('all-escapes'))
            
       


class Partial:
    def __init__(self):
        self.header_buff = bytes([])
        self.message_buff = bytes([])
        self.message = None

    def append_byte(self, byte):
        """
        Adds a byte to a partial message.
        If message is full, resend full message

        Assumes byte is a bytes object.

        Params: 
            byte (bytes): byte to add
        
        Returns:
            {
                'done': bool, 
                'signal_code': int,
                'contents': Message|None
            }
        """
        done = False
        signal_code = 255
        if len(self.header_buff) < Message.HEADER_SIZE_BYTES - 1:
            self.header_buff = byte + self.header_buff
        elif len(self.header_buff) == Message.HEADER_SIZE_BYTES - 1:
            self.header_buff = byte + self.header_buff
            parsed_header = Header(self.header_buff)
            if not parsed_header.is_data: # Signal!!!
                done = True
                signal_code = parsed_header.trans_id

        elif len(self.message_buff) < Message.MESSAGE_SIZE_BYTES - 1:
            self.message_buff = byte + self.message_buff
        elif len(self.message_buff) == Message.MESSAGE_SIZE_BYTES - 1:
            self.message_buff = byte + self.message_buff
            done = True
            self.message = Message(self.header_buff, self.message_buff, 1)
        else: # Should have a message by now
            done = True
            signal_code = self.message.parsed_header.trans_id

        return {
            'done': done,
            'signal_code': signal_code,
            'contents': self.message
        }

class Header:
    def __init__(self, bytes_obj=None, params=None):
        if bytes_obj is not None:
            self.parse_bytes(bytes_obj)
        elif params is not None:
            self.populate_params(params)
        else:
            raise Exception("Must have one of byte_obj or params")

    def populate_params(self, params):
        """
        Takes in a dictionary with the expected params,
        populates this header's params.

        Raises errors if params are too large
        or missing.
        """
        assert 0 <= params['trans_id'] < 256
        assert 0 <= params['packet_num'] < 256
        assert 0 <= params['data_len'] < Message.MESSAGE_SIZE_BITS, params['data_len'] # in bits, actually up to 512 if can compile it
        
        # populate (KeyError if missing)
        self.is_data = params['is_data']
        self.is_start = params['is_start']
        self.is_raw = params['is_raw']
        self.trans_id = params['trans_id']
        self.packet_num = params['packet_num']
        self.data_len = params['data_len']

    def parse_bytes(self, header):
        """
        Takes in a bytes object of size HEADER_SIZE_BYTES
        and parses it.

        The header consists of the following information, by bits:

        Use the parenthesized indeces since Python is inverted

        0     (31)    : data flag
        1     (30)    : start flag
        2     (29)    : raw flag
        3-6   (25:28) : reserved
        7-14  (17:24) : transmission ID 
        15-22 (9:16)  : packet #
        23-31 (0:8)   : packet data length - 1
        """
        assert len(header) == Message.HEADER_SIZE_BYTES
        bs = Bits(header)

        self.is_data = bs[31]
        self.is_start = bs[30]
        self.is_raw = bs[29]
        self.trans_id = bs[17:24+1].u
        self.packet_num = bs[9:16+1].u
        self.data_len = bs[0:8+1].u

    def to_bytes(self):
        """
        Returns binary version of the header
        as a bytes object
        """
        array = BitArray(length=Message.HEADER_SIZE_BITS)
        array[31] = self.is_data
        array[30] = self.is_start
        array[29] = self.is_raw
        array[17:24+1] = self.trans_id
        array[9:16+1] = self.packet_num
        array[0:8+1] = self.data_len

        return array.bytes

    def __str__(self):
        return str({
            'bytes': self.to_bytes().decode('all-escapes'),
            'is_data': self.is_data,
            'is_start': self.is_start,
            'is_raw': self.is_raw,
            'trans_id': self.trans_id,
            'packet_num': self.packet_num,
            'data_len': self.data_len,
        })


"""
Message will store the byte buffers for the message


Header: 

parsed bytes for header

External modules will use the parsed header to construct a message

header.to_bytes() should return bytes of the header



"""

if __name__ == "__main__":
    # Testing header stuff
    print("-"*10, "Header","-"*10)
    header = [255 for _ in range(Message.HEADER_SIZE_BYTES)]
    header = '0_0_0_0000_00000001_00000011_111111111'
    header = header.replace("_","")
    print(len(header))
    
    header_bytes = bytes([int(header[i:i+8], 2) for i in range(0,len(header),8)])
    print(header_bytes)
    hdr = Header(header_bytes)
    print(str(hdr))
    print(hdr.to_bytes())
    hdr2 = Header(None, {'is_data': False, 'is_start': False, 'is_raw': False, 'trans_id': 1, 'packet_num': 0, 'data_len': 127})
    print('hdr2', hdr2.to_bytes())
    print(bin(int.from_bytes(hdr2.to_bytes())))

    # Testing message works
    print("-"*10, "Message","-"*10)
    header = [i for i in range(Message.HEADER_SIZE_BYTES)]
    message = [i for i in range(Message.MESSAGE_SIZE_BYTES)]
    msg = Message(bytes(header), bytes(message), 1)
    cont = True
    while cont:
        byte, cont, just_finished = msg.get_next_byte()
        print(byte)

    msg2 = Message(Header(None, {'is_data': False, 'is_start': False, 'is_raw': False, 'trans_id': 1, 'packet_num': 0, 'data_len': 42}), bytes(message), 1)
    
    print(str(msg2.parsed_header))

    # Testing Partial
    print("-"*10, "Header","-"*10)
    print("signal")
    p = Partial()
    hdr3 = Header(None, {'is_data': False, 'is_start': False, 'is_raw': False, 'trans_id': 1, 'packet_num': 0, 'data_len': 0})
    hdr3_bytes = hdr3.to_bytes()
    for i in range(Message.HEADER_SIZE_BYTES):
        byte = bytes([hdr3_bytes[i]])
        res = p.append_byte(byte)
        print(res)

    print("messages")
    from manager import Message_Manager
    mgr = Message_Manager()
    contents = bytes([i for i in range(32)])
    messages = mgr.make_messages(contents)

    for message in messages:
        p = Partial()
        hdr = message.header
        msg = message.message
        for i in range(Message.HEADER_SIZE_BYTES):
            byte = bytes([hdr[i]])
            res = p.append_byte(byte)
            print(res)
        for i in range(Message.MESSAGE_SIZE_BYTES):
            byte = bytes([msg[i]])
            res = p.append_byte(byte)
            print(res)

        print(str(res['contents'])) # should be a Message Obj

    print(Message.MESSAGE_SIZE_BYTES)