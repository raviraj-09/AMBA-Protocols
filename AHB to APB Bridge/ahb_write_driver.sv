// ============================================================
//  driver.sv
//  Two separate driver classes:
//    write_driver  ? drives AHB write transfers (and bursts)
//    read_driver   ? drives AHB read  transfers (and bursts)
//
//  Both follow the AHB-Lite pipelined protocol:
//    ? Address phase presented on cycle N
//    ? HWDATA for that beat presented on cycle N+1
//    ? Bridge asserts HREADYOUT=0 while busy; driver waits.
//
//  The drivers share the same interface via the drv_cb
//  clocking block.  Only one driver is active at a time
//  (env serialises them); if simultaneous use is needed the
//  env must arbitrate HTRANS / HSEL.
// ============================================================

//`include "transaction.sv"

// ============================================================
//  write_driver
// ============================================================
class write_driver #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);

    typedef transaction #(ADDR_WIDTH, DATA_WIDTH) txn_t;

    virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif;
    mailbox #(txn_t)  mbx;

    function new(
        virtual ahb_apb_if #(ADDR_WIDTH, DATA_WIDTH) vif_,
        mailbox #(txn_t) mbx_
    );
        vif = vif_;
        mbx = mbx_;
    endfunction

    // ----------------------------------------------------------
    //  Drive idle on the AHB bus
    // ----------------------------------------------------------
    task drive_idle();
        vif.drv_cb.HSEL    <= 1'b0;
        vif.drv_cb.HTRANS  <= 2'b00; // IDLE
        vif.drv_cb.HWRITE  <= 1'b0;
        vif.drv_cb.HADDR   <= '0;
        vif.drv_cb.HWDATA  <= '0;
        vif.drv_cb.HSIZE   <= 3'b010;
        vif.drv_cb.HBURST  <= 3'b000;
    endtask

    // ----------------------------------------------------------
    //  Wait for HREADYOUT = 1
    // ----------------------------------------------------------
    task wait_ready();
        while (!vif.drv_cb.HREADYOUT)
            @(vif.drv_cb);
    endtask

    // ----------------------------------------------------------
    //  Drive one AHB write beat.
    //  addr_phase : presents address + control
    //  data_phase : presents HWDATA on the following cycle
    //               (caller must advance clock between them)
    // ----------------------------------------------------------
    task drive_beat(txn_t t);
        // Address phase
        vif.drv_cb.HSEL   <= 1'b1;
        vif.drv_cb.HADDR  <= t.addr;
        vif.drv_cb.HWRITE <= 1'b1;
        vif.drv_cb.HSIZE  <= t.size;
        vif.drv_cb.HBURST <= t.burst_type;
        vif.drv_cb.HTRANS <= t.trans_type;
        @(vif.drv_cb);

        // Data phase ? present HWDATA while bridge processes
        vif.drv_cb.HWDATA <= t.data;
        // Drive IDLE to signal no new transfer following this beat
        // (unless the caller has the next beat ready ? handled in run())
        wait_ready();
    endtask

    // ----------------------------------------------------------
    //  Main run task
    // ----------------------------------------------------------
    task run();
        txn_t t;
        txn_t pending[$]; // queue for burst beats

        drive_idle();
        @(vif.drv_cb);

        $display("[WR_DRV] Started");
        while (mbx.num() > 0 || pending.size() > 0) begin

            // Refill from mailbox
            while (mbx.try_get(t))
                pending.push_back(t);

            if (pending.size() == 0) begin
                @(vif.drv_cb);
                continue;
            end

            t = pending.pop_front();
            $display("[WR_DRV] %s", t.to_str());

            // Address phase
            vif.drv_cb.HSEL   <= 1'b1;
            vif.drv_cb.HADDR  <= t.addr;
            vif.drv_cb.HWRITE <= 1'b1;
            vif.drv_cb.HSIZE  <= t.size;
            vif.drv_cb.HBURST <= t.burst_type;
            vif.drv_cb.HTRANS <= t.trans_type;
            @(vif.drv_cb);

            // Data phase: if next beat is SEQ, drive its address
            // while driving this beat's data (AHB pipeline).
            if (pending.size() > 0 && pending[0].trans_type == 2'b11) begin
                txn_t nxt = pending[0];
                vif.drv_cb.HWDATA <= t.data;
                vif.drv_cb.HADDR  <= nxt.addr;
                vif.drv_cb.HBURST <= nxt.burst_type;
                vif.drv_cb.HTRANS <= nxt.trans_type;
            end else begin
                vif.drv_cb.HWDATA <= t.data;
                // De-assert after last beat
                vif.drv_cb.HTRANS <= 2'b00;
                vif.drv_cb.HSEL   <= 1'b0;
            end

            wait_ready();
        end

        drive_idle();
        $display("[WR_DRV] Done");
    endtask

endclass : write_driver

