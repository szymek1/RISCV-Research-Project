# -----------------------------------------------------------------------
# Author: Szymon Bogus
# Date:   09.07.2025
#
# Description:
# This TCL script aims to automate building binaries for an FPGA:
# bitstream and netlist. This process saves binaries to corresponding
# directories: bin/bit and bin/netlist.
# License: GNU GPL
# -----------------------------------------------------------------------


# Parse arguments passed from Makefile
set language        [lindex $argv 0]
set hdl_dir         [lindex $argv 1]
set constraints_dir [lindex $argv 2]
set netlist_dir     [lindex $argv 3]
set bitstream_dir   [lindex $argv 4]
set device          [lindex $argv 5]
set project_name    [lindex $argv 6]
set top_mod_name    [lindex $argv 7]

# Collect HDL sources
if {$language eq "verilog"} {
    set lang v
} elseif {$language eq "vhdl"} {
    set lang vhd
} elseif {$language eq "systemverilog"} {
    set lang sv
} else {
    error "Unrecognized HDL: $language"
}

set hdl_files [glob -nocomplain "$hdl_dir/*.$lang"]

if {[llength $hdl_files] == 0} {
    error "No HDL files found in $hdl_dir"
}

# Constraints
set constraints_files [glob -nocomplain "$constraints_dir/*.xdc"]
if {[llength $constraints_files] == 0} {
    error "No constraints files found in $constraints_dir"
}

# Read HDL sources
foreach file $hdl_files {
    puts "Reading HDL file: $file"
    if { $language eq "verilog" } {
        read_verilog $file
    } elseif { $language eq "vhdl" } {
        read_vhdl $file
    } elseif { $language eq "systemverilog" } {
        read_verilog -sv $file
    }
}

# Read constraints
foreach file $constraints_files {
    puts "Reading constraints file: $file"
    read_xdc $file
}

# Run synthesis and implementation
synth_design -top $top_mod_name -part $device
opt_design
place_design
route_design

# Output bitstream and netlist
file mkdir $bitstream_dir
file mkdir $netlist_dir

write_bitstream -force "$bitstream_dir/$project_name.bit"
write_edif -force "$netlist_dir/$project_name.edif"

puts "Bitstream generated at $bitstream_dir/$project_name.bit"
