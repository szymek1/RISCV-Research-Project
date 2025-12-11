# SOC
This directory contains the sources for and build utilities for the final product- synthesizeable diesign, which includes:

- ZYNQ Processing System C application (AXI Master)
- PS-PL joint project in Vivado (it instantiates the design with the core of choice and all necessary IP cores)
- IP cores directory

## Architecture
The diagram below was created in accordance to [High Level Architecture and Detailed Single Worker Architecture](../README.md). It clarifies, which components belong to Processing System (PS) and which to Porgrammable Logic (PL)- implemented in HDL. Several indicated IP cores: AXI Interconnecct, AXI BRAM Controller, AXI Protocol Converter belong to AMD IP Cores Library. RISC-V IP is the custom made IP Core which integrates the core of choice with Fault Injection/Controll Module.

![SOC Detailed Architecture](../docs/soc_architecture.drawio.png)

## PS-PL joint project
### General
This is Vivado project which defines the connections between HDL part of the project and the software part of the project. The project can be recreated thanks to ```RISC_V_softcore.tcl```. To do so run:

```vivado -mode gui -source RISC_V_softcore.tcl```

This command will create ```RISC_V_softcore/``` directory and inside it Vivado will regenerate the project.

### Development
Once the project is regenerate user can edit it however they want but it is ***crucial to recreate tcl file*** as this is the only part of Vivado project that goes to the source control.

In order to do it properly go to: *File->Project->Write TCL*, then check: *Copy sources to new project* (**TODO: do we need that?**) and *Recreate Block Designs using TCL*. Finally, overwrite the file.

In ```soc/``` directory ```scripts/``` directory contains three scripts necessary to:

- build RISC-V IP Core: ```scripts/package_riscv_ip.tcl```
- synthesize and implement entire PL layer and export ready design into ```xsa```: ```scripts/build_riscv_worker_pl.tcl```
- compile PS layer of the system using exported ```xsa``` and initialize Vitis project: ```scripts/build_riscv_worker_ps_pl.py```

Additionally, as a safe check there's also ```soc/RISC_V_worker_PL_layer.tcl```, which can be used to regenerate Vivado project in GUI mode to graphically prepare the block diagram.

The recommended development is as follows:

1. Run: ```vivado -mode gui -source RISC_V_worker_PL_layerl.tcl``` and graphically create the block diagram project. Then do: *File->Project->Write TCL* and check: *Copy sources to new project* and *Recreate Block Designs using TCL*.
2. Open ```scripts/build_riscv_worker_pl.tcl``` and copy all the lines from ```RISC_V_worker_PL_layerl.tcl``` into the script so it has the latest design.
3. Run (from ```scripts/```): ```vivado -mode batch -source build_riscv_worker_pl.tcl```. This will prepare ```xsa``` and save it in ```soc```.
4. Run (from ```scripts/```): ```vitis -s build_riscv_worker_ps_pl.py --workspace "../vitis_ws" --hw_design "../riscv_worker_hardware.xsa" --code "../zynq" --verbose 1```. This will create Vitis project, compile both platform and application.
5. Open Vitis and program the device.

**Remarks:** 
- steps 1 and 2 are only mandatory when the block diagram changes, otherwise user can proceed with step 3 immediately. 
- resort to ```scripts/build_riscv_worker_ps_pl.py``` for more detailed description of the parser of execute ```vitis -s build_riscv_worker_ps_pl.py -h```.
- in order to run ```scripts/RISC_V_worker_PL_layerl.tcl``` user has to delete directory ```RISC_V_worker_PL_layer/``` (Vivado forces to work like that...).
- currently Vitis automatization is not yet perfect: Vitis project copies files from ```zynq/``` therefore making a copy which doesn't update when sources in ```zynq/``` update or the other way around. This has to be resolved. Only files from ```zynq/``` are included into the repository, so it is important to keep them up to date. So far in order to regenerate Vitis project with updated sources its directory ```vitis_ws/``` has to be deleted and the script re-executed.

#### TODO
- fix ```scripts/build_riscv_worker_ps_pl.py``` so it either deletes and properly retargets the new application component with new sources from ```zynq/``` or use other kind of magic to solve it.
- combine entire workflow into Makefile targets