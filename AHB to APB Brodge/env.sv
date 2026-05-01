// ============================================================
//  env.sv
//  Wires up all TB components.  Owns all mailboxes.
//  Tests instantiate env and call build() then run().
// ============================================================

`include "ahb_transaction.sv"
`include "generator_bridge.sv"
`include "ahb_write_driver.sv"
`include "ahb_read_driver.sv"
`include "write_monitor.sv"
`include "read_monitor.sv"
`include "reference_model.sv"
`include "scoreboard.sv"

class env #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);

    typedef transaction #(ADDR_WIDTH, DATA_WIDTH) txn_t;
bit [ADDR_WIDTH - 1: 0] wr_base;
bit [ADDR_WIDTH - 1 : 0] rd_base;

    // ----------------------------------------------------------
    //  Component handles
    // ----------------------------------------------------------
    generator  #(ADDR_WIDTH, DATA_WIDTH) gen;
    write_driver  #(ADDR_WIDTH, DATA_WIDTH) wr_drv;
    read_driver   #(ADDR_WIDTH, DATA_WIDTH) rd_drv;
    write_monitor #(ADDR_WIDTH, DATA_WIDTH) wr_mon;
    read_monitor  #(ADDR_WIDTH, DATA_WIDTH) rd_mon;
    ref_model     #(ADDR_WIDTH, DATA_WIDTH) rm;
    scoreboard    #(ADDR_WIDTH, DATA_WIDTH) scb;

    // ----------------------------------------------------------
    //  Mailboxes
    // ----------------------------------------------------------
    mailbox #(txn_t) gen_wr_mbx;    // generator  ? write_driver
    mailbox #(txn_t) gen_rd_mbx;    // generator  ? read_driver
    mailbox #(txn_t) wr_mon_mbx;    // wr_monitor ? scoreboard (observed)
    mailbox #(txn_t) rd_mon_mbx;    // rd_monitor ? ref_model
    mailbox #(txn_t) ref_scb_mbx;   // ref_model  ? scoreboard (expected reads)
    mailbox #(txn_t) wr_exp_mbx;    // generator  ? scoreboard (expected writes)

    // Virtual interface handle
    virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif;

    // Test knobs
    int unsigned num_writes;
    int unsigned num_reads;

  

 function new(
	virtual ahb_apb_if #(ADDR_WIDTH,DATA_WIDTH) vif_,
        bit [ADDR_WIDTH-1:0] wr_base = 32'h0000_0000,
        bit [ADDR_WIDTH-1:0] rd_base = 32'h0000_1000,
        int unsigned         nw      = 8,
        int unsigned         nr      = 8
    );
       
	vif = vif_;
	num_writes = nw;
	num_reads = nr;
	this.wr_base = wr_base;
	this.rd_base = rd_base;
       
       
    endfunction

    // ----------------------------------------------------------
    //  Build: create mailboxes and components
    // ----------------------------------------------------------
    function void build();
        gen_wr_mbx  = new();
        gen_rd_mbx  = new();
        wr_mon_mbx  = new();
        rd_mon_mbx  = new();
        ref_scb_mbx = new();
        wr_exp_mbx  = new();

	 gen = new(gen_wr_mbx, gen_rd_mbx, num_writes, num_reads, wr_base, rd_base);

       // gen    = new(gen_wr_mbx, gen_rd_mbx, num_writes, num_reads);
        wr_drv = new(vif, gen_wr_mbx);
        rd_drv = new(vif, gen_rd_mbx);
        wr_mon = new(vif, wr_mon_mbx);
        rd_mon = new(vif, rd_mon_mbx);
        rm     = new(rd_mon_mbx, ref_scb_mbx);
        scb    = new(wr_mon_mbx, ref_scb_mbx, wr_exp_mbx);

        $display("[ENV] Build complete");
    endfunction

   
    task run();
        $display("[ENV] Run started");

        // Start background monitors, ref model, scoreboard
        fork
            wr_mon.run();
            rd_mon.run();
            rm.run();
            scb.run();
        join_none

        // Generate all stimulus first
        gen.run();

        // Clone write transactions into wr_exp_mbx for scoreboard.
        // We drain gen_wr_mbx, copy into both the driver mbx and exp mbx.
        begin
            txn_t t;
            mailbox #(txn_t) tmp = new();
            // Move from gen_wr_mbx ? tmp + wr_exp_mbx
            while (gen_wr_mbx.num() > 0) begin
                gen_wr_mbx.get(t);
                tmp.put(t.copy());
                wr_exp_mbx.put(t.copy());
            end
            // Refill gen_wr_mbx for driver
            while (tmp.num() > 0) begin
                tmp.get(t);
                gen_wr_mbx.put(t);
            end
        end

        // Run drivers sequentially (write, then read)
        // Fork them if you need simultaneous stimulus
        wr_drv.run();
        rd_drv.run();

        // Allow monitors/scoreboard to drain remaining transactions
        #500;

        $display("[ENV] Run complete");
    endtask

    // ----------------------------------------------------------
    //  Report
    // ----------------------------------------------------------
    function void report();
        rm.report();
        scb.report();
    endfunction

endclass : env
