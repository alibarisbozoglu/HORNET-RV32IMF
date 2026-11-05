# FPGA area (and optionally timing) of HORNET: the whole SoC on a board, and
# the core alone (out of context).
#
#   vivado -mode batch -source area/area.tcl -tclargs <board> <out_dir> <impl> [<imem.hex> <dmem.hex> IMEM_SIZE DMEM_SIZE CLK_DIV BOOT_ADDR RV_M RV_F]
#
# <board>   a directory fpga/<board>/ with board.tcl (nexys4ddr, nexysvideo)
# <impl>    0: synthesis + opt_design; 1: also place and route + timing
# Without program arguments it uses the default images in fpga/default/
# (bootloader + LED blink, 64 KiB IMEM and DMEM), like fpga/<board>/build.tcl.
#
# Reports (in <out_dir>):
#   soc_util_<stage>.rpt       utilization of hornet_board (core + SoC + clock/reset)
#   soc_util_hier_<stage>.rpt  the same per hierarchy level (core vs SoC blocks)
#   soc_timing_route.rpt       timing summary (impl=1 only)
#   core_util_<stage>.rpt      hornet_core synthesized alone (out of context)
#   core_util_hier_<stage>.rpt the same per hierarchy level
#   core_timing_route.rpt      its timing summary at the board's clock (impl=1 only)
#   <soc|core>_critical.rpt    the worst setup path (impl=1 only)
#   soc_core_critical.rpt      the worst setup path with both ends in the core, in the SoC (impl=1 only)
#   <soc|core>_power.rpt       report_power, default (vectorless) activity (impl=1 only)
#   <soc|core>_route.dcp       routed checkpoint, for later analysis without a rerun (impl=1 only)
# <stage> is "opt" (after synthesis and opt_design) or "route" (impl=1).

set script_name area.tcl
set board [lindex $argv 0]
set out_dir [file normalize [lindex $argv 1]]
set impl [lindex $argv 2]
set argv [lrange $argv 3 end]
source [file dirname [file normalize [info script]]]/../fpga/common/board.tcl
if {[llength $argv] > 0} { set argv [linsert $argv 0 $out_dir] }
board_args $out_dir

file mkdir $out_dir
cd $out_dir
set_part $board_part
set_param general.maxThreads 8

read_verilog [glob $rtl/core/*.v] [glob $rtl/fpu/*.v] [glob $rtl/soc/*.v] $fpga_dir/common/hornet_board.v
file copy -force $imem imem.hex
file copy -force $dmem dmem.hex

proc write_reports {prefix stage} {
  report_utilization -file ${prefix}_util_${stage}.rpt
  report_utilization -hierarchical -hierarchical_depth 8 -file ${prefix}_util_hier_${stage}.rpt
}

# opt_design removes logic without loads and propagates constants, like the
# implementation flow does, so the numbers are what really ends up on the FPGA
proc implement {prefix impl} {
  opt_design
  write_reports $prefix opt
  if {$impl} {
    place_design
    phys_opt_design
    route_design
    write_reports $prefix route
    report_timing_summary -max_paths 20 -file ${prefix}_timing_route.rpt
    report_timing -max_paths 1 -nworst 1 -file ${prefix}_critical.rpt
    report_power -file ${prefix}_power.rpt
    write_checkpoint -force ${prefix}_route.dcp
  }
}

# ---- Core alone: out of context, so its ports get no I/O buffers and nothing
# outside it can optimize it away or merge with it. Before the board
# constraints are read, which name ports the core does not have. The clock is
# the board's core clock (1000 MHz / CLK_DIV).
synth_design -top hornet_core -mode out_of_context -include_dirs [list $rtl/core $rtl/fpu] \
  -generic RV_M=$rv_m -generic RV_F=$rv_f
create_clock -name clk -period $clk_div [get_ports clk_i]
implement core $impl
close_design

# ---- SoC: the same synthesis as fpga/common/build.tcl
read_xdc $board_dir/$board_xdc
set generics {}
foreach g [board_generic_list] { lappend generics -generic $g }
synth_design -top hornet_board -include_dirs [list $rtl/core $rtl/fpu] {*}$generics
implement soc $impl
if {$impl} {
  set core_regs [filter [all_registers -cells] {NAME =~ SOC/CORE/*}]
  report_timing -from $core_regs -to $core_regs -max_paths 1 -nworst 1 -file soc_core_critical.rpt
}
close_design

puts "INFO: reports written to $out_dir"
