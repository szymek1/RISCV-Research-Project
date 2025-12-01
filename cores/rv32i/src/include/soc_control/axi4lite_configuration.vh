`ifndef AXI4LITE_CONFIGURATION_V
`define AXI4LITE_CONFIGURATION_V

// Data bus details
`define C_AXI_DATA_WIDTH   32
`define C_REGISTERS_NUMBER 32
`define C_AXI_STROBE_WIDTH (`C_AXI_DATA_WIDTH / 8)
`define C_ADDR_LSB $clog2(`C_AXI_DATA_WIDTH / 8)    // bits used for the byte offset
`define C_ADDR_REG_BITS $clog2(`C_REGISTERS_NUMBER) // bits used for register index
`define C_AXI_ADDR_WIDTH (`C_ADDR_LSB + `C_ADDR_REG_BITS)

// AXI write flags
// BRESP & RRESP flags
`define AXI_RESP_OKAY   2'b00
`define AXI_RESP_EXOKAY 2'b01
`define AXI_RESP_SLVERR 2'b10
`define AXI_RESP_DECERR 2'b11

`endif