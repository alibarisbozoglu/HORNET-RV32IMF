# FPGA area: core vs SoC

LUT, FF, BRAM and DSP usage of HORNET for each ISA configuration (RV32I,
RV32IM, RV32IMF), split into the core (`hornet_core`:
pipeline, register files, and the M unit and FPU when configured) and the rest of the SoC (IMEM/DMEM,
data router, AXI4-Lite bridge and crossbar, timer, UART, GPIO, sysctl, board
clock and reset). Vivado runs on the host, as for `make fpga-build`.

## Results

Nexys 4 DDR (XC7A100T-1CSG324), Vivado 2026.1, after place and route
(`make -C area all IMPL=1`), RTL at commit `59412a9` (v2.1.0), 64 KiB IMEM and
64 KiB DMEM, 50 MHz core clock.

### ISA configurations

Core in the SoC:

| ISA | LUTs | LUTRAM | FFs | BRAM (36 Kb) | DSPs |
|---|---:|---:|---:|---:|---:|
| RV32I | 2,317 | 44 | 1,036 | 0 | 0 |
| RV32IM | 2,768 | 44 | 1,280 | 0 | 4 |
| RV32IMF | 6,016 | 110 | 1,980 | 0 | 6 |

Whole design and timing:

| ISA | LUTs | LUTRAM | FFs | BRAM (36 Kb) | DSPs | SoC without core (LUTs / FFs) | Setup WNS |
|---|---:|---:|---:|---:|---:|---:|---:|
| RV32I | 2,939 | 56 | 1,838 | 32 | 0 | 622 / 802 | +1.552 ns |
| RV32IM | 3,405 | 56 | 2,082 | 32 | 4 | 637 / 802 | +1.102 ns |
| RV32IMF | 6,638 | 122 | 2,783 | 32 | 6 | 622 / 803 | +0.488 ns |

Core alone (out of context):

| ISA | LUTs | LUTRAM | FFs | BRAM (36 Kb) | DSPs | Setup WNS |
|---|---:|---:|---:|---:|---:|---:|
| RV32I | 2,458 | 44 | 1,569 | 0 | 0 | +3.658 ns |
| RV32IM | 2,908 | 44 | 1,776 | 0 | 4 | +4.555 ns |
| RV32IMF | 6,432 | 110 | 2,497 | 0 | 6 | +1.161 ns |

Cost of each extension (core in the SoC):

| Step | LUTs | LUTRAM | FFs | DSPs |
|---|---:|---:|---:|---:|
| RV32I to RV32IM | +451 | +0 | +244 | +4 |
| RV32IM to RV32IMF | +3,248 | +66 | +700 | +2 |

The SoC peripherals are the same in all three; the 15 extra LUTs of RV32IM are
in the logic flattened into the SoC (memories, data router, crossbar, clock and
reset). Slack is not strictly ordered with size in the out-of-context runs:
RV32IM has more slack than RV32I.

### Critical paths

| ISA | Path | Slack | Period at zero slack | Data path (logic + route) | Levels |
|---|---|---:|---:|---:|---:|
| RV32I | Whole design | +1.552 ns | 18.45 ns (54.2 MHz) | 17.30 ns (4.94 + 12.36) | 17 |
| RV32I | Inside the core, in the SoC | +4.803 ns | 15.20 ns (65.8 MHz) | 14.82 ns (3.63 + 11.19) | 17 |
| RV32I | Core alone | +3.658 ns | 16.34 ns (61.2 MHz) | 15.85 ns (4.05 + 11.79) | 15 |
| RV32IM | Whole design | +1.102 ns | 18.90 ns (52.9 MHz) | 17.96 ns (5.21 + 12.75) | 17 |
| RV32IM | Inside the core, in the SoC | +2.732 ns | 17.27 ns (57.9 MHz) | 16.95 ns (3.21 + 13.74) | 15 |
| RV32IM | Core alone | +4.555 ns | 15.45 ns (64.7 MHz) | 15.26 ns (3.25 + 12.01) | 17 |
| RV32IMF | Whole design | +0.488 ns | 19.51 ns (51.3 MHz) | 19.15 ns (6.42 + 12.72) | 21 |
| RV32IMF | Inside the core, in the SoC | +0.847 ns | 19.15 ns (52.2 MHz) | 19.06 ns (7.32 + 11.74) | 31 |
| RV32IMF | Core alone | +1.161 ns | 18.84 ns (53.1 MHz) | 18.78 ns (7.38 + 11.40) | 27 |

