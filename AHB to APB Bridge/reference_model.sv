

//`include "transaction.sv"

class ref_model #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);

    typedef transaction #(ADDR_WIDTH, DATA_WIDTH) txn_t;

    // Input mailbox  ? from read monitor
    mailbox #(txn_t) rd_mon_mbx;
    // Output mailbox ? to scoreboard
    mailbox #(txn_t) scb_mbx;

    // Simple word-addressed memory model
    // (populated by the APB slave model in top via back-door)
    logic [DATA_WIDTH-1:0] mem [logic [ADDR_WIDTH-1:0]];

    // Statistics
    int unsigned num_processed = 0;
    int unsigned num_errors    = 0;

    // ----------------------------------------------------------
    //  Constructor
    // ----------------------------------------------------------
    function new(
        mailbox #(txn_t) rd_mon_mbx_,
        mailbox #(txn_t) scb_mbx_
    );
        rd_mon_mbx = rd_mon_mbx_;
        scb_mbx    = scb_mbx_;
    endfunction

    // ----------------------------------------------------------
    //  Back-door write: called by the APB slave model to tell
    //  the ref model what data lives at each address.
    // ----------------------------------------------------------
    function void backdoor_write(
        logic [ADDR_WIDTH-1:0] addr,
        logic [DATA_WIDTH-1:0] data
    );
        mem[addr] = data;
    endfunction

   
    local function txn_t predict_read(txn_t observed);
        txn_t exp = observed.copy();
   
        if (mem.exists(observed.addr))
            exp.data = mem[observed.addr];
        return exp;
    endfunction

    // ----------------------------------------------------------
    //  Run task: pulls from rd_mon_mbx, predicts, pushes to scb
    // ----------------------------------------------------------
    task run();
        txn_t obs, exp;
        $display("[REF] Started");
        forever begin
            rd_mon_mbx.get(obs);
            num_processed++;
            if (obs.pslverr) begin
                num_errors++;
                $display("[REF] PSLVERR on read addr=0x%08h ? forwarding as error txn", obs.addr);
            end
            exp = predict_read(obs);
            $display("[REF] Expected: %s", exp.to_str());
            scb_mbx.put(exp);
        end
    endtask

    function void report();
        $display("[REF] Processed=%0d  Errors=%0d", num_processed, num_errors);
    endfunction

endclass : ref_model
