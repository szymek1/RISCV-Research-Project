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
ROOT_DIR 	    := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# Project's main directories
SOURCE_DIR      := $(ROOT_DIR)/src
SIM_DIR         := $(ROOT_DIR)/simulation
SCRIPTS_DIR     := $(ROOT_DIR)/scripts
LOG_DIR		    := $(ROOT_DIR)/log
BINARIES_DIR    := $(ROOT_DIR)/bin
DATA_DIR	    := $(ROOT_DIR)/data

# Project's subdirectories
# HDL exclusive source files
HDL_DIR 	    := $(SOURCE_DIR)/hdl

# testbenches
SIM_SRC_DIR     := $(SOURCE_DIR)/sim

# constraints
CONSTRAINTS_DIR := $(SOURCE_DIR)/constraints

# Waveforms
WAVE_DIR 	    := $(SIM_DIR)/waveforms

# Netlist and bitstream
NETLIST_DIR     := $(BINARIES_DIR)/netlist
BITSTREAM_DIR   := $(BINARIES_DIR)/bit

# TCL scripts
BUILD_TCL       := $(SCRIPTS_DIR)/build.tcl
SIMULATE_TCL    := $(SCRIPTS_DIR)/simulate.tcl
PROGRAM_TCL     := $(SCRIPTS_DIR)/program_board.tcl

# Python scripts
DEP_ANALYZER    := $(ROOT_DIR)/dep_analyzer.py

# Project's details
project_name    := rv32i_sc
top_module	    := riscv_cpu
language 	    := verilog
device 		    := xc7z020clg400-1

VIVADO_CMD 		:= vivado -mode batch

# Directories to verify during configuration directive
DIRS := $(HDL_DIR) $(CONSTRAINTS_DIR) $(SIM_SRC_DIR) $(WAVE_DIR) \
        $(NETLIST_DIR) $(BITSTREAM_DIR) $(LOG_DIR)

.PHONY: conf sim_all sim_sel bit program_fpga clean

conf:
	@echo "Checking and creating necessary directories..."
	@mkdir -p $(DIRS)
	@echo "Directories ensured."

# Run all testbenches
sim_all: conf
	@echo "Simulating all testbenches"
	@$(VIVADO_CMD) -source $(SIMULATE_TCL) \
		-tclargs $(language) $(HDL_DIR) $(SIM_SRC_DIR) $(DATA_DIR) $(WAVE_DIR) \
		> $(LOG_DIR)/simulation_all.log 2>&1
	@rm -rf *.backup.* vivado.jou
	@echo "Simulations completed for $(project_name). Logs stored at $(LOG_DIR)/simulation_all.log; Waveforms stored at $(WAVE_DIR)"

# Run selected testbenches: example $ make sim_sel TB="tb1 tb2 tb3" USE "...", no need for file extension
sim_sel: conf
	@echo "Simulating specific testbenches: $(TB)..."
	@COMPILE_SRCS="$$(python3 $(DEP_ANALYZER) --lang $(language) --tbs "$${TB}" --hdl_dir $(HDL_DIR) --sim_dir $(SIM_SRC_DIR))" && \
	cd $(WAVE_DIR) && $(VIVADO_CMD) -source $(SIMULATE_TCL) \
		-tclargs $(language) "$${COMPILE_SRCS}" $(SIM_SRC_DIR) $(DATA_DIR) $(WAVE_DIR) $(TB) \
		> $(LOG_DIR)/simulation_selected.log 2>&1
	@rm -rf *.backup.* vivado.jou
	@echo "Simulations completed for $(project_name): $(TB). Logs and waveforms stored in correspnding directories in $(LOG_DIR) and $(WAVE_DIR)"

bit: conf
	@echo "Building bitstream..."
	@$(VIVADO_CMD) -source $(BUILD_TCL) \
		-tclargs $(language) $(HDL_DIR) $(CONSTRAINTS_DIR) $(NETLIST_DIR) $(BITSTREAM_DIR) $(device) $(project_name) $(top_module) \
		> $(LOG_DIR)/build.log 2>&1
	@rm -rf *.backup.* vivado.jou
	@echo "Build completed for $(project_name). Logs stored at $(LOG_DIR)/build.log"

program_fpga: bit
	@echo "Programming FPGA..."
	@$(VIVADO_CMD) -source $(PROGRAM_TCL) \
		-tclargs $(BITSTREAM_DIR)/$(project_name).bit $(device) \
		> $(LOG_DIR)/program.log 2>&1
	@rm -rf *.backup.* vivado.jou
	@echo "FPGA programmed for $(project_name). Logs stored at $(LOG_DIR)/program.log"

clean:
	@echo "Cleaning generated files..."
	@rm -rf $(BINARIES_DIR)/* $(LOG_DIR)/* *.backup.* vivado.jou
	@echo "Clean completed."