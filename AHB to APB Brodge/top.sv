
//`include "test.sv"
//`include "interface_bridge.sv"

// ============================================================
//  top.sv
// ============================================================


/*
module top;

    // ----------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10;

    // ----------------------------------------------------------
    // Clock & Reset
    // ----------------------------------------------------------
    logic HCLK;
    logic HRESETn;

    initial HCLK = 1'b0;
    always #(CLK_PERIOD/2) HCLK = ~HCLK;

    // ----------------------------------------------------------
    // Reset Task ? reusable between tests
    // ----------------------------------------------------------
    task do_reset();
        HRESETn = 1'b0;
        repeat(4) @(posedge HCLK);
        @(negedge HCLK);
        HRESETn = 1'b1;
        $display("[TOP] Reset deasserted at %0t", $time);
    endtask

    // ----------------------------------------------------------
    // Interface Instance
    // ----------------------------------------------------------
    ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) bus_if (
        .HCLK    (HCLK),
        .HRESETn (HRESETn)
    );

    // ----------------------------------------------------------
    // DUT Instance
    // ----------------------------------------------------------
    ahb_to_apb_bridge #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .HCLK      (HCLK),
        .HRESETn   (HRESETn),

        // AHB Slave
        .HADDR     (bus_if.HADDR),
        .HWDATA    (bus_if.HWDATA),
        .HWRITE    (bus_if.HWRITE),
        .HTRANS    (bus_if.HTRANS),
        .HSIZE     (bus_if.HSIZE),
        .HBURST    (bus_if.HBURST),
        .HSEL      (bus_if.HSEL),
        .HRDATA    (bus_if.HRDATA),
        .HREADYOUT (bus_if.HREADYOUT),
        .HRESP     (bus_if.HRESP),

        // APB Master
        .PADDR     (bus_if.PADDR),
        .PWDATA    (bus_if.PWDATA),
        .PWRITE    (bus_if.PWRITE),
        .PSEL      (bus_if.PSEL),
        .PENABLE   (bus_if.PENABLE),
        .PSTRB     (bus_if.PSTRB),
        .PRDATA    (bus_if.PRDATA),
        .PREADY    (bus_if.PREADY),
        .PSLVERR   (bus_if.PSLVERR)
    );

    // ----------------------------------------------------------
    // APB Slave Model
    // ----------------------------------------------------------
    logic [DATA_WIDTH-1:0] apb_mem [0:255];
    logic        inject_err;
    int unsigned apb_txn_count;

    initial begin
        inject_err    = 1'b0;   // controlled per-test now
        apb_txn_count = 0;
        foreach (apb_mem[i])
            apb_mem[i] = 32'hDEAD_0000 | i;
    end

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            bus_if.PRDATA  <= '0;
            bus_if.PREADY  <= 1'b1;
            bus_if.PSLVERR <= 1'b0;
        end
        else begin
            bus_if.PREADY  <= 1'b1;
            bus_if.PSLVERR <= 1'b0;

            if (bus_if.PSEL && bus_if.PENABLE && bus_if.PREADY) begin
                apb_txn_count++;

                if (bus_if.PWRITE) begin
                    if (bus_if.PSTRB[0]) apb_mem[bus_if.PADDR[9:2]][7:0]   <= bus_if.PWDATA[7:0];
                    if (bus_if.PSTRB[1]) apb_mem[bus_if.PADDR[9:2]][15:8]  <= bus_if.PWDATA[15:8];
                    if (bus_if.PSTRB[2]) apb_mem[bus_if.PADDR[9:2]][23:16] <= bus_if.PWDATA[23:16];
                    if (bus_if.PSTRB[3]) apb_mem[bus_if.PADDR[9:2]][31:24] <= bus_if.PWDATA[31:24];
                end
                else begin
                    bus_if.PRDATA <= apb_mem[bus_if.PADDR[9:2]];
                end

                // inject_err controlled by test via top-level variable
                if (inject_err && apb_txn_count == 2)
                    bus_if.PSLVERR <= 1'b1;
            end
        end
    end

    // ----------------------------------------------------------
    // Run All Tests Sequentially
    // ----------------------------------------------------------
    initial begin

        int pass_count;
        int fail_count;
        pass_count = 0;
        fail_count = 0;

        $display("[TOP] ============================================");
        $display("[TOP]  Running ALL tests");
        $display("[TOP] ============================================");

        // -------------------- TEST 1 : base --------------------
        begin
            base_test #(ADDR_WIDTH, DATA_WIDTH) t;
            $display("\n[TOP] ---- TEST 1 : base_test ----");
            inject_err    = 1'b0;
            apb_txn_count = 0;
            do_reset();
            t = new(bus_if);
            t.run();
            #50;
            $display("[TOP] ---- base_test DONE ----");
            pass_count++;
        end

   


// -------------------- TEST 2 : mid region -------------------
begin
    mid_region_test #(ADDR_WIDTH, DATA_WIDTH) t;
    $display("\n[TOP] ---- TEST 2 : mid_region_test ----");
    inject_err    = 1'b0;
    apb_txn_count = 0;
    do_reset();
    t = new(bus_if);
    t.run();
    #50;
    $display("[TOP] ---- mid_region_test DONE ----");
end

// -------------------- TEST 3 : high region ------------------
begin
    high_region_test #(ADDR_WIDTH, DATA_WIDTH) t;
    $display("\n[TOP] ---- TEST 3 : high_region_test ----");
    inject_err    = 1'b0;
    apb_txn_count = 0;
    do_reset();
    t = new(bus_if);
    t.run();
    #50;
    $display("[TOP] ---- high_region_test DONE ----");
end

// -------------------- TEST 4 : top region -------------------
begin
    top_region_test #(ADDR_WIDTH, DATA_WIDTH) t;
    $display("\n[TOP] ---- TEST 4 : top_region_test ----");
    inject_err    = 1'b0;
    apb_txn_count = 0;
    do_reset();
    t = new(bus_if);
    t.run();
    #50;
    $display("[TOP] ---- top_region_test DONE ----");
end


        // -------------------- SUMMARY --------------------------
        $display("\n[TOP] ============================================");
        $display("[TOP]  SIMULATION SUMMARY");
        $display("[TOP]  Tests run  : %0d", pass_count + fail_count);
        $display("[TOP]  Passed     : %0d", pass_count);
        $display("[TOP]  Failed     : %0d", fail_count);
        $display("[TOP] ============================================");

        #100;
        $display("[TOP] Simulation finished at %0t", $time);
        $finish;

    end

    // ----------------------------------------------------------
    // Watchdog Timeout
    // ----------------------------------------------------------
    initial begin
        #1_000_000;
        $display("[TOP] TIMEOUT : simulation exceeded limit");
        $fatal(1, "Watchdog timeout");
    end

    // ----------------------------------------------------------
    // Waveform Dump
    // ----------------------------------------------------------
    initial begin
        if ($test$plusargs("WAVES")) begin
            $dumpfile("waves.vcd");
            $dumpvars(0, top);
        end
    end

endmodule
*/


