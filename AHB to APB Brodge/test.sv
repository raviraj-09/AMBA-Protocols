// ============================================================
//  test.sv
//  base_test + one directed test per address region
// ============================================================

`include "env.sv"

// ============================================================
//  BASE TEST ? low region  0x0000_0000 : 0x3FFF_FFFF
// ============================================================
class base_test #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    typedef env #(ADDR_WIDTH, DATA_WIDTH) env_t;

    env_t e;
    virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif;

    function new(virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif_);
        vif = vif_;
        e   = new(
            vif,
            32'h0000_0000,   // wr_base ? low region
            //32'h0000_1000,   // rd_base ? low region
            8,               // num_writes
            8                // num_reads
        );

e.build();
    endfunction

    task run();
        $display("[BASE_TEST] Starting ? LOW region");
        e.run();
        $display("[BASE_TEST] Done");
    endtask

endclass : base_test


// ============================================================
//  MID REGION TEST ? 0x4000_0000 : 0x7FFF_FFFF
// ============================================================
class mid_region_test #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    typedef env #(ADDR_WIDTH, DATA_WIDTH) env_t;

    env_t e;
    virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif;

    function new(virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif_);
        vif = vif_;
        e   = new(
            vif,
            32'h4000_0000,   // wr_base ? start of mid region
            32'h4000_1000,   // rd_base ? offset in mid region
            8,
            8
        );
e.build();
    endfunction

    task run();
        $display("[MID_TEST] Starting ? MID region 0x4000_0000");
        e.run();

     

        $display("[MID_TEST] Done");
    endtask

endclass : mid_region_test


// ============================================================
//  HIGH REGION TEST ? 0x8000_0000 : 0xBFFF_FFFF
// ============================================================
class high_region_test #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    typedef env #(ADDR_WIDTH, DATA_WIDTH) env_t;

    env_t e;
    virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif;

    function new(virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif_);
        vif = vif_;
        e   = new(
            vif,
            32'h8000_0000,   // wr_base ? start of high region
            32'h8000_1000,   // rd_base
            8,
            8
        );

	e.build();
    endfunction

    task run();
        $display("[HIGH_TEST] Starting ? HIGH region 0x8000_0000");
        

        
       
        e.run();

        $display("[HIGH_TEST] Done");
    endtask

endclass : high_region_test


// ============================================================
//  TOP REGION TEST ? 0xC000_0000 : 0xFFFF_FFFF
// ============================================================
class top_region_test #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    typedef env #(ADDR_WIDTH, DATA_WIDTH) env_t;

    env_t e;
    virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif;

    function new(virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif_);
        vif = vif_;
        e   = new(
            vif,
            32'hC000_0000,   // wr_base ? start of top region
            32'hC000_1000,   // rd_base
            8,
            8
        );

e.build();
    endfunction

    task run();
        $display("[TOP_TEST] Starting ? TOP region 0xC000_0000");
        e.run();

        // Also hit the END of top region
       
      

        $display("[TOP_TEST] Done");
    endtask

endclass : top_region_test
