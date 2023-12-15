"""
Need:

1. Constant read thread
2. Write thread - needs handshake
- handshake - send is_ready, await ack, then send after
- do this after each 64 byte message + header
3. Human interface
- raw data
- processed data
- data entry

For HCI initially just have some consoles, later
on can drag in sound/image files possbily (before that specify paths)

Observation: reading when there is nothing available is quite a timesink even at low timeouts (0.001)
"""
import threading
from serial import Serial 
import time
from message import Message, Header, Partial
from manager import Message_Manager
import sys

class Lock:
    def __init__(self):
        self.locked = False

    def acquire(self):
        """
        Attempts to acquire the lock. 

        Returns:
            True if successfully acquired the lock,
            False otherwise.
        """
        if not self.locked: 
            self.locked = True
            return True
        return False
    
    def release(self):
        """
        Releases a lock
        """
        self.locked = False

class Writer:
    def  __init__(self, quiet, text):
        self.quiet = quiet
        self.messages = []
        self.text = text

        self.curr_message = None

        # for testing
        self.i = 0

    def write_loop(self):
        pass

    def enqueue(self, messages):
        """
        Adds a new message to the buffer

        Params:
            message (Message): message to send
        """
        if isinstance(messages, Message):
            self.messages.append(messages)
        else:
            for message in messages:
                assert isinstance(message, Message)
                self.messages.append(message)

    def dequeue(self):
        """
        Pops a byte from the current message.
        If no current message, tries to grab one from the buffer.
        Returns the next byte to send to the FPGA.

        Returns:
            byte (bytes) | None: next byte to send
                                 None if not bytes are available
        """
        if self.curr_message is None:
            if self.messages: 
                self.curr_message = self.messages.pop(0)
                if self.quiet: 
                    print("\033[32mSending message:\033[37m: " + self.curr_message.reduced_str(self.text))
                else:
                    print("\033[32mSending message:\033[37m\n" + str(self.curr_message))
            else: return None, False
            
        next_byte, continue_msg, just_finished =  self.curr_message.get_next_byte()
        if just_finished:
            print("\033[32mFinished message:\033[37m: " + self.curr_message.reduced_str())
        if not continue_msg:
            self.curr_message = None

        return next_byte, just_finished
    
class Message_Bucket:
    def __init__(self, text):
        self.enc = None
        self.dec = None
        self.text = text
        
    def add_msg(self, msg: Message):
        is_raw = msg.parsed_header.is_raw
        if is_raw: 
            self.enc = msg
        else: 
            self.dec = msg

    def __str__(self):
        res = ""
        if self.enc is not None:
            res += "enc: " + self.enc.reduced_str(self.text)
        if self.enc is not None and self.dec is not None:
            res += " || "
        if self.dec is not None:
            res += "dec: " + self.dec.reduced_str(self.text)

        return res

class Reader:
    def __init__(self, quiet, text):
        self.messages_received = {}
        self.current_partial = None
        self.quiet = quiet
        self.text = text

    def read_loop(self):
        pass

    def msg_to_print(self, msg: Message):
        # Assumes message in bucket:
        id = msg.parsed_header.trans_id
        bucket = self.messages_received[id] 
        
        if self.quiet: 
            return "\033[34mGot message:\033[37m: " + str(bucket)
        else:
            return f"\033[34mGot message:\033[37m\n" + str(msg) # For now do nothing else


    def concat_msg(self, msg: Message):
        assert isinstance(msg, Message)
        id = msg.parsed_header.trans_id
        if id not in self.messages_received:
            self.messages_received[id] = Message_Bucket(self.text)
        bucket = self.messages_received[id] 
        bucket.add_msg(msg)

        print(self.msg_to_print(msg))
        
        # msg_id = msg.parsed_header.trans_id
        # if msg_id not in self.message_received:
        #     self.messages_received[msg_id] = Transmission()
        
        # self.messages_received[msg_id].add_message(msg)
    def get_signal(self, code):
        signals = {
            1: 'stall',
            2: 'unstall',
            255: 'ok'
        }
        if code not in signals:
            return 'unknown'
        return signals[code]

    def append_byte(self, byte):
        """
        Returns 'stall' if stalled,
        'unstall' if unstalled,
        code|None otherwise
        """
        if self.current_partial is None:
            if byte != bytes([Message.START_BYTE]):
                return 'no_start'
            self.current_partial = Partial()
            return 'start'
        res = self.current_partial.append_byte(byte)
        if res['done']:
            # print("--"*50, res['signal_code'])
            if self.get_signal(res['signal_code']) == 'ok':
                self.current_partial = None # clear Partial
                self.concat_msg(res['contents'])
            return self.get_signal(res['signal_code'])
        return None
     

class Display: 
    pass

def main_loop(reader, writer, quiet=False):
    port = 'COM4'
    ser_module = Serial(port=str(port), baudrate=12_000_000, timeout=0.0001)

    with ser_module as ser: 
        stalled = False
        to_write = None
        ix = 0
        timer = -100
        just_finished_msg = False
        val = bytes([])
        status = None
        WAIT_TIME = 3
        while True:
            # Writing
            to_write = None # For printing
            # if not stalled and time.time() - timer > WAIT_TIME:
            #     to_write, just_finished_msg = writer.dequeue()
            #     # to_write, just_finished_msg = Message.START_BYTE, False
            #     # to_write, just_finished_msg = 0xff, False

               
            #     if to_write is not None:
            #         ser.write(to_write)
            #     if just_finished_msg:
            #         timer = time.time()

            write_print = None if to_write is None else str(bytes([to_write]).decode("all-escapes")).zfill(4)
            
            # Reading
            if to_write is None: # Only read when not writing
                val = ser.read()
                status = reader.append_byte(val)
                if status == 'stall':
                    stalled = True
                elif status == 'unstall':
                    stalled = False
            else:
                val = bytes([])
            
            # Printing
            if not quiet and (to_write is not None or int.from_bytes(val)):
                print('wrote:', write_print, 'got:', str(val.decode("all-escapes")).zfill(4), 'stalled?:', stalled, 'read_status:', status)
            else:
                if not quiet and ix%1000 == 0 and ix > 0:
                    print("\033[33mwaiting...\033[37m")
                ix += 1

            if not quiet and just_finished_msg:
                print('\033[32mFinished sending message\033[37m')

            # Resetting
            just_finished_msg = False

            # time.sleep(0.1) # temp
            

            

def entry_point(args):
    quiet = "q" in args
    text = "t" in args
    manager = Message_Manager()
    writer = Writer(quiet, text)
    reader = Reader(quiet, text)

    # temporary stuff
    # writer.enqueue(manager.make_messages(bytes([i for i in range(0)])))
    # writer.enqueue(manager.make_messages(bytes([i for i in range(Message.MESSAGE_SIZE_BYTES)])))
    # writer.enqueue(manager.make_start_message(0, 0, True))

    msgs = manager.make_messages(bytes([i for i in range(Message.MESSAGE_SIZE_BYTES)]))
    msg = msgs[1]
    msg.repeats = 'inf'
    writer.enqueue(msg)

    # end temporary

    main_loop(reader, writer, quiet)

if __name__ == "__main__":
    entry_point(sys.argv[1:])