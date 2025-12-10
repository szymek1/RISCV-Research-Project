# Configuration
set project_name    "RISC_V_worker_PL_layer"
set output_dir      "../build_riscv_worker_pl"
set ip_repo_dir     "../ip_repos"
set target_part     "xc7z020clg400-1"
set board_part      "digilentinc.com:zybo-z7-20:part0:1.2"
set xsa_name        "riscv_worker_hardware.xsa"

# How many threads should perform synthesis and implementation tasks
set threads_num     2

puts "--- Creating Project ---"
create_project -force $project_name $output_dir -part $target_part

# Set Board Properties
set_property board_part $board_part [current_project]

# Set IP Repository
set_property ip_repo_paths $ip_repo_dir [current_project]
update_ip_catalog

puts "--- Creating Block Design ---"

# Create the BD object
create_bd_design "RISC_V_worker_PL"
update_compile_order -fileset sources_1

# Block Diagram generation
# 1. Create Processing System
set processing_system7_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]
# Apply any specific Zynq settings below
set_property -dict [list \
  CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
  CONFIG.PCW_FPGA_FCLK0_IO {MIO} \
  CONFIG.PCW_USE_M_AXI_GP0 {1} \
  CONFIG.PCW_EN_EMIO_TTC0 {0} \
  CONFIG.PCW_USE_S_AXI_GP0 {0} \
] $processing_system7_0

# 2. Create BRAM Controller & Memory
set axi_bram_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0 ]
set_property CONFIG.SINGLE_PORT_BRAM {1} $axi_bram_ctrl_0
set blk_mem_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0 ]

# 3. Create SmartConnects
set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
set_property -dict [list CONFIG.NUM_MI {2} CONFIG.NUM_SI {1}] $smartconnect_0
set smartconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_1 ]

# 4. Create Reset System
set rst_ps7_0_50M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_50M ]

# 5. Create IP Core
# Make sure that the VLNV (Vendor:Library:Name:Version) matches exactly what was packaged!
set risc_v_32i_cm_0 [ create_bd_cell -type ip -vlnv ISAE:user:risc_v_32i_cm:1.0 risc_v_32i_cm_0 ]

# 6. Connections (Intf)
connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
connect_bd_intf_net -intf_net processing_system7_0_M_AXI_GP0 [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins smartconnect_0/S00_AXI]
connect_bd_intf_net -intf_net risc_v_32i_cm_0_M_AXI [get_bd_intf_pins risc_v_32i_cm_0/M_AXI] [get_bd_intf_pins smartconnect_1/S01_AXI]
connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins smartconnect_0/M00_AXI] [get_bd_intf_pins smartconnect_1/S00_AXI]
connect_bd_intf_net -intf_net smartconnect_0_M01_AXI [get_bd_intf_pins smartconnect_0/M01_AXI] [get_bd_intf_pins risc_v_32i_cm_0/S_AXI]
connect_bd_intf_net -intf_net smartconnect_1_M00_AXI [get_bd_intf_pins smartconnect_1/M00_AXI] [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]

# 7. Connections (Clocks/Resets)
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] [get_bd_pins smartconnect_0/aclk] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins rst_ps7_0_50M/slowest_sync_clk] [get_bd_pins risc_v_32i_cm_0/CLK] [get_bd_pins smartconnect_1/aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_50M/ext_reset_in]
connect_bd_net [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins smartconnect_0/aresetn] [get_bd_pins risc_v_32i_cm_0/RSTn] [get_bd_pins smartconnect_1/aresetn]

# 8. Address Mapping (Auto-assign to avoid overlap errors)
assign_bd_address

# Save and Validate
save_bd_design
validate_bd_design
puts "--- Block Design Created Successfully ---"

# Generating HDL wrapper
puts "--- Generating Top-Level Wrapper ---"
set bd_file [get_files RISC_V_worker_PL.bd]
generate_target all $bd_file
set wrapper_path [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper_path

# Update hierarchy to ensure the wrapper is Top
set_property top RISC_V_worker_PL_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Synthesis and Implementation
puts "--- Launching Synthesis ---"
# Launch runs with 8 threads (adjust -jobs based on your PC)
launch_runs synth_1 -jobs $threads_num
wait_on_run synth_1

# Check if synthesis succeeded
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
   error "ERROR: Synthesis failed"
}

puts "--- Launching Implementation & Bitstream Generation ---"
# 'to_step write_bitstream' runs opt, place, route, and bitstream in one go
launch_runs impl_1 -to_step write_bitstream -jobs $threads_num
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
   error "ERROR: Implementation failed"
}

# Export Hardware to XSA
puts "--- Exporting Hardware to $xsa_name ---"

# -fixed: Include the bitstream
# -force: Overwrite if exists
write_hw_platform -fixed -include_bit -force -file $xsa_name

puts "========================================================"
puts " BUILD COMPLETE "
puts " Bitstream location: [get_property DIRECTORY [get_runs impl_1]]/RISC_V_worker_PL_wrapper.bit"
puts " XSA location:       [pwd]/$xsa_name"
puts "========================================================"