Where the paths run:

| ISA | Path | From | To |
|---|---|---|---|
| RV32I | Whole design | `SOC/IMEM/mem_reg_0_3` | `SOC/IMEM/mem_reg_1_2` (port B address) |
| RV32I | Inside the core, in the SoC | `SOC/CORE/MEM_STAGE/store_o_reg` | `SOC/CORE/IF_STAGE/out_pc_q_reg[16]` |
| RV32I | Core alone | `MEM_STAGE/store_o_reg` | `IF_STAGE/wait_pc_q_reg[23]` |
| RV32IM | Whole design | `SOC/IMEM/mem_reg_2_1` | `SOC/IMEM/mem_reg_1_3` (port B address) |
| RV32IM | Inside the core, in the SoC | `SOC/CORE/ID_STAGE/rs2_q_o_reg[2]` | `SOC/CORE/IF_STAGE/pc_q_reg[0]` |
| RV32IM | Core alone | `ID_STAGE/rs2_q_o_reg[2]` | `IF_STAGE/wait_pc_q_reg[16]` |
| RV32IMF | Whole design | `SOC/IMEM/mem_reg_0_0` | `SOC/CORE/EX_STAGE/F_FPU.FPU/CVT/mant_q_reg[14]` |
| RV32IMF | Inside the core, in the SoC | `SOC/CORE/EX_STAGE/F_FPU.FPU/DIVSQRT/q_reg[26]` | `SOC/CORE/EX_STAGE/F_FPU.FPU/out_q_reg[22]` |
| RV32IMF | Core alone | `EX_STAGE/F_FPU.FPU/DIVSQRT/q_reg[26]` | `EX_STAGE/F_FPU.FPU/out_q_reg[21]` |

"Period at zero slack" is the 20 ns requirement minus the slack. It is not a
maximum frequency: the tools stop working on timing once 50 MHz is met, so a
run with a tighter clock may do better. The core alone has only a clock
constraint, so paths through its ports are not timed. "Inside the core, in the
SoC" is the worst path with both ends on registers of the `CORE` instance.

### Static power

| ISA | Whole design | Out of context | Junction temperature (whole design) |
|---|---:|---:|---:|
| RV32I | 0.099 W | 0.084 W | 26.1 C |
| RV32IM | 0.099 W | 0.084 W | 26.1 C |
| RV32IMF | 0.099 W | 0.084 W | 26.1 C |

This is Vivado's Device Static power, with its default operating conditions
(25 C ambient, 250 LFM airflow, medium heat sink). It is the leakage of the
whole XC7A100T die, so it does not change with the configuration and it cannot
be split into core and SoC. The out-of-context figure is not the static power
of the core: the same die, without the board's I/O. The 0.015 W gap is about
13 mW on the 3.3 V I/O supply plus about 1 mW each on the BRAM and core supplies.

### RV32IMF in detail

Setup WNS: whole design +0.488 ns, core alone +1.161 ns.

| | LUTs | LUT as logic | LUTRAM | FFs | BRAM (36 Kb) | DSPs |
|---|---:|---:|---:|---:|---:|---:|
| **Whole design** (`hornet_board`) | 6,638 | 6,516 | 122 | 2,783 | 32 | 6 |
| **Core** in the SoC (`hornet_core`) | 6,016 | 5,906 | 110 | 1,980 | 0 | 6 |
| **Core** alone (out of context) | 6,432 | 6,322 | 110 | 2,497 | 0 | 6 |
| **SoC without core** | 622 | 610 | 12 | 803 | 32 | 0 |

The whole design uses 10.5% of the device's LUTs, 2.2% of its FFs, 23.7% of
its BRAMs and 2.5% of its DSPs. No SRLs are used.

Core in the SoC, by block:

| Block | LUTs | FFs | DSPs | share of core LUTs |
|---|---:|---:|---:|---:|
| EX_STAGE (ex_stage) | 4,004 | 1,065 | 2 | 66.6% |
| &nbsp;&nbsp;&nbsp;&nbsp;F_FPU.FPU (fpu_top) | 2,845 | 620 | 2 | 47.3% |
| &nbsp;&nbsp;&nbsp;&nbsp;M_DIV.DIV (div) | 370 | 139 | 0 | 6.2% |
| &nbsp;&nbsp;&nbsp;&nbsp;ALU, forwarding and the rest of EX | 789 | 306 | 0 | 13.1% |
| ID_STAGE (id_stage) | 1,144 | 259 | 0 | 19.0% |
| IF_STAGE (if_stage) | 351 | 198 | 0 | 5.8% |
| MEM_STAGE (mem_stage, with the multiplier) | 303 | 107 | 4 | 5.0% |
| REGFILE (regfile, LUTRAM) | 110 | 0 | 0 | 1.8% |
| CSR_UNIT (csr_unit) | 82 | 318 | 0 | 1.4% |
| WB_STAGE (wb_stage) | 51 | 33 | 0 | 0.8% |

