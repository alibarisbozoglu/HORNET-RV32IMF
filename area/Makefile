# FPGA area of HORNET, core vs SoC (Vivado on the host).
#
#   make -C area                     Nexys 4 DDR, synthesis + opt_design
#   make -C area BOARD=nexysvideo    another board (any fpga/<board>/ with board.tcl)
#   make -C area IMPL=1              also place and route + timing
#   make -C area summary             only rebuild area.md from existing reports
#
# Output: build/area/<board>/area.md and the Vivado reports next to it.

ROOT    := $(abspath ..)
VIVADO  ?= $(shell command -v vivado 2>/dev/null || echo /opt/Xilinx/2025.2/Vivado/bin/vivado)
BOARD   ?= nexys4ddr
IMPL    ?= 0
DEPTH   ?= 2
OUT     ?= $(ROOT)/build/area/$(BOARD)

.PHONY: area summary clean

area:
	@mkdir -p $(OUT)
	cd $(OUT) && $(VIVADO) -mode batch -nojournal -log vivado.log \
	    -source $(ROOT)/area/area.tcl -tclargs $(BOARD) $(OUT) $(IMPL) > /dev/null
	$(MAKE) --no-print-directory summary

summary:
	python3 $(ROOT)/area/area_summary.py $(OUT) --depth $(DEPTH) -o $(OUT)/area.md

clean:
	rm -rf $(OUT)
