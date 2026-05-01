// ============================================================
//  AHB-Lite to APB Bridge  (with AHB burst decomposition)
//
//  Bug fixes applied vs original:
//

// ============================================================

module ahb_to_apb_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                    HCLK,
    input  wire                    HRESETn,

    // AHB-Lite slave interface
    input  wire [ADDR_WIDTH-1:0]   HADDR,
    input  wire [DATA_WIDTH-1:0]   HWDATA,
    input  wire                    HWRITE,
    input  wire [1:0]              HTRANS,
    input  wire [2:0]              HSIZE,
    input  wire [2:0]              HBURST,
    input  wire                    HSEL,
    output reg  [DATA_WIDTH-1:0]   HRDATA,
    output wire                    HREADYOUT,
    output wire [1:0]              HRESP,

    // APB master interface
    output reg  [ADDR_WIDTH-1:0]   PADDR,
    output reg  [DATA_WIDTH-1:0]   PWDATA,
    output reg                     PWRITE,
    output reg                     PSEL,
    output reg                     PENABLE,
    output reg  [DATA_WIDTH/8-1:0] PSTRB,
    input  wire [DATA_WIDTH-1:0]   PRDATA,
    input  wire                    PREADY,
    input  wire                    PSLVERR
);

    // ============================================================
    //  FSM state encoding
    // ============================================================
    localparam [2:0]
        ST_IDLE   = 3'd0,
        ST_SETUP  = 3'd1,
        ST_ENABLE = 3'd2,
        ST_WAIT   = 3'd3,
        ST_WBACK  = 3'd4;

    // AHB HTRANS encodings
    localparam [1:0]
        TRANS_IDLE   = 2'b00,
        TRANS_BUSY   = 2'b01,
        TRANS_NONSEQ = 2'b10,
        TRANS_SEQ    = 2'b11;

    // AHB HBURST encodings
    localparam [2:0]
        BURST_SINGLE = 3'b000,
        BURST_INCR   = 3'b001,
        BURST_WRAP4  = 3'b010,
        BURST_INCR4  = 3'b011,
        BURST_WRAP8  = 3'b100,
        BURST_INCR8  = 3'b101,
        BURST_WRAP16 = 3'b110,
        BURST_INCR16 = 3'b111;

    // ============================================================
    //  Internal signals
    // ============================================================
    reg [2:0]            state, next_state;

    // AHB address-phase latches
    reg [ADDR_WIDTH-1:0] lat_addr;
    reg [DATA_WIDTH-1:0] lat_wdata;  
    reg                  lat_write;
    reg [2:0]            lat_size;
    reg [2:0]            lat_burst;

    // Burst tracking
    reg [4:0]            beat_count;
    reg                  burst_active;

    // FIX 6: registered response signals
    reg                  hready_out;
    reg                  hresp_reg;       // registered, not combinational
    reg                  hresp_next;      // combinational next value

    // ============================================================
    //  Output assignments
    // ============================================================
    assign HREADYOUT = hready_out;
    assign HRESP     = {1'b0, hresp_reg};

    // ============================================================
    //  Transfer type helpers
    // ============================================================
    wire valid_transfer = HSEL &&
                          (HTRANS == TRANS_NONSEQ || HTRANS == TRANS_SEQ);

    // ============================================================
    //  Burst length decode
    //  Returns remaining beats after the NONSEQ (first) beat.
    // ============================================================
    function [4:0] burst_beats;
        input [2:0] hburst;
        begin
            case (hburst)
                BURST_WRAP4,
                BURST_INCR4  : burst_beats = 5'd3;//0->1->2->3
                BURST_WRAP8,
                BURST_INCR8  : burst_beats = 5'd7;
                BURST_WRAP16,
                BURST_INCR16 : burst_beats = 5'd15;
                default       : burst_beats = 5'd0; // SINGLE or INCR
            endcase
        end
    endfunction

    // ============================================================
    //  Byte strobe generation
    // ============================================================
    function [DATA_WIDTH/8-1:0] gen_strobe;
        input [2:0] size;
        input [1:0] addr_lsb;
        begin
            case (size)
                3'b000:
                    case (addr_lsb)
                        2'b00: gen_strobe = 4'b0001;
                        2'b01: gen_strobe = 4'b0010;
                        2'b10: gen_strobe = 4'b0100;
                        2'b11: gen_strobe = 4'b1000;
                    endcase
                3'b001:
                    case (addr_lsb[1])
                        1'b0: gen_strobe = 4'b0011;
                        1'b1: gen_strobe = 4'b1100;
                    endcase
                default: gen_strobe = 4'b1111;
            endcase
        end
    endfunction

    // ============================================================
    //  FSM: state register
    // ============================================================
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            hresp_reg <= 1'b0;
        else
            hresp_reg <= hresp_next;
    end

    // ============================================================
    //  AHB address-phase latch + burst tracking
    //
    //  FIX 1 & 4: ALL updates gated on hready_out.
    //             The master holds its output signals whenever
    //             HREADYOUT=0, so latching is safe and correct
    //             only when HREADYOUT=1.
    //
    //  FIX 2: lat_wdata latches HWDATA on the valid transfer
    //         cycle (address phase accepted) so that when the
    //         bridge enters ST_SETUP / ST_ENABLE the data phase
    //         word is already captured and stable.
    //
    //  FIX 3: TRANS_NONSEQ unconditionally clears burst_active
    //         first (overrides any leftover INCR state), then
    //         sets it only when the new burst has > 1 beat.
    //
    //  FIX 5: When HSEL=0 with burst_active, clear state so
    //         the bridge does not hang waiting for SEQ beats.
    // ============================================================
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            lat_addr     <= {ADDR_WIDTH{1'b0}};
            lat_wdata    <= {DATA_WIDTH{1'b0}};
            lat_write    <= 1'b0;
            lat_size     <= 3'b0;
            lat_burst    <= BURST_SINGLE;
            beat_count   <= 5'd0;
            burst_active <= 1'b0;
        end else begin

            if (!HSEL && burst_active) begin
                burst_active <= 1'b0;
                beat_count   <= 5'd0;
            end

            if (hready_out) begin
                case (HTRANS)
                    TRANS_NONSEQ: begin
                        if (HSEL) begin
                            lat_addr     <= HADDR;
                            lat_write    <= HWRITE;
                            lat_size     <= HSIZE;
                            lat_burst    <= HBURST;
                            beat_count   <= burst_beats(HBURST);
                            
                            burst_active <= (HBURST != BURST_SINGLE);
                        end
                    end

                    TRANS_SEQ: begin
                        if (HSEL) begin
                            lat_addr     <= HADDR;
                            lat_write    <= HWRITE;
                            lat_size     <= HSIZE;
                            // lat_burst unchanged (same burst)
                            if (beat_count != 5'd0)
                                beat_count <= beat_count - 5'd1;
                            // burst_active clears on last SEQ beat.
                            // For INCR (undefined length) it stays set
                            // until IDLE or NONSEQ clears it (FIX 3).
                            burst_active <= (beat_count > 5'd1) ||
                                            (lat_burst == BURST_INCR);
                        end
                    end

                    TRANS_BUSY: begin
                        // Mid-burst pause: hold all latches.
                        // burst_active remains set so bridge waits
                        // in ST_IDLE for the next SEQ beat.
                    end

                    TRANS_IDLE: begin
                        burst_active <= 1'b0;
                        beat_count   <= 5'd0;
                    end

                    default: ;
                endcase

                // FIX 2: Capture write data in the same cycle as the
                //        address-phase acceptance (valid NONSEQ or SEQ
                //        with HREADYOUT=1).  HWDATA for the current beat
                //        is valid on the cycle AFTER address acceptance
                //        per AHB pipeline, so we latch it when the NEXT
                //        beat's address arrives (or when HREADYOUT rises
                //        at end of the APB transaction for that beat).
                //
                //        Concretely: when hready_out=1 and the FSM is
                //        completing a transaction, the master simultaneously
                //        presents the next address-phase AND the write data
                //        for the beat just accepted.  We always sample HWDATA
                //        at this point so lat_wdata is correct for the APB
                //        write that follows.
                if (valid_transfer)
                    lat_wdata <= HWDATA;
            end
        end
    end

    // ============================================================
    //  FSM: combinational next-state and output logic
    // ============================================================
    always @(*) begin
        // Defaults
        next_state  = state;
        hready_out  = 1'b1;
        hresp_next  = 1'b0;     

        PSEL    = 1'b0;
        PENABLE = 1'b0;
        PADDR   = lat_addr;
        PWRITE  = lat_write;
        PWDATA  = lat_wdata;    // FIX 2: use registered write data
        PSTRB   = gen_strobe(lat_size, lat_addr[1:0]);

        case (state)

            // --------------------------------------------------------
            //  IDLE
            //  Free. Waiting for first (or next) beat.
            //  NONSEQ always starts a new APB transaction.
            //  SEQ arrives here when returning from a mid-burst BUSY.
            // --------------------------------------------------------
            ST_IDLE: begin
                hready_out = 1'b1;
                if (valid_transfer) begin
                    hready_out = 1'b0;
                    next_state = ST_SETUP;
                end
            end

            // --------------------------------------------------------
            //  SETUP
            //  APB setup phase for this beat.
            //  PSEL=1, PENABLE=0, master stalled.
            // --------------------------------------------------------
            ST_SETUP: begin
                PSEL       = 1'b1;
                PENABLE    = 1'b0;
                PADDR      = lat_addr;
                PWRITE     = lat_write;
                PWDATA     = lat_wdata;   // FIX 2
                PSTRB      = gen_strobe(lat_size, lat_addr[1:0]);
                hready_out = 1'b0;
                next_state = ST_ENABLE;
            end

            // --------------------------------------------------------
            //  ENABLE
            //  APB access phase for this beat.
            //
            //  On PREADY=1, no error:
            //    a) Master already presents next burst beat → ST_SETUP
            //       (back-to-back beats, no idle gap on APB).
            //    b) BUSY insert or end of burst / single → ST_IDLE.
            //
            //  On error: two-cycle AHB error response, burst aborted.
            // --------------------------------------------------------
            ST_ENABLE: begin
                PSEL       = 1'b1;
                PENABLE    = 1'b1;
                hready_out = 1'b0;

                if (PREADY) begin
                    if (PSLVERR) begin
                        hresp_next = 1'b1;   // FIX 6: feed registered path
                        hready_out = 1'b0;
                        next_state = ST_WBACK;
                    end else begin
                        hready_out = 1'b1;
                        if (valid_transfer)
                            next_state = ST_SETUP;
                        else
                            next_state = ST_IDLE;
                    end
                end else begin
                    next_state = ST_WAIT;
                end
            end

            // --------------------------------------------------------
            //  WAIT
            //  APB slave inserting wait states.
            //  Same completion decisions as ST_ENABLE.
            //  FIX 7: explicit next_state = ST_WAIT when !PREADY.
            // --------------------------------------------------------
            ST_WAIT: begin
                PSEL       = 1'b1;
                PENABLE    = 1'b1;
                hready_out = 1'b0;

                if (PREADY) begin
                    if (PSLVERR) begin
                        hresp_next = 1'b1;   // FIX 6
                        hready_out = 1'b0;
                        next_state = ST_WBACK;
                    end else begin
                        hready_out = 1'b1;
                        if (valid_transfer)
                            next_state = ST_SETUP;
                        else
                            next_state = ST_IDLE;
                    end
                end else begin
                    next_state = ST_WAIT;    // FIX 7: explicit hold
                end
            end

            // --------------------------------------------------------
            //  WBACK
            //  Second cycle of AHB two-cycle error response.
            //  hresp_reg is already 1 from the registered path.
            //  Burst is aborted on any APB slave error.
            // --------------------------------------------------------
            ST_WBACK: begin
                hready_out = 1'b1;
                hresp_next = 1'b1;   
                next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // ============================================================
    //  Read data capture - clocked
    //  Captures PRDATA into HRDATA when APB read completes.
    //  Works per-beat for burst reads.
    // ============================================================
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HRDATA <= {DATA_WIDTH{1'b0}};
        end else begin
            case (state)
                ST_ENABLE: begin
                    if (PREADY && !PSLVERR && !lat_write)
                        HRDATA <= PRDATA;
                end
                ST_WAIT: begin
                    if (PREADY && !PSLVERR && !lat_write)
                        HRDATA <= PRDATA;
                end
                default: ;
            endcase
        end
    end

    // ============================================================
    //  Registered HREADYOUT
    //  hready_out is driven combinationally above and used
    //  directly on the output port.  If downstream tools flag a
    //  combinatorial path on HREADYOUT, insert a pipeline register
    //  here and adjust timing constraints accordingly.
    // ============================================================

endmodule