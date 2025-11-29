`ifndef AXI_CONFIGURATION_VH
`define AXI_CONFIGURATION_VH

// Data bus details
`define C_AXI_DATA_WIDTH 32
`define C_AXI_ADDR_WIDTH 32
`define C_AXI_STROBE_WIDTH (`C_AXI_DATA_WIDTH / 8)
`define C_ADDR_LSB $clog2(`C_AXI_DATA_WIDTH / 8)    // bits used for the byte offset

// AXI write flags
// output by the slave

// BRESP & RRESP flags
`define AXI_RESP_OKAY 2'b00
`define AXI_RESP_EXOKAY 2'b01
`define AXI_RESP_SLVERR 2'b10
`define AXI_RESP_DECERR 2'b11

`endif
