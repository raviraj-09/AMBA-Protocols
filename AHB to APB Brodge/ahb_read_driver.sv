

// ============================================================
//  read_driver
// ============================================================
class read_driver #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);

    typedef transaction #(ADDR_WIDTH, DATA_WIDTH) txn_t;

    virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif;
    mailbox #(txn_t) mbx;

    function new(
        virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif_,
        mailbox #(txn_t) mbx_
    );
        vif = vif_;
        mbx = mbx_;
    endfunction

    task drive_idle();
        vif.drv_cb.HSEL   <= 1'b0;
        vif.drv_cb.HTRANS <= 2'b00;
        vif.drv_cb.HWRITE <= 1'b0;
        vif.drv_cb.HADDR  <= '0;
        vif.drv_cb.HWDATA <= '0;
        vif.drv_cb.HSIZE  <= 3'b010;
        vif.drv_cb.HBURST <= 3'b000;
    endtask

    task wait_ready();
        while (!vif.drv_cb.HREADYOUT)
            @(vif.drv_cb);
    endtask

    task run();
        txn_t t;
        txn_t pending[$];

        drive_idle();
        @(vif.drv_cb);

        $display("[RD_DRV] Started");
        while (mbx.num() > 0 || pending.size() > 0) begin

            while (mbx.try_get(t))
                pending.push_back(t);

            if (pending.size() == 0) begin
                @(vif.drv_cb);
                continue;
            end

            t = pending.pop_front();
            $display("[RD_DRV] %s", t.to_str());

            // Address phase
            vif.drv_cb.HSEL   <= 1'b1;
            vif.drv_cb.HADDR  <= t.addr;
            vif.drv_cb.HWRITE <= 1'b0;
            vif.drv_cb.HSIZE  <= t.size;
            vif.drv_cb.HBURST <= t.burst_type;
            vif.drv_cb.HTRANS <= t.trans_type;
            @(vif.drv_cb);

            // Reads: no HWDATA to drive; pipeline next address if burst
            if (pending.size() > 0 && pending[0].trans_type == 2'b11) begin
                txn_t nxt = pending[0];
                vif.drv_cb.HADDR  <= nxt.addr;
                vif.drv_cb.HBURST <= nxt.burst_type;
                vif.drv_cb.HTRANS <= nxt.trans_type;
            end else begin
                vif.drv_cb.HTRANS <= 2'b00;
                vif.drv_cb.HSEL   <= 1'b0;
            end

            wait_ready();
        end

        drive_idle();
        $display("[RD_DRV] Done");
    endtask

endclass : read_driver
