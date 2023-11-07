BUILD_SOURCES := \
				hdl/ \
				xdc/ \

.PHONY: build 
build: 
	./remote/r.py build.py build.tcl $(BUILD_SOURCES)

.PHONY: flash
flash: 
	openFPGALoader -b arty_s7_50 obj/final.bit

.PHONY: sim
sim: 
	iverilog -g2012 -o vcd/sim.out $(SIM)
	vvp vcd/sim.out

.PHONY: clean
clean: 
	rm -rf obj/*
	rm -rf 

