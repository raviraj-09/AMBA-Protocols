
// ============================================================
//  read_monitor
// ============================================================
class read_monitor #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);

    typedef transaction #(ADDR_WIDTH, DATA_WIDTH) txn_t;

    virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif;
    mailbox #(txn_t) mbx; // ? reference model

    function new(
        virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif_,
        mailbox #(txn_t) mbx_
    );
        vif = vif_;
        mbx = mbx_;
    endfunction

    // ----------------------------------------------------------
    //  Run: watches for completed APB read beats.
    //  A completed read beat is: PSEL=1, PENABLE=1, PWRITE=0,
    //  PREADY=1.
    //  PRDATA is sampled at this moment and stored in t.data.
    // ----------------------------------------------------------
    task run();
        txn_t t;
        $display("[RD_MON] Started");
        forever begin
            @(vif.rd_mon_cb);
            if (vif.rd_mon_cb.PSEL    &&
                vif.rd_mon_cb.PENABLE &&
               !vif.rd_mon_cb.PWRITE  &&
                vif.rd_mon_cb.PREADY)
            begin
                t = new();
                t.direction = txn_t::READ;
                t.addr      = vif.rd_mon_cb.PADDR;
                t.data      = vif.rd_mon_cb.PRDATA; // APB slave's response
                t.strb      = vif.rd_mon_cb.PSTRB;
                t.pslverr   = vif.rd_mon_cb.PSLVERR;
                t.size      = vif.rd_mon_cb.HSIZE;
                $display("[RD_MON] Captured %s", t.to_str());
                mbx.put(t); // forward to ref model via mailbox
            end
        end
    endtask

endclass : read_monitor
