ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# Project details
# RISC-V IP Core
CORE := rv32i
IP_NAME := risc_v_32i_cm
IP_VENDOR := ISAE
IP_LIBRARY := user
IP_VERSION := 1.0

# Hardware information
TARGET_PART := xc7z020clg400-1
BOARD_PART := digilentinc.com:zybo-z7-20:part0:1.2

# Vitis
WORKSPACE := $(ROOT_DIR)/vitis_ws
PLATFORM := RISC_V_worker_PS_layer_platform
HW := $(ROOT_DIR)/riscv_worker_hardware.xsa
CPU := ps7_cortexa9_0
APPLICATION := RISC_V_worker_PS_application
CODE := $(ROOT_DIR)/zynq
VERBOSITY := 1

# Relevant directories
SCRIPTS_DIR := scripts
CORE_DIR := $(ROOT_DIR)/../cores/$(CORE)


# Building RISC-V IP Core
riscv_ip:
	@echo "Creating RISC-V IP Core from: $(CORE_DIR)"
	@vivado -mode batch -source $(SCRIPTS_DIR)/package_riscv_ip.tcl \
			-tclargs $(IP_NAME) $(IP_VENDOR) $(IP_LIBRARY) $(IP_VERSION) $(TARGET_PART) $(CORE)
