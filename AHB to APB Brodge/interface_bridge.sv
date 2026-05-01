// ============================================================
//  ahb_apb_if.sv
//  Bundles all AHB-Lite slave signals + APB master signals
//  into one interface.  Clocking blocks keep driver/monitor
//  sampling edges unambiguous.
// ============================================================

interface ahb_apb_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic HCLK,
    input logic HRESETn
);

    // ----------------------------------------------------------
    //  AHB-Lite slave signals
    // ----------------------------------------------------------
    logic [ADDR_WIDTH-1:0]   HADDR;
    logic [DATA_WIDTH-1:0]   HWDATA;
    logic                    HWRITE;
    logic [1:0]              HTRANS;
    logic [2:0]              HSIZE;
    logic [2:0]              HBURST;
    logic                    HSEL;
    logic [DATA_WIDTH-1:0]   HRDATA;
    logic                    HREADYOUT;
    logic [1:0]              HRESP;

    // ----------------------------------------------------------
    //  APB master signals (driven by DUT, observed by monitors)
    // ----------------------------------------------------------
    logic [ADDR_WIDTH-1:0]   PADDR;
    logic [DATA_WIDTH-1:0]   PWDATA;
    logic                    PWRITE;
    logic                    PSEL;
    logic                    PENABLE;
    logic [DATA_WIDTH/8-1:0] PSTRB;
    logic [DATA_WIDTH-1:0]   PRDATA;   // driven by APB slave model
    logic                    PREADY;   // driven by APB slave model
    logic                    PSLVERR;  // driven by APB slave model

    // ----------------------------------------------------------
    //  Clocking block ? driver (AHB side)
    //  Drives on negedge, samples one full cycle later.
    // ----------------------------------------------------------
    clocking drv_cb @(posedge HCLK);
        default input  #1step output negedge;
        output HADDR, HWDATA, HWRITE, HTRANS, HSIZE, HBURST, HSEL;
        input  HRDATA, HREADYOUT, HRESP;
    endclocking

    // ----------------------------------------------------------
    //  Clocking block ? AHB write monitor
    // ----------------------------------------------------------
    clocking wr_mon_cb @(posedge HCLK);
        default input #1step;
        input HADDR, HWDATA, HWRITE, HTRANS, HSIZE, HBURST, HSEL,
              HRDATA, HREADYOUT, HRESP;
        input PADDR, PWDATA, PWRITE, PSEL, PENABLE, PSTRB,
              PREADY, PSLVERR;
    endclocking

    // ----------------------------------------------------------
    //  Clocking block ? AHB read monitor
    // ----------------------------------------------------------
    clocking rd_mon_cb @(posedge HCLK);
        default input #1step;
        input HADDR, HWDATA, HWRITE, HTRANS, HSIZE, HBURST, HSEL,
              HRDATA, HREADYOUT, HRESP;
        input PADDR, PWDATA, PWRITE, PSEL, PENABLE, PSTRB,
              PRDATA, PREADY, PSLVERR;
    endclocking

    // ----------------------------------------------------------
    //  Modports
    // ----------------------------------------------------------
    modport DRV  (clocking drv_cb,  input HCLK, HRESETn);
    modport WMON (clocking wr_mon_cb, input HCLK, HRESETn);
    modport RMON (clocking rd_mon_cb, input HCLK, HRESETn);

    // ----------------------------------------------------------
    //  Convenience task ? wait N clocks
    // ----------------------------------------------------------
    task automatic wait_clks(int n);
        repeat(n) @(posedge HCLK);
    endtask

endinterface : ahb_apb_if
