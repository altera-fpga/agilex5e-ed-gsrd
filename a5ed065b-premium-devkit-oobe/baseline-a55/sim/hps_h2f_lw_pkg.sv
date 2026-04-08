// Defines constants for HPS to FPGA LW bridge interface
package hps_h2f_lw_pkg;

    localparam LWH2F_DATA_WIDTH = 32;
    localparam LWH2F_ADDR_WIDTH = 29;
    localparam LWH2F_SYMBOLS_PER_WORD = LWH2F_DATA_WIDTH / 8;

    // Addresses from Qsys system. These addresses are relative to the bridge,
    // not relative to the HPS
    localparam LWH2F_BUTTON_PIO_BASE_ADDR = 32'h0001_0060;
    localparam LWH2F_BUTTON_PIO_SIZE = 32'h0000_0010;
    localparam LWH2F_DIPSW_PIO_BASE_ADDR = 32'h0001_0070;
    localparam LWH2F_DIPSW_PIO_SIZE = 32'h0000_0010;
    localparam LWH2F_LED_PIO_BASE_ADDR = 32'h0001_0080;
    localparam LWH2F_LED_PIO_SIZE = 32'h0000_0010;
    localparam LWH2F_SYSID_BASE_ADDR = 32'h0001_0000;
    localparam LWH2F_SYSID_SIZE = 32'h0000_0010;
    localparam LWH2F_SYSID_VALUE = 32'h0000_0001;

endpackage
