# FPGA area of HORNET, core vs SoC (Vivado on the host).
#
#   make -C area                     Nexys 4 DDR, RV32IMF, synthesis + opt_design
#   make -C area ISA=rv32im          another ISA configuration: rv32i, rv32im, rv32imf
#   make -C area BOARD=nexysvideo    another board (any fpga/<board>/ with board.tcl)
#   make -C area IMPL=1              also place and route + timing
#   make -C area all IMPL=1          every configuration in ISAS, then compare
#   make -C area summary             only rebuild area.md from existing reports
#   make -C area compare             only rebuild compare.md from existing reports
#
# Output: build/area/<board>/<isa>/area.md and the Vivado reports next to it,
# build/area/<board>/compare.md for the comparison.

ROOT    := $(abspath ..)
VIVADO  ?= $(shell command -v vivado 2>/dev/null || echo /opt/Xilinx/2025.2/Vivado/bin/vivado)
BOARD   ?= nexys4ddr
IMPL    ?= 0
DEPTH   ?= 2

ISA     ?= rv32imf
ISAS    ?= rv32i rv32im rv32imf
ifeq ($(filter $(ISA),rv32i rv32im rv32imf),)
$(error ISA=$(ISA): use rv32i, rv32im or rv32imf)
endif
ISA_EXT  = $(patsubst rv32i%,%,$(ISA))
RV_M     = $(if $(findstring m,$(ISA_EXT)),1,0)
RV_F     = $(if $(findstring f,$(ISA_EXT)),1,0)

BOARD_OUT = $(ROOT)/build/area/$(BOARD)
OUT     ?= $(BOARD_OUT)/$(ISA)
# The defaults of fpga/common/board.tcl with this ISA. The images stay the
# RV32IMF ones: memory contents do not change the area, and these runs are not booted.
PROG_ARGS = $(ROOT)/fpga/default/imem.hex $(ROOT)/fpga/default/dmem.hex 65536 65536 20 0xF000 $(RV_M) $(RV_F)

.PHONY: area all summary compare clean

area:
	@mkdir -p $(OUT)
	cd $(OUT) && $(VIVADO) -mode batch -nojournal -log vivado.log \
	    -source $(ROOT)/area/area.tcl -tclargs $(BOARD) $(OUT) $(IMPL) $(PROG_ARGS) > /dev/null
	$(MAKE) --no-print-directory summary

all:
	set -e; for isa in $(ISAS); do $(MAKE) --no-print-directory area ISA=$$isa; done
	$(MAKE) --no-print-directory compare

summary:
	python3 $(ROOT)/area/area_summary.py $(OUT) --isa $(shell echo $(ISA) | tr a-z A-Z) --depth $(DEPTH) -o $(OUT)/area.md

compare:
	python3 $(ROOT)/area/area_summary.py --compare $(foreach i,$(ISAS),$(i)=$(BOARD_OUT)/$(i)) -o $(BOARD_OUT)/compare.md

clean:
	rm -rf $(OUT)
