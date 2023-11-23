BUILD_SOURCES := \
				hdl/* \
				xdc/* \

.PHONY: build 
build: 
	./remote/r.py build.py build.tcl $(BUILD_SOURCES)

.PHONY: flash
flash: 
	cd /c/users/sjcam/Github/EncryptED
	openFPGALoader -b arty_s7_50 obj/final.bit

.PHONY: sim
sim: 
	iverilog -g2012 -o vcd/sim.out $(SIM)
	vvp vcd/sim.out

.PHONY: clean

.PHONY: test
test: 
	iverilog -g2012 -o vcd/test_tx.out sim/uart_tx_tb.sv hdl/uart.sv hdl/top_level.sv
	vvp vcd/test_tx.out
	iverilog -g2012 -o vcd/test_rx.out sim/uart_rx_tb.sv hdl/uart.sv hdl/top_level.sv
	vvp vcd/test_rx.out
clean: 
	rm -rf obj/*
	rm -rf 


