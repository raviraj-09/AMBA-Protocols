

`timescale 1ns/1ps

module tb_ahb_to_apb_bridge;

    // ============================================================
    //  Parameters
    // ============================================================
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter MEM_DEPTH  = 16;

    // ============================================================
    //  DUT signals
    // ============================================================
    reg                      HCLK;
    reg                      HRESETn;

    reg  [ADDR_WIDTH-1:0]    HADDR;
    reg  [DATA_WIDTH-1:0]    HWDATA;
    reg                      HWRITE;
    reg  [1:0]               HTRANS;
    reg  [2:0]               HSIZE;
    reg  [2:0]               HBURST;
    reg                      HSEL;
    wire [DATA_WIDTH-1:0]    HRDATA;
    wire                     HREADYOUT;
    wire [1:0]               HRESP;

    wire [ADDR_WIDTH-1:0]    PADDR;
    wire [DATA_WIDTH-1:0]    PWDATA;
    wire                     PWRITE;
    wire                     PSEL;
    wire                     PENABLE;
    wire [DATA_WIDTH/8-1:0]  PSTRB;
    reg  [DATA_WIDTH-1:0]    PRDATA;
    wire                     PREADY;
    wire                     PSLVERR;

    // ============================================================
    //  DUT instantiation
    // ============================================================
    ahb_to_apb_bridge #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .HCLK      (HCLK),      .HRESETn   (HRESETn),
        .HADDR     (HADDR),     .HWDATA    (HWDATA),
        .HWRITE    (HWRITE),    .HTRANS    (HTRANS),
        .HSIZE     (HSIZE),     .HBURST    (HBURST),
        .HSEL      (HSEL),      .HRDATA    (HRDATA),
        .HREADYOUT (HREADYOUT), .HRESP     (HRESP),
        .PADDR     (PADDR),     .PWDATA    (PWDATA),
        .PWRITE    (PWRITE),    .PSEL      (PSEL),
        .PENABLE   (PENABLE),   .PSTRB     (PSTRB),
        .PRDATA    (PRDATA),    .PREADY    (PREADY),
        .PSLVERR   (PSLVERR)
    );

    // ============================================================
    //  Clock
    // ============================================================
    initial HCLK = 0;
    always #5 HCLK = ~HCLK;

    // ============================================================
    //  APB slave model
    //  16-word memory, always ready, no errors.
    //  PRDATA combinational so it is stable before posedge.
    // ============================================================
    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    reg [DATA_WIDTH-1:0] slave_mem [0:MEM_DEPTH-1];
    integer i;

    always @(posedge HCLK) begin
        if (PSEL && PENABLE && PREADY && PWRITE)
            slave_mem[PADDR[5:2]] <= PWDATA;
    end

    always @(*) begin
        if (PSEL && !PWRITE)
            PRDATA = slave_mem[PADDR[5:2]];
        else
            PRDATA = {DATA_WIDTH{1'b0}};
    end

    // ============================================================
    //  Tracking
    // ============================================================
    integer      pass_count;
    integer      fail_count;
    reg [DATA_WIDTH-1:0] rd_buf [0:3];

    // ============================================================
    //  Task: wait_hready
    //  Advance to the posedge where HREADYOUT is high.
    // ============================================================
    task wait_hready;
        begin
            @(posedge HCLK);
            while (!HREADYOUT) @(posedge HCLK);
        end
    endtask

    // ============================================================
    //  Task: check_read
    // ============================================================
    task check_read;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] expected;
        input [DATA_WIDTH-1:0] got;
        begin
            if (got === expected) begin
                $display("    PASS : addr=0x%08h  exp=0x%08h  got=0x%08h",
                         addr, expected, got);
                pass_count = pass_count + 1;
            end else begin
                $display("    FAIL : addr=0x%08h  exp=0x%08h  got=0x%08h",
                         addr, expected, got);
                fail_count = fail_count + 1;
            end
        end
    endtask

   
    task incr4_write;
        input [ADDR_WIDTH-1:0] base;
        input [DATA_WIDTH-1:0] d0, d1, d2, d3;
        begin
            // Beat 0 address phase
            @(posedge HCLK);
            HSEL   <= 1;
            HTRANS <= 2'b10;   // NONSEQ
            HWRITE <= 1;
            HADDR  <= base;
            HSIZE  <= 3'b010;
            HBURST <= 3'b011;  // INCR4

            // Beat 0 completes → present beat 1 address + beat 0 data
            wait_hready;
            HWDATA <= d0;
            HTRANS <= 2'b11;   // SEQ
            HADDR  <= base + 32'h4;

            // Beat 1 completes → present beat 2 address + beat 1 data
            wait_hready;
            HWDATA <= d1;
            HTRANS <= 2'b11;
            HADDR  <= base + 32'h8;

            // Beat 2 completes → present beat 3 address + beat 2 data
            wait_hready;
            HWDATA <= d2;
            HTRANS <= 2'b11;
            HADDR  <= base + 32'hC;

            // Beat 3 completes → IDLE + beat 3 data
            wait_hready;
            HWDATA <= d3;
            HTRANS <= 2'b00;   // IDLE
            HSEL   <= 0;

            // Wait for last APB transaction to finish
            wait_hready;
        end
    endtask

 
    task incr4_read;
        input [ADDR_WIDTH-1:0] base;
        begin
            // Beat 0 address phase
            @(posedge HCLK);
            HSEL   <= 1;
            HTRANS <= 2'b10;   // NONSEQ
            HWRITE <= 0;
            HADDR  <= base;
            HSIZE  <= 3'b010;
            HBURST <= 3'b011;  // INCR4

            // Beat 0 APB completes (HREADYOUT=1)
            // Present beat 1 address on this same edge
            wait_hready;
            HTRANS <= 2'b11;
            HADDR  <= base + 32'h4;
            // One extra cycle for HRDATA to settle after posedge
            @(posedge HCLK);
            rd_buf[0] = HRDATA;   // beat 0 data now valid

            // Beat 1 APB completes
            while (!HREADYOUT) @(posedge HCLK);
            HTRANS <= 2'b11;
            HADDR  <= base + 32'h8;
            @(posedge HCLK);
            rd_buf[1] = HRDATA;   // beat 1 data now valid

            // Beat 2 APB completes
            while (!HREADYOUT) @(posedge HCLK);
            HTRANS <= 2'b11;
            HADDR  <= base + 32'hC;
            @(posedge HCLK);
            rd_buf[2] = HRDATA;   // beat 2 data now valid

            // Beat 3 APB completes
            while (!HREADYOUT) @(posedge HCLK);
            HTRANS <= 2'b00;   // IDLE
            HSEL   <= 0;
            @(posedge HCLK);
            rd_buf[3] = HRDATA;   // beat 3 data now valid

            wait_hready;
        end
    endtask

    task wrap4_write;
        input [ADDR_WIDTH-1:0] start;
        input [DATA_WIDTH-1:0] d0, d1, d2, d3;
        reg   [ADDR_WIDTH-1:0] wb;
        reg   [ADDR_WIDTH-1:0] a0, a1, a2, a3;
        begin
            wb = start & 32'hFFFF_FFF0;
            a0 = start;
            a1 = wb | ((start + 32'h4) & 32'hF);
            a2 = wb | ((start + 32'h8) & 32'hF);
            a3 = wb | ((start + 32'hC) & 32'hF);

            $display("    Wrap addresses: 0x%08h 0x%08h 0x%08h 0x%08h",
                     a0, a1, a2, a3);

            @(posedge HCLK);
            HSEL   <= 1;
            HTRANS <= 2'b10;   // NONSEQ
            HWRITE <= 1;
            HADDR  <= a0;
            HSIZE  <= 3'b010;
            HBURST <= 3'b010;  // WRAP4

            wait_hready;
            HWDATA <= d0;
            HTRANS <= 2'b11;
            HADDR  <= a1;

            wait_hready;
            HWDATA <= d1;
            HTRANS <= 2'b11;
            HADDR  <= a2;

            wait_hready;
            HWDATA <= d2;
            HTRANS <= 2'b11;
            HADDR  <= a3;

            wait_hready;
            HWDATA <= d3;
            HTRANS <= 2'b00;
            HSEL   <= 0;

            wait_hready;
        end
    endtask


    task wrap4_read;
        input [ADDR_WIDTH-1:0] start;
        reg   [ADDR_WIDTH-1:0] wb;
        reg   [ADDR_WIDTH-1:0] a0, a1, a2, a3;
        begin
            wb = start & 32'hFFFF_FFF0;
            a0 = start;
            a1 = wb | ((start + 32'h4) & 32'hF);
            a2 = wb | ((start + 32'h8) & 32'hF);
            a3 = wb | ((start + 32'hC) & 32'hF);

            @(posedge HCLK);
            HSEL   <= 1;
            HTRANS <= 2'b10;   // NONSEQ
            HWRITE <= 0;
            HADDR  <= a0;
            HSIZE  <= 3'b010;
            HBURST <= 3'b010;  // WRAP4

            wait_hready;
            HTRANS <= 2'b11;
            HADDR  <= a1;
            @(posedge HCLK);
            rd_buf[0] = HRDATA;

            while (!HREADYOUT) @(posedge HCLK);
            HTRANS <= 2'b11;
            HADDR  <= a2;
            @(posedge HCLK);
            rd_buf[1] = HRDATA;

            while (!HREADYOUT) @(posedge HCLK);
            HTRANS <= 2'b11;
            HADDR  <= a3;
            @(posedge HCLK);
            rd_buf[2] = HRDATA;

            while (!HREADYOUT) @(posedge HCLK);
            HTRANS <= 2'b00;
            HSEL   <= 0;
            @(posedge HCLK);
            rd_buf[3] = HRDATA;

            wait_hready;
        end
    endtask

    // ============================================================
    //  Stimulus
    // ============================================================
    initial begin
        $dumpfile("tb_ahb_to_apb_bridge.vcd");
        $dumpvars(0, tb_ahb_to_apb_bridge);

        pass_count = 0;
        fail_count = 0;

        for (i = 0; i < MEM_DEPTH; i = i + 1)
            slave_mem[i] = 32'h0;

        HRESETn = 0;
        HSEL    = 0;
        HTRANS  = 2'b00;
        HWRITE  = 0;
        HADDR   = 0;
        HWDATA  = 0;
        HSIZE   = 3'b010;
        HBURST  = 3'b000;

        repeat(3) @(posedge HCLK);
        HRESETn = 1;
        repeat(2) @(posedge HCLK);

        // ============================================================
        //  TEST 1 : INCR4 write
        // ============================================================
        $display("");
        $display("========================================");
        $display(" TEST 1 : INCR4 Write Burst");
        $display(" Base = 0xA000_0000");
        $display("========================================");

        incr4_write(32'hA000_0000,
                    32'hAAAA_0001, 32'hAAAA_0002,
                    32'hAAAA_0003, 32'hAAAA_0004);

        repeat(3) @(posedge HCLK);

        // ============================================================
        //  TEST 2 : INCR4 read
        // ============================================================
        $display("");
        $display("========================================");
        $display(" TEST 2 : INCR4 Read Burst");
        $display(" Base = 0xA000_0000");
        $display("========================================");

        incr4_read(32'hA000_0000);

        check_read(32'hA000_0000, 32'hAAAA_0001, rd_buf[0]);
        check_read(32'hA000_0004, 32'hAAAA_0002, rd_buf[1]);
        check_read(32'hA000_0008, 32'hAAAA_0003, rd_buf[2]);
        check_read(32'hA000_000C, 32'hAAAA_0004, rd_buf[3]);

        repeat(3) @(posedge HCLK);

        // ============================================================
        //  TEST 3 : WRAP4 write  (start mid-boundary to force wrap)
        // ============================================================
        $display("");
        $display("========================================");
        $display(" TEST 3 : WRAP4 Write Burst");
        $display(" Start = 0xA000_0008  (wraps at 0xA000_0010)");
        $display("========================================");

        wrap4_write(32'hA000_0008,
                    32'hBBBB_0001, 32'hBBBB_0002,
                    32'hBBBB_0003, 32'hBBBB_0004);

        repeat(3) @(posedge HCLK);

        // ============================================================
        //  TEST 4 : WRAP4 read
        //  Expected data at wrapped addresses:
        //    0xA000_0008 <- BBBB_0001  (beat 0)
        //    0xA000_000C <- BBBB_0002  (beat 1)
        //    0xA000_0000 <- BBBB_0003  (beat 2, wrapped)
        //    0xA000_0004 <- BBBB_0004  (beat 3)
        // ============================================================
        $display("");
        $display("========================================");
        $display(" TEST 4 : WRAP4 Read Burst");
        $display(" Start = 0xA000_0008");
        $display("========================================");

        wrap4_read(32'hA000_0008);

        check_read(32'hA000_0008, 32'hBBBB_0001, rd_buf[0]);
        check_read(32'hA000_000C, 32'hBBBB_0002, rd_buf[1]);
        check_read(32'hA000_0000, 32'hBBBB_0003, rd_buf[2]);
        check_read(32'hA000_0004, 32'hBBBB_0004, rd_buf[3]);

        repeat(3) @(posedge HCLK);

        // ============================================================
        //  Summary
        // ============================================================
        $display("");
        $display("========================================");
        $display(" RESULTS : %0d PASSED  %0d FAILED",
                 pass_count, fail_count);
        $display("========================================");
        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" SOME TESTS FAILED - check waveform");
        $display("");
        $finish;
    end

endmodule