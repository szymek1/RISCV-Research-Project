# SOC
This directory contains the sources for and build utilities for the final product- synthesizeable diesign, which includes:

- ZYNQ Processing System C application (AXI Master)
- PS-PL joint project in Vivado (it instantiates the design with the core of choice and all necessary IP cores)
- IP cores directory

## PS-PL joint project
### General
This is Vivado project which defines the connections between HDL part of the project and the software part of the project. The project can be recreated thanks to ```RISC_V_softcore.tcl```. To do so run:

```vivado -mode gui -source RISC_V_softcore.tcl```

This command will create ```RISC_V_softcore/``` directory and inside it Vivado will regenerate the project.

### Development
Once the project is regenerate user can edit it however they want but it is ***crucial to recreate tcl file*** as this is the only part of Vivado project that goes to the source control.

In order to do it properly go to: *File->Project->Write TCL*, then check: *Copy sources to new project* (**TODO: do we need that?**) and *Recreate Block Designs using TCL*. Finally, overwrite the file.