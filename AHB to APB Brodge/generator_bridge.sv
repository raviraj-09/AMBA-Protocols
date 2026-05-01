// ============================================================
//  generator.sv
// ============================================================
class generator #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    typedef transaction #(ADDR_WIDTH, DATA_WIDTH) txn_t;

    // ----------------------------------------------------------
    //  Mailbox handles
    // ----------------------------------------------------------
    mailbox #(txn_t) wr_mbx;
    mailbox #(txn_t) rd_mbx;

    int unsigned        num_writes;
    int unsigned        num_reads;

    // ----------------------------------------------------------
    //  Configurable base addresses (set by test)
    // ----------------------------------------------------------
    bit [ADDR_WIDTH-1:0] wr_base_addr;
    bit [ADDR_WIDTH-1:0] rd_base_addr;

    // ----------------------------------------------------------
    //  Constructor
    // ----------------------------------------------------------
    function new(
        mailbox #(txn_t) wr_mbx_,
        mailbox #(txn_t) rd_mbx_,
        int unsigned         nw      = 8,
        int unsigned         nr      = 8,
        bit [ADDR_WIDTH-1:0] wr_base = 32'h0000_0000,
        bit [ADDR_WIDTH-1:0] rd_base = 32'h0000_1000
    );
        wr_mbx       = wr_mbx_;
        rd_mbx       = rd_mbx_;
        num_writes   = nw;
        num_reads    = nr;
        wr_base_addr = wr_base;
        rd_base_addr = rd_base;
    endfunction

    // ----------------------------------------------------------
    //  Single WRITE
    // ----------------------------------------------------------
    function txn_t make_write(
        bit [ADDR_WIDTH-1:0] addr,
        bit [DATA_WIDTH-1:0] data,
        bit [2:0]            size = 3'b010
    );
        txn_t t = new();
        if (!t.randomize() with {   //inline constraint
            this.addr       == addr;
            this.data       == data;
            this.direction  == txn_t::WRITE;
            this.size       == size;
            this.trans_type == txn_t::NONSEQ;
            this.burst_type == txn_t::SINGLE;
        }) $fatal(1, "[GEN] make_write randomize() failed");
        return t;
    endfunction

    // ----------------------------------------------------------
    //  Single READ
    // ----------------------------------------------------------
    function txn_t make_read(
        bit [ADDR_WIDTH-1:0] addr,
        bit [2:0]            size = 3'b010
    );
        txn_t t = new();
        if (!t.randomize() with { //inline constraint
            this.addr       == addr;
            this.direction  == txn_t::READ;
            this.size       == size;
            this.trans_type == txn_t::NONSEQ;
            this.burst_type == txn_t::SINGLE;
        }) $fatal(1, "[GEN] make_read randomize() failed");
        return t;
    endfunction

    // ----------------------------------------------------------
    //  INCR4 WRITE BURST
    // ----------------------------------------------------------
    task make_incr4_write(
        bit [ADDR_WIDTH-1:0] base_addr,
        bit [DATA_WIDTH-1:0] base_data
    );
        txn_t t;
        for (int i = 0; i < 4; i++) begin
            t = new();
            if (!t.randomize() with {//inline constrinat
                this.addr       == (base_addr + (i << 2));
                this.data       == (base_data + i);
                this.direction  == txn_t::WRITE;
                this.size       == 3'b010;
                this.burst_type == txn_t::INCR4;
                this.trans_type == ((i == 0) ? txn_t::NONSEQ : txn_t::SEQ);
            }) $fatal(1, "[GEN] make_incr4_write randomize() failed beat %0d", i);
            t.beat_num = i;
            wr_mbx.put(t);
        end
    endtask

    // ----------------------------------------------------------
    //  INCR4 READ BURST
    // ----------------------------------------------------------
    task make_incr4_read(
        bit [ADDR_WIDTH-1:0] base_addr
    );
        txn_t t;
        for (int i = 0; i < 4; i++) begin
            t = new();
            if (!t.randomize() with {
                this.addr       == (base_addr + (i << 2));
                this.direction  == txn_t::READ;
                this.size       == 3'b010;
                this.burst_type == txn_t::INCR4;
                this.trans_type == ((i == 0) ? txn_t::NONSEQ : txn_t::SEQ);
            }) $fatal(1, "[GEN] make_incr4_read randomize() failed beat %0d", i);
            t.beat_num = i;
            rd_mbx.put(t);
        end
    endtask

    // ----------------------------------------------------------
    //  MAIN GENERATION TASK
    //  Uses wr_base_addr / rd_base_addr ? set by test via
    //  constructor or direct field assignment before run()
    // ----------------------------------------------------------
    task run();
        bit [ADDR_WIDTH-1:0] wr_addr = wr_base_addr;  // ? from class field
        bit [ADDR_WIDTH-1:0] rd_addr = rd_base_addr;  // ? from class field
        bit [DATA_WIDTH-1:0] data;

        $display("[GEN] Starting: %0d writes, %0d reads | wr_base=0x%08h rd_base=0x%08h",
                 num_writes, num_reads, wr_base_addr, rd_base_addr);

        // ---------------- WRITES ----------------
        for (int i = 0; i < int'(num_writes); i++) begin
            data = $urandom();
            if ((i % 4) == 3) begin
                make_incr4_write(wr_addr, data);
                wr_addr += 32'h10; //wr_addr = wr_addr + 2;
            end else begin
                txn_t t;
                t = make_write(wr_addr, data);
                wr_mbx.put(t);
                wr_addr += 32'h4; //wr_addr = wr_addr + 4
            end
        end

        // ---------------- READS ----------------
        for (int i = 0; i < int'(num_reads); i++) begin
            if ((i % 4) == 3) begin
                make_incr4_read(rd_addr);
                rd_addr += 32'h10;
            end else begin
                txn_t t;
                t = make_read(rd_addr);
                rd_mbx.put(t);
                rd_addr += 32'h4;
            end
        end

        $display("[GEN] Done. wr_mbx=%0d rd_mbx=%0d",
                 wr_mbx.num(), rd_mbx.num());
    endtask

endclass : generator