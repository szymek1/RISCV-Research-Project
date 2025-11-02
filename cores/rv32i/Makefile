# -----------------------------------------------------------------------
# Author: Szymon Bogus
# Date:   09.07.2025
#
# Description:
# This Makefile intends to configure Xilinx FPGA project and maintain it
# through internal TCL calls. It assumes utilization of Vivado Simulator.
# License: GNU GPL
# -----------------------------------------------------------------------


# This Makefile should be placed int the root directory of the project
ROOT_DIR        := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# Project's main directories
SOURCE_DIR      := $(ROOT_DIR)/src
SIM_DIR         := $(ROOT_DIR)/simulation
SCRIPTS_DIR     := $(ROOT_DIR)/scripts
LOG_DIR         := $(ROOT_DIR)/log
BINARIES_DIR    := $(ROOT_DIR)/bin
DATA_DIR        := $(ROOT_DIR)/data

# Project's subdirectories
HDL_DIR         := $(SOURCE_DIR)/hdl
SIM_SRC_DIR     := $(SOURCE_DIR)/sim
CONSTRAINTS_DIR := $(SOURCE_DIR)/constraints

# TCL scripts
BUILD_TCL       := $(SCRIPTS_DIR)/build.tcl
SIMULATE_TCL    := $(SCRIPTS_DIR)/simulate.tcl
PROGRAM_TCL     := $(SCRIPTS_DIR)/program_board.tcl

TB_DIR          := $(SIM_SRC_DIR)/component_testbenches
TB_SRC_FILES := $(wildcard $(TB_DIR)/*_tb.v)
TB_NAMES := $(TB_SRC_FILES:$(TB_DIR)/%.v=%)

TEST_PROG_DIRS  := $(dir $(wildcard $(DATA_DIR)/*/*/memory.hex))
TEST_PROG_NAMES := $(patsubst $(DATA_DIR)/%,%,$(TEST_PROG_DIRS:/=))
# $(info TEST_PROG_DIRS = $(TEST_PROG_DIRS))
# $(info TEST_PROG_NAMES = $(TEST_PROG_NAMES))

# Python scripts
DEP_ANALYZER    := $(ROOT_DIR)/dep_analyzer.py

# Project's details
project_name    := rv32i_sc
top_module      := riscv_cpu
language        := verilog
device          := xc7z020clg400-1

VIVADO_CMD      := vivado -mode batch
# Netlist and bitstream
NETLIST_DIR     := $(BINARIES_DIR)/netlist
BITSTREAM_DIR   := $(BINARIES_DIR)/bit

IVERILOG_FLAGS  := -g2012 -Wall
VVP_DIR         := $(BINARIES_DIR)/vvp
D_DIR           := $(BINARIES_DIR)/d

#
# ================ MISC ================
#

.PHONY: list-test-progs
list-test-progs:
	@echo Found test programs:
	@echo $(TEST_PROG_NAMES)

.PHONY: list-testbenches
list-testbenches:
	@echo Found testbenches:
	@echo $(TB_NAMES)

#
# ================ IVERILOG ================
#

# Build verilog and output dependencies as Makefile .d format
.PRECIOUS: $(VVP_DIR)/%.vvp
$(VVP_DIR)/%.vvp: $(SIM_SRC_DIR)/%.v
	@echo "Compiling testbench \"$(@F:.vvp=)\""
	@mkdir -p $(@D) $(D_DIR) $(LOG_DIR)
	@iverilog $(IVERILOG_FLAGS) \
		-Mall=$(@:.vvp=.d.raw) -y $(HDL_DIR) -I $(<D) \
		-DDATA_DIR=\"$(DATA_DIR)/\" \
		-o $@ $< > $(LOG_DIR)/compile_$(@F:.vvp=).txt 2>&1
	@{ \
	  printf '%s:' '$@'; \
	  sort -u $(@:.vvp=.d.raw) | tr '\n' ' '; \
	  printf '\n'; \
	} > $(@:$(VVP_DIR)/%.vvp=$(D_DIR)/%.d)
	@rm $(@:.vvp=.d.raw)

# Run TB and output report
$(SIM_DIR)/%/sim_output.txt: $(VVP_DIR)/%.vvp
	@mkdir -p $(@D)
	@echo "Running testbench \"$(<F:.vvp=)\""
	@cd $(@D) && vvp $< > $@ 2>&1

# # Alias each tb name to its report
# $(TB_NAMES): %: $(SIM_DIR)/component_testbenches/%/sim_output.txt

# # Target that combines all TBs
# .PHONY: sim
# sim: $(TB_NAMES)

#
# ================ VIVADO ================
#

# - Run all testbenches: example $ make sim-vivado
# - Run selected testbenches: example $ make sim-vivado TB="tb1 tb2 tb3" USE "...", no need for file extension
.PHONY: sim-vivado
sim-vivado:
	mkdir -p $(SIM_DIR) $(LOG_DIR)
ifeq ($(TB),)
	@echo "Simulating all testbenches"
else
	@echo "Simulating specific testbenches: $(TB)..."
endif
	@$(VIVADO_CMD) -source $(SIMULATE_TCL) \
		-tclargs $(language) $(HDL_DIR) $(SIM_SRC_DIR) $(DATA_DIR) $(SIM_DIR) $(TB) \
		> $(LOG_DIR)/sim.log 2>&1
	@rm -rf *.backup.* vivado.jou
	@echo "Simulations completed for $(project_name). Logs stored at $(LOG_DIR)/sim.log; Simulation output stored at $(SIM_DIR)"

.PHONY: bit
bit: $(BITSTREAM_DIR)/$(project_name).bit
$(BITSTREAM_DIR)/$(project_name).bit:
	mkdir -p $(NETLIST_DIR) $(BITSTREAM_DIR) $(LOG_DIR)
	@echo "Building bitstream..."
	@$(VIVADO_CMD) -source $(BUILD_TCL) \
		-tclargs $(language) $(HDL_DIR) $(CONSTRAINTS_DIR) $(NETLIST_DIR) $(BITSTREAM_DIR) $(device) $(project_name) $(top_module) \
		> $(LOG_DIR)/build.log 2>&1
	@rm -rf *.backup.* vivado.jou
	@echo "Build completed for $(project_name). Logs stored at $(LOG_DIR)/build.log"

.PHONY: program_fpga
program_fpga: bit
	@echo "Programming FPGA..."
	@$(VIVADO_CMD) -source $(PROGRAM_TCL) \
		-tclargs $(BITSTREAM_DIR)/$(project_name).bit $(device) \
		> $(LOG_DIR)/program.log 2>&1
	@rm -rf *.backup.* vivado.jou
	@echo "FPGA programmed for $(project_name). Logs stored at $(LOG_DIR)/program.log"


#
# ================ MISC ================
#

.PHONY: clean
clean:
	@echo "Cleaning generated files..."
	@rm -rf $(BINARIES_DIR) $(LOG_DIR) $(SIM_DIR) *.backup.* vivado.jou vivado.log
	@echo "Clean completed."

# Pull in previously generated .d dependency files
-include $(wildcard $(D_DIR)/*.d)
