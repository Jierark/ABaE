BUILD_SOURCES := \
				hdl/* \
				xdc/* \

.PHONY: build 
build: 
	./remote/r.py build.py build.tcl $(BUILD_SOURCES)

.PHONY: build-uart-echo
# iverilog -g2012 hdl/uart_low_level.sv uart_echo/top_level.sv
build-uart-echo:

	./remote/r.py build.py build.tcl xdc/* hdl/uart_low_level.sv uart_echo/top_level.sv

.PHONY: build-uart-integration
# iverilog -g2012 hdl/uart_low_level.sv uart_integration/top_level.sv hdl/uart_tx_bridge.sv hdl/uart_rx_bridge.sv hdl/uart_controller.sv
build-uart-integration:
	./remote/r.py build.py build.tcl xdc/* hdl/uart_low_level.sv uart_integration/top_level.sv hdl/uart_tx_bridge.sv hdl/uart_rx_bridge.sv hdl/uart_controller.sv

.PHONY: test-integration
test-integration:
	iverilog -g2012 -o vcd/test_integration.vcd sim/uart_integration_tb.sv hdl/uart_low_level.sv  hdl/uart_tx_bridge.sv hdl/uart_rx_bridge.sv hdl/uart_controller.sv
	vvp vcd/test_integration.vcd

.PHONY: build-uart-tx-batch
#    iverilog -g2012 hdl/uart_low_level.sv uart_tx_batch/top_level.sv hdl/uart_tx_bridge.sv hdl/uart_rx_bridge.sv hdl/uart_controller.sv
build-uart-tx-batch:
	 ./remote/r.py build.py build.tcl xdc/* hdl/uart_low_level.sv uart_tx_batch/top_level.sv hdl/uart_tx_bridge.sv hdl/uart_rx_bridge.sv hdl/uart_controller.sv

.PHONY: build-spi
build-spi:
	./remote/r.py build.py build.tcl xdc/* hdl/uart_low_level.sv hdl_spi/top_level.sv hdl/uart_tx_bridge.sv hdl/uart_rx_bridge.sv hdl/uart_controller.sv hdl/spi_controller.sv hdl/spi_rx.sv hdl/spi_tx.sv

.PHONY: build-spi-uart
build-spi-uart:
	./remote/r.py build.py build.tcl xdc/* hdl/uart_low_level.sv hdl_spi_uart/top_level.sv hdl/uart_tx_bridge.sv hdl/uart_rx_bridge.sv hdl/uart_controller.sv hdl/spi_controller.sv hdl/spi_rx.sv hdl/spi_tx.sv

.PHONY: test-spi-uart
test-spi-uart:
	iverilog -g2012 hdl/uart_low_level.sv hdl_spi_uart/top_level.sv hdl/uart_tx_bridge.sv hdl/uart_rx_bridge.sv hdl/uart_controller.sv hdl/spi_controller.sv hdl/spi_rx.sv hdl/spi_tx.sv
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
	iverilog -g2012 -o vcd/test_tx.out sim/uart_tx_tb.sv hdl/uart_low_level.sv
	vvp vcd/test_tx.out
	iverilog -g2012 -o vcd/test_rx.out sim/uart_rx_tb.sv hdl/uart_low_level.sv
	vvp vcd/test_rx.out

	iverilog -g2012 -o vcd/test_rx_bridge.out sim/uart_rx_bridge_tb.sv hdl/uart_rx_bridge.sv
	vvp vcd/test_rx_bridge.out
	iverilog -g2012 -o vcd/test_tx_bridge.out sim/uart_tx_bridge_tb.sv hdl/uart_tx_bridge.sv
	vvp vcd/test_tx_bridge.out

	iverilog -g2012 -o vcd/test_mod_inv.out sim/modular_inverse_tb.sv hdl/modular_inverse.sv hdl/divider.sv
	vvp vcd/test_mod_inv.out
	iverilog -g2012 -o vcd/test_mult.out sim/multiplier_tb.sv hdl/multiplier.sv 
	vvp vcd/test_mult.out

clean: 
	rm -rf obj/*
	rm -rf 


