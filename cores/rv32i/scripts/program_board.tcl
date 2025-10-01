# -----------------------------------------------------------------------
# Author: Szymon Bogus
# Date:   10.07.2025
#
# Description:
# This TCL script aims to automate programming an FPGA device.
# License: GNU GPL
# -----------------------------------------------------------------------


# Parse arguments passed from Makefile
set bitstream_file [lindex $argv 0]
set device         [lindex $argv 1]

# Extract just the base device name for get_hw_devices
# Match like: xc7z020clg400-1 -> xc7z020
if {[regexp {^(xc[0-9a-z]+?)[a-z]{3}[0-9]+} $device match base_device]} {
    set hw_device_pattern "${base_device}*"
} else {
    error "Could not extract base device name from: $device"
}

puts "Looking for hardware device: $hw_device_pattern"

open_hw_manager
connect_hw_server
open_hw_target [lindex [get_hw_targets *] 0]

# Select FPGA explicitly xc7z020*
set fpga_device [lsearch -inline [get_hw_devices] $hw_device_pattern] 
if { $fpga_device eq "" } {
    error "FPGA device $hw_device_pattern not found. Check connection."
}
current_hw_device $fpga_device

# Program FPGA
set_property PROGRAM.FILE $bitstream_file [current_hw_device]
program_hw_devices [current_hw_device]

puts "FPGA programming successful."