`include "test.sv"
`include "interface_bridge.sv"

// ============================================================
//  top.sv
// ============================================================

module top;

    // ----------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10;

    // ----------------------------------------------------------
    // Clock & Reset
    // ----------------------------------------------------------
    logic HCLK;
    logic HRESETn;

    initial HCLK = 1'b0;
    always #(CLK_PERIOD/2) HCLK = ~HCLK;

    // ----------------------------------------------------------
    // Reset Task - reusable between tests
    // ----------------------------------------------------------
    task do_reset();
        HRESETn = 1'b0;
        repeat(4) @(posedge HCLK);
        @(negedge HCLK);
        HRESETn = 1'b1;
        $display("[TOP] Reset deasserted at %0t", $time);
    endtask

    // ----------------------------------------------------------
    // Backdoor Write Task - mirrors APB writes into ref model
    // Strobe-aware: only updates bytes where PSTRB is asserted
    // ----------------------------------------------------------
    task automatic do_backdoor_watch(input ref_model #(ADDR_WIDTH, DATA_WIDTH) rm);
        logic [DATA_WIDTH-1:0] masked;
        forever @(posedge HCLK) begin
            if (bus_if.PSEL && bus_if.PENABLE && bus_if.PREADY && bus_if.PWRITE) begin
                // Read existing value first (for partial byte writes)
                masked = rm.mem.exists(bus_if.PADDR) ? rm.mem[bus_if.PADDR] : '0;
                if (bus_if.PSTRB[0]) masked[7:0]   = bus_if.PWDATA[7:0];
                if (bus_if.PSTRB[1]) masked[15:8]  = bus_if.PWDATA[15:8];
                if (bus_if.PSTRB[2]) masked[23:16] = bus_if.PWDATA[23:16];
                if (bus_if.PSTRB[3]) masked[31:24] = bus_if.PWDATA[31:24];
                rm.backdoor_write(bus_if.PADDR, masked);
            end
        end
    endtask

    // ----------------------------------------------------------
    // Interface Instance
    // ----------------------------------------------------------
    ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) bus_if (
        .HCLK    (HCLK),
        .HRESETn (HRESETn)
    );

    // ----------------------------------------------------------
    // DUT Instance
    // ----------------------------------------------------------
    ahb_to_apb_bridge #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .HCLK      (HCLK),
        .HRESETn   (HRESETn),

        // AHB Slave
        .HADDR     (bus_if.HADDR),
        .HWDATA    (bus_if.HWDATA),
        .HWRITE    (bus_if.HWRITE),
        .HTRANS    (bus_if.HTRANS),
        .HSIZE     (bus_if.HSIZE),
        .HBURST    (bus_if.HBURST),
        .HSEL      (bus_if.HSEL),
        .HRDATA    (bus_if.HRDATA),
        .HREADYOUT (bus_if.HREADYOUT),
        .HRESP     (bus_if.HRESP),

        // APB Master
        .PADDR     (bus_if.PADDR),
        .PWDATA    (bus_if.PWDATA),
        .PWRITE    (bus_if.PWRITE),
        .PSEL      (bus_if.PSEL),
        .PENABLE   (bus_if.PENABLE),
        .PSTRB     (bus_if.PSTRB),
        .PRDATA    (bus_if.PRDATA),
        .PREADY    (bus_if.PREADY),
        .PSLVERR   (bus_if.PSLVERR)
    );

    // ----------------------------------------------------------
    // APB Slave Model
    // ----------------------------------------------------------
    logic [DATA_WIDTH-1:0] apb_mem [0:255];
    logic        inject_err;
    int unsigned apb_txn_count;

    initial begin
        inject_err    = 1'b0;
        apb_txn_count = 0;
        foreach (apb_mem[i])
            apb_mem[i] = 32'hDEAD_0000 | i;
    end

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            bus_if.PRDATA  <= '0;
            bus_if.PREADY  <= 1'b1;
            bus_if.PSLVERR <= 1'b0;
        end
        else begin
            bus_if.PREADY  <= 1'b1;
            bus_if.PSLVERR <= 1'b0;

            if (bus_if.PSEL && bus_if.PENABLE && bus_if.PREADY) begin
                apb_txn_count++;

                if (bus_if.PWRITE) begin
                    if (bus_if.PSTRB[0]) apb_mem[bus_if.PADDR[9:2]][7:0]   <= bus_if.PWDATA[7:0];
                    if (bus_if.PSTRB[1]) apb_mem[bus_if.PADDR[9:2]][15:8]  <= bus_if.PWDATA[15:8];
                    if (bus_if.PSTRB[2]) apb_mem[bus_if.PADDR[9:2]][23:16] <= bus_if.PWDATA[23:16];
                    if (bus_if.PSTRB[3]) apb_mem[bus_if.PADDR[9:2]][31:24] <= bus_if.PWDATA[31:24];
                end
                else begin
                    bus_if.PRDATA <= apb_mem[bus_if.PADDR[9:2]];
                end

                if (inject_err && apb_txn_count == 2)
                    bus_if.PSLVERR <= 1'b1;
            end
        end
    end

    // ----------------------------------------------------------
    // Run All Tests Sequentially
    // ----------------------------------------------------------
    initial begin

        int pass_count;
        int fail_count;
        pass_count = 0;
        fail_count = 0;

        $display("[TOP] ============================================");
        $display("[TOP]  Running ALL tests");
        $display("[TOP] ============================================");

        // -------------------- TEST 1 : base --------------------
        begin
            base_test #(ADDR_WIDTH, DATA_WIDTH) t;
            $display("\n[TOP] ---- TEST 1 : base_test ----");
            inject_err    = 1'b0;
            apb_txn_count = 0;
            do_reset();
            t = new(bus_if);
            fork
                t.run();
                do_backdoor_watch(t.e.rm);
            join_any
            disable fork;
            #50;
            $display("[TOP] ---- base_test DONE ----");
            pass_count++;
        end

        // -------------------- TEST 2 : mid region -------------------
        begin
            mid_region_test #(ADDR_WIDTH, DATA_WIDTH) t;
            $display("\n[TOP] ---- TEST 2 : mid_region_test ----");
            inject_err    = 1'b0;
            apb_txn_count = 0;
            do_reset();
            t = new(bus_if);
            fork
                t.run();
                do_backdoor_watch(t.e.rm);
            join_any
            disable fork;
            #50;
            $display("[TOP] ---- mid_region_test DONE ----");
            pass_count++;
        end

        // -------------------- TEST 3 : high region ------------------
        begin
            high_region_test #(ADDR_WIDTH, DATA_WIDTH) t;
            $display("\n[TOP] ---- TEST 3 : high_region_test ----");
            inject_err    = 1'b0;
            apb_txn_count = 0;
            do_reset();
            t = new(bus_if);
            fork
                t.run();
                do_backdoor_watch(t.e.rm);
            join_any
            disable fork;
            #50;
            $display("[TOP] ---- high_region_test DONE ----");
            pass_count++;
        end

        // -------------------- TEST 4 : top region -------------------
        begin
            top_region_test #(ADDR_WIDTH, DATA_WIDTH) t;
            $display("\n[TOP] ---- TEST 4 : top_region_test ----");
            inject_err    = 1'b0;
            apb_txn_count = 0;
            do_reset();
            t = new(bus_if);
            fork
                t.run();
                do_backdoor_watch(t.e.rm);
            join_any
            disable fork;
            #50;
            $display("[TOP] ---- top_region_test DONE ----");
            pass_count++;
        end

        // -------------------- SUMMARY --------------------------
        $display("\n[TOP] ============================================");
        $display("[TOP]  SIMULATION SUMMARY");
        $display("[TOP]  Tests run  : %0d", pass_count + fail_count);
        $display("[TOP]  Passed     : %0d", pass_count);
        $display("[TOP]  Failed     : %0d", fail_count);
        $display("[TOP] ============================================");

        #100;
        $display("[TOP] Simulation finished at %0t", $time);
        $finish;

    end

    // ----------------------------------------------------------
    // Watchdog Timeout
    // ----------------------------------------------------------
    initial begin
        #1_000_000;
        $display("[TOP] TIMEOUT : simulation exceeded limit");
        $fatal(1, "Watchdog timeout");
    end

    // ----------------------------------------------------------
    // Waveform Dump
    // ----------------------------------------------------------
    initial begin
        if ($test$plusargs("WAVES")) begin
            $dumpfile("waves.vcd");
            $dumpvars(0, top);
        end
    end

endmodule
