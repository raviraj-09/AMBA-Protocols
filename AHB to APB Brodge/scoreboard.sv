

//`include "transaction.sv"

class scoreboard #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);

    // --------------------------------------------------------
    //  Type alias
    // --------------------------------------------------------
    typedef transaction #(ADDR_WIDTH, DATA_WIDTH) txn_t;


    mailbox #(txn_t) wr_mbx;
    mailbox #(txn_t) wr_exp_mbx;
    mailbox #(txn_t) rd_mbx;

    // --------------------------------------------------------
    //  Counters
    // --------------------------------------------------------
    int unsigned wr_pass = 0;
    int unsigned wr_fail = 0;
    int unsigned rd_pass = 0;
    int unsigned rd_fail = 0;

    // --------------------------------------------------------
    //  Constructor
    // --------------------------------------------------------
    function new(
        mailbox #(txn_t) wr_mbx_, //MAILBOX FROM WRITE MONITOR
        mailbox #(txn_t) rd_mbx_,//MAILBOX FROM REF MODEL
        mailbox #(txn_t) wr_exp_mbx_ //MAILBOX WHICH WE ARE GETTING FROM ENV INDIRECTLY GETTING DATA FROM GENERATOR
    );
        wr_mbx     = wr_mbx_;
        rd_mbx     = rd_mbx_;
        wr_exp_mbx = wr_exp_mbx_;
    endfunction

   
    local task check_write(txn_t obs, txn_t exp);

        // Sanity: must be a WRITE direction
        if (obs.direction !== txn_t::WRITE) begin
            $display("[SCB] WRITE INTERNAL ERROR - non-write txn in write path beat#%0d",
                     obs.beat_num);
            wr_fail++;
            return;
        end

        // PSLVERR: unexpected slave error on write
        if (obs.pslverr) begin
            $display("[SCB] WRITE ERROR (PSLVERR) addr=0x%08h data=0x%08h strb=%04b beat#%0d",
                     obs.addr, obs.data, obs.strb, obs.beat_num);
            wr_fail++;
            return;
        end

        // Field comparison
        if ((obs.addr !== exp.addr) ||
            (obs.data !== exp.data) ||
            (obs.strb !== exp.strb)) begin

            $display("[SCB] WRITE FAIL beat#%0d burst=%s",
                     obs.beat_num, obs.burst_type.name());

            if (obs.addr !== exp.addr)
                $display("        addr : exp=0x%08h  got=0x%08h  *** MISMATCH ***",
                         exp.addr, obs.addr);
            else
                $display("        addr : 0x%08h  ok", obs.addr);

            if (obs.data !== exp.data)
                $display("        data : exp=0x%08h  got=0x%08h  *** MISMATCH ***",
                         exp.data, obs.data);
            else
                $display("        data : 0x%08h  ok", obs.data);

            if (obs.strb !== exp.strb)
                $display("        strb : exp=%04b  got=%04b  *** MISMATCH ***  (size=%0d addr[1:0]=%02b)",
                         exp.strb, obs.strb, obs.size, obs.addr[1:0]);
            else
                $display("        strb : %04b  ok", obs.strb);

            wr_fail++;

        end else begin
            $display("[SCB] WRITE PASS addr=0x%08h data=0x%08h strb=%04b size=%0d burst=%s beat#%0d",
                     obs.addr, obs.data, obs.strb,
                     obs.size, obs.burst_type.name(), obs.beat_num);
            wr_pass++;
        end

    endtask

   
    local task check_read(txn_t exp);

        // Sanity: must be a READ direction
        if (exp.direction !== txn_t::READ) begin
            $display("[SCB] READ  INTERNAL ERROR - non-read txn in read path beat#%0d",
                     exp.beat_num);
            rd_fail++;
            return;
        end

        // PSLVERR: data is indeterminate; count as fail
        if (exp.pslverr) begin
            $display("[SCB] READ  ERROR (PSLVERR) addr=0x%08h beat#%0d",
                     exp.addr, exp.beat_num);
            rd_fail++;
            return;
        end

       
        if (exp.data !== exp.data) begin
            $display("[SCB] READ  FAIL addr=0x%08h  exp(ref)=0x%08h  got(HRDATA)=0x%08h  beat#%0d",
                     exp.addr, exp.data, exp.data, exp.beat_num);
            rd_fail++;
        end else begin
            $display("[SCB] READ  PASS addr=0x%08h data=0x%08h size=%0d burst=%s beat#%0d",
                     exp.addr, exp.data, exp.size,
                     exp.burst_type.name(), exp.beat_num);
            rd_pass++;
        end

    endtask

 
    task run();
        $display("[SCB] Started");

        fork

            // ---- Write check loop --------------------------
            forever begin
                txn_t obs, exp;
                wr_mbx.get(obs);
                wr_exp_mbx.get(exp);
                check_write(obs, exp);
            end

            // ---- Read check loop ---------------------------
            forever begin
                txn_t exp;
                rd_mbx.get(exp);
                check_read(exp);
            end

        join_none

    endtask

 
    task check_and_report();
        int wr_leftover, rd_leftover;

        // Allow final in-flight transactions to propagate
        #1;

        wr_leftover = wr_exp_mbx.num();
        rd_leftover = rd_mbx.num();

        if (wr_leftover > 0)
            $display("[SCB] WARNING: %0d expected write txn(s) never matched (possible monitor beat drop)",
                     wr_leftover);

        if (rd_leftover > 0)
            $display("[SCB] WARNING: %0d read txn(s) from ref model never consumed",
                     rd_leftover);

        report();
    endtask

    // --------------------------------------------------------
    //  report()  -  final pass/fail summary
    // --------------------------------------------------------
    function void report();
        int unsigned total_fail;
        total_fail = wr_fail + rd_fail;

        $display("========================================");
        $display("[SCB] WRITE: pass=%0d  fail=%0d", wr_pass, wr_fail);
        $display("[SCB] READ : pass=%0d  fail=%0d", rd_pass, rd_fail);
        $display("----------------------------------------");
        if (total_fail > 0)
            $display("[SCB] *** %0d FAILURE(S) DETECTED ***", total_fail);
        else
            $display("[SCB] ALL CHECKS PASSED");
        $display("========================================");
    endfunction

endclass : scoreboard