The blocks add up to 29 LUTs more than the core: Vivado's hierarchical report
shows this kind of difference already after `opt_design`. In RV32I and RV32IM
synthesis does not keep `regfile` as its own instance, so the generated reports
show its 44 LUTRAMs under "other CORE logic".

SoC without core, by block:

| Block | LUTs | FFs | BRAM (36 Kb) |
|---|---:|---:|---:|
| AXI_BRIDGE (obi_axil_bridge) | 299 | 104 | 0 |
| UART (axil_uart) | 146 | 123 | 0 |
| GPIO (axil_gpio) | 77 | 296 | 0 |
| TIMER (axil_timer) | 32 | 166 | 0 |
| SYSCTL (axil_sysctl) | 28 | 99 | 0 |
| IMEM, DMEM, data router, crossbar, clock and reset (flattened by synthesis) | 40 | 15 | 32 |

The 32 BRAMs are IMEM and DMEM (16 each for 64 KiB).

## Running

```
make -C area                     # Nexys 4 DDR, RV32IMF, synthesis + opt_design
make -C area ISA=rv32im          # another ISA: rv32i, rv32im, rv32imf
make -C area IMPL=1              # also place and route + timing
make -C area all IMPL=1          # all three ISAs, then compare.md (about 7 minutes each)
make -C area BOARD=nexysvideo    # another board (any fpga/<board>/ with board.tcl)
make -C area summary DEPTH=3     # rebuild area.md only, deeper core breakdown
make -C area compare             # rebuild compare.md only
```

Output in `build/area/<board>/<isa>/`, and `compare.md` (all ISAs side by side)
in `build/area/<board>/`:

| File | Content |
|---|---|
| `area.md` | summary: whole design, core, SoC without core; core and SoC breakdown |
| `soc_util_<stage>.rpt`, `soc_util_hier_<stage>.rpt` | `hornet_board` (the same synthesis as `fpga/common/build.tcl`) |
| `soc_timing_route.rpt` | timing summary (`IMPL=1`) |
| `core_util_<stage>.rpt`, `core_util_hier_<stage>.rpt` | `hornet_core` synthesized alone, out of context |
| `core_timing_route.rpt` | its timing summary at the board's core clock (`IMPL=1`) |
| `soc_critical.rpt`, `soc_core_critical.rpt`, `core_critical.rpt` | worst setup path: whole design, inside the core in the SoC, core alone (`IMPL=1`) |
| `soc_power.rpt`, `core_power.rpt` | `report_power` with default (vectorless) activity (`IMPL=1`) |
| `soc_route.dcp`, `core_route.dcp` | routed checkpoints, for later analysis such as power with simulation activity (`IMPL=1`) |

`<stage>` is `opt` (synthesis + `opt_design`) or `route` (`IMPL=1`); the
summary uses the route reports when they exist, so run `make -C area clean`
before going back to `IMPL=0`.

The core is given two ways:

- **in the SoC**: the `hornet_core` instance in the hierarchical report of the
  whole design. Together with "SoC without core" this adds up to the total.
- **alone**: `hornet_core` as the top with `-mode out_of_context` (no I/O
  buffers). It is larger than the in-SoC number mainly because the RVFI
  outputs (formal verification trace) drive top-level ports and are kept,
  while `hornet_soc` leaves them open and synthesis removes their registers.
  The in-SoC number is the cost of the core as it is used.

The memories come from the default images in `fpga/default/` (64 KiB IMEM and
64 KiB DMEM) in every configuration. Those images are built for RV32IMF, so the
RV32I and RV32IM runs measure area and are not meant to be booted; the BRAM count of the SoC scales with `IMEM_SIZE`/`DMEM_SIZE`.

Files: `area.tcl` (Vivado), `area_summary.py` (report parser), `Makefile`.
Nothing outside this folder is changed; `area.tcl` reuses
`fpga/common/board.tcl` for the board definitions.
