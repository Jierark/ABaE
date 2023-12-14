from message import Header, Message
from bitstring import BitArray
import math

def num_to_bytes(num: int):
    """
    Params:
        num (int): number to convert

    Returns bytes (the num as a byte obj).
    """
    if num == 0:
        return bytes([0])
    
    length_in_bits = math.ceil(math.log(num, 2))
    length = length_in_bits//8 + 1
    print(length)
    return num.to_bytes(length)

class Message_Manager:
    def __init__(self):
        self.id_counter = 0
        self.data_types = { # vals must be in range 1-255 so no empty messages
            'raw': 1
        }

    def make_start_message(self, num_packets, msg_id, debug_loop=False):
        """
        Creates and returns a Message object for a transmission
        See README.md in hdl for details on specification of this message
        """
        msg_cont = BitArray(length=Message.MESSAGE_SIZE_BITS)
        
        msg_cont[Message.MESSAGE_SIZE_BITS-8:Message.MESSAGE_SIZE_BITS] = self.data_types['raw']

        len_bytes = num_to_bytes(num_packets)
        packet_num_bit_length = len(len_bytes)*8

        assert len(len_bytes) < Message.MESSAGE_SIZE_BITS
        for idx, byte in enumerate(len_bytes):  # write bytes
            btm = Message.MESSAGE_SIZE_BITS-16-(idx+1)*8
            top = Message.MESSAGE_SIZE_BITS-16
            msg_cont[btm:top] = byte
        
        hdr_obj = Header(None, {'is_data': True, 
                                'is_start': True, 
                                'is_raw': True, 
                                'trans_id': msg_id, 
                                'packet_num': 0, 
                                'data_len': 16+packet_num_bit_length}) # store length - 1
        
        repeats = 'inf' if debug_loop else 1
        start_msg = Message(hdr_obj, msg_cont.bytes, repeats)

        return start_msg
    
    def make_msg_content(self, content):
        """
        Makes a bytes object of length Message.MESSAGE_SIZE_BYTES
        containing content, zero extended.
        Assumes content is smaller than Message.MESSAGE_SIZE_BYTES.
        """
        assert len(content) <= Message.MESSAGE_SIZE_BYTES
        msg_cont = BitArray(length=Message.MESSAGE_SIZE_BITS)
        for idx, byte in enumerate(content):
            msg_cont[idx*8:idx*8+8] = byte
        return msg_cont.bytes

    def make_messages(self, contents):
        """
        Creates a returns a list of Message objects
        long enough to fit all the contents.

        Expects contents to be a bytes object.
        """
        messages = []
        header_proto = {'is_data': True, 
                        'is_start': False, 
                        'is_raw': True, 
                        'trans_id': self.id_counter, 
                        'packet_num': 0, # placeholder
                        'data_len': 0}   # placeholder
        
        for start_idx in range(0, len(contents), Message.MESSAGE_SIZE_BYTES):
            header_proto['packet_num'] = len(messages) + 1
            if len(contents) - start_idx < Message.MESSAGE_SIZE_BYTES:  # store length - 1 bit
                data_len = max(0, (len(contents) - start_idx) * 8 - 1)  # if length 0, don't go to -1
            else:
                data_len = Message.MESSAGE_SIZE_BITS - 1

            header_proto['data_len'] = data_len  # in bits

            content = self.make_msg_content(contents[start_idx:start_idx+Message.MESSAGE_SIZE_BYTES])

            msg = Message(Header(None, header_proto), content, 1)

            messages.append(msg)
        
        
        start_msg = self.make_start_message(len(messages), self.id_counter)
        messages = [start_msg, *messages]

        self.id_counter += 1
        return messages

if __name__ == "__main__":
    mgr = Message_Manager()
    content = bytes([i for i in range(33)])
    messages = mgr.make_messages(content)
    for msg in messages:
        print(str(msg))

    print(num_to_bytes(511))
    print(num_to_bytes(128))
    print(num_to_bytes(256))
    print(num_to_bytes(2**16+7+ 10*16).decode("all-escapes"))
            
    
    