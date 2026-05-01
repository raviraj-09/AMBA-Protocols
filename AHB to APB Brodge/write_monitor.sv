// ============================================================
//  monitor.sv
//  Two monitor classes:
//    write_monitor  ? observes completed APB write transactions
//    read_monitor   ? observes completed APB read  transactions
//                     and pushes results into a mailbox for the
//                     reference model.
//
//  Monitors watch the APB side (PSEL/PENABLE/PREADY handshake)
//  so they capture what the DUT actually drove onto the bus,
//  independent of the AHB stimulus.
// ============================================================

//`include "transaction.sv"

// ============================================================
//  write_monitor
// ============================================================
class write_monitor #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);

    typedef transaction #(ADDR_WIDTH, DATA_WIDTH) txn_t;

    virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif;
    mailbox #(txn_t) mbx; // ? scoreboard

txn_t current_txn;
/*
    function new(
        virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif_,
        mailbox #(txn_t) mbx_
    );
        vif = vif_;
        mbx = mbx_;
    endfunction
*/



    

    // --------------------------------------------------------
    //  Covergroup ? declared inside the class
    // --------------------------------------------------------
    covergroup apb_write_cg;

        cp_paddr : coverpoint current_txn.addr {
            bins low_region  = {[32'h0000_0000 : 32'h3FFF_FFFF]};
            bins mid_region  = {[32'h4000_0000 : 32'h7FFF_FFFF]};
            bins high_region = {[32'h8000_0000 : 32'hBFFF_FFFF]};
            bins top_region  = {[32'hC000_0000 : 32'hFFFF_FFFF]};
        }

        cp_pwdata : coverpoint current_txn.data {
            bins all_zeros = {32'h0000_0000};
            bins all_ones  = {32'hFFFF_FFFF};
            bins walk_ones = {32'h0000_0001, 32'h0000_0002, 32'h0000_0004,
                              32'h0000_0008, 32'h0000_0010, 32'h0000_0020,
                              32'h0000_0040, 32'h0000_0080};
            bins typical   = default;
        }

        cp_pstrb : coverpoint current_txn.strb {
            bins no_bytes    = {4'b0000};
            bins byte0_only  = {4'b0001};
            bins byte1_only  = {4'b0010};
            bins byte2_only  = {4'b0100};
            bins byte3_only  = {4'b1000};
            bins lower_half  = {4'b0011};
            bins upper_half  = {4'b1100};
            bins lower_three = {4'b0111};
            bins upper_three = {4'b1110};
            bins all_bytes   = {4'b1111};
            bins other       = default;
        }

        cp_hsize : coverpoint current_txn.size {
            bins byte_xfer     = {3'b000};
            bins halfword_xfer = {3'b001};
            bins word_xfer     = {3'b010};
            bins reserved      = {[3'b011 : 3'b111]};
        }

        cp_pslverr : coverpoint current_txn.pslverr {
            bins ok    = {1'b0};
            bins error = {1'b1};
        }

        cp_addr_align : coverpoint get_alignment(current_txn.addr,
                                                 current_txn.size) {
            bins aligned    = {1'b1};
            bins misaligned = {1'b0};
        }

        cx_strb_x_size  : cross cp_pstrb, cp_hsize;
        cx_addr_x_err   : cross cp_paddr, cp_pslverr;
        cx_align_x_err  : cross cp_addr_align, cp_pslverr;

    endgroup : apb_write_cg

    // --------------------------------------------------------
    //  Constructor
    // --------------------------------------------------------
    function new(
        virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif_,
        mailbox #(txn_t) mbx_
    );
        vif          = vif_;
        mbx          = mbx_;
        apb_write_cg = new();   // instantiate covergroup here
    endfunction

    // --------------------------------------------------------
    //  Helper : alignment check
    // --------------------------------------------------------
    function automatic logic get_alignment(
        logic [ADDR_WIDTH-1:0] addr,
        logic [2:0]            size
    );
        case (size)
            3'b000  : return 1'b1;                // byte  ? always aligned
            3'b001  : return (addr[0]    == 1'b0); // halfword
            3'b010  : return (addr[1:0]  == 2'b00);// word
            3'b011  : return (addr[2:0]  == 3'b000);// dword
            default : return 1'b0;
        endcase
    endfunction

    // --------------------------------------------------------
    //  Run
    // --------------------------------------------------------
    task run();
        txn_t t;
        $display("[WR_MON] Started");
        forever begin
            @(vif.wr_mon_cb);
            if (vif.wr_mon_cb.PSEL    &&
                vif.wr_mon_cb.PENABLE &&
                vif.wr_mon_cb.PWRITE  &&
                vif.wr_mon_cb.PREADY)
            begin
                t = new();
                t.direction = txn_t::WRITE;
                t.addr      = vif.wr_mon_cb.PADDR;
                t.data      = vif.wr_mon_cb.PWDATA;
                t.strb      = vif.wr_mon_cb.PSTRB;
                t.pslverr   = vif.wr_mon_cb.PSLVERR;
                t.size      = vif.wr_mon_cb.HSIZE;
                $display("[WR_MON] Captured %s", t.to_str());
                mbx.put(t);

                // ---------- sample coverage ----------
                current_txn = t;
                apb_write_cg.sample();
                // -------------------------------------
            end
        end
    endtask

    // --------------------------------------------------------
    //  Report ? call from env/scoreboard at end of sim
    // --------------------------------------------------------
    function void report();
        $display("------------------------------------------------");
        $display("[WR_MON COV] APB Write Coverage  = %.2f%%",
                  apb_write_cg.get_coverage());
        $display("[WR_MON COV]   cp_paddr          = %.2f%%",
                  apb_write_cg.cp_paddr.get_coverage());
        $display("[WR_MON COV]   cp_pwdata         = %.2f%%",
                  apb_write_cg.cp_pwdata.get_coverage());
        $display("[WR_MON COV]   cp_pstrb          = %.2f%%",
                  apb_write_cg.cp_pstrb.get_coverage());
        $display("[WR_MON COV]   cp_hsize          = %.2f%%",
                  apb_write_cg.cp_hsize.get_coverage());
        $display("[WR_MON COV]   cp_pslverr        = %.2f%%",
                  apb_write_cg.cp_pslverr.get_coverage());
        $display("[WR_MON COV]   cp_addr_align     = %.2f%%",
                  apb_write_cg.cp_addr_align.get_coverage());
        $display("------------------------------------------------");
    endfunction

endclass : write_monitor


