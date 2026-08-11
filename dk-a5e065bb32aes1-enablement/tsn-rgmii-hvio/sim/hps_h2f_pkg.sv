// Defines constants for HPS to FPGA bridge interface
package hps_h2f_pkg;

    localparam H2F_ID_WIDTH = 4;
    localparam H2F_DATA_WIDTH = 128;
    localparam H2F_ADDR_WIDTH = 38;
    localparam H2F_SYMBOLS_PER_WORD = H2F_DATA_WIDTH / 8;

    // Addresses from Qsys system. These addresses are relative to the bridge,
    // not relative to the HPS
    localparam H2F_OCRAM_BASE_ADDR = 32'h0000_0000;
    localparam H2F_OCRAM_SIZE = 32'h0004_0000;

endpackage
