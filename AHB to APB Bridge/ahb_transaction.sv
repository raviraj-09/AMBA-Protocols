// ============================================================
//  transaction.sv
// ============================================================
class transaction #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    // ----------------------------------------------------------
    //  AHB encoding constants
    // ----------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        BUSY   = 2'b01,
        NONSEQ = 2'b10,
        SEQ    = 2'b11
    } htrans_e;

    typedef enum logic [2:0] {
        SINGLE = 3'b000,
        INCR   = 3'b001,
        WRAP4  = 3'b010,
        INCR4  = 3'b011,
        WRAP8  = 3'b100,
        INCR8  = 3'b101,
        WRAP16 = 3'b110,
        INCR16 = 3'b111
    } hburst_e;

    typedef enum logic { READ = 1'b0, WRITE = 1'b1 } dir_e;

    // ----------------------------------------------------------
    //  Randomizable stimulus fields
    // ----------------------------------------------------------
    rand bit [ADDR_WIDTH-1:0] addr;
    rand bit [DATA_WIDTH-1:0] data;
    rand dir_e                direction;
    rand bit [2:0]            size;
    rand htrans_e             trans_type;
    rand hburst_e             burst_type;

    // ----------------------------------------------------------
    //  Observed / computed fields ? NOT randomized
    // ----------------------------------------------------------
    bit [DATA_WIDTH/8-1:0]    strb;      // derived in post_randomize
    bit                       pslverr;   // filled by monitor
    int unsigned              beat_num;  // filled by generator/driver

    // ----------------------------------------------------------
    //  Constraints
    // ----------------------------------------------------------
    constraint valid_size_c {
        size inside {3'b000, 3'b001, 3'b010};  // byte, half, word only
    }

    constraint addr_align_c {
        (size == 3'b001) -> addr[0]   == 1'b0;  // halfword aligned
        (size == 3'b010) -> addr[1:0] == 2'b00; // word aligned
    }

    constraint valid_trans_c {
        trans_type inside {NONSEQ, SEQ};  // no IDLE/BUSY from generator
    }

    // ----------------------------------------------------------
    //  Post-randomize: derive strb from size + addr
    // ----------------------------------------------------------
    function void post_randomize();
        case (size)
            3'b000: strb = 4'b0001 << addr[1:0];
            3'b001: strb = addr[1] ? 4'b1100 : 4'b0011;
            default: strb = 4'b1111;
        endcase
    endfunction

    // ----------------------------------------------------------
    //  Constructor
    // ----------------------------------------------------------
    function new(
        bit [ADDR_WIDTH-1:0] addr_  = '0,
        bit [DATA_WIDTH-1:0] data_  = '0,
        dir_e                dir_   = WRITE,
        bit [2:0]            size_  = 3'b010,
        htrans_e             trans_ = NONSEQ,
        hburst_e             burst_ = SINGLE
    );
        addr       = addr_;
        data       = data_;
        direction  = dir_;
        size       = size_;
        trans_type = trans_;
        burst_type = burst_;
        strb       = '1;
        pslverr    = 1'b0;
        beat_num   = 0;
    endfunction

    // ----------------------------------------------------------
    //  Deep copy
    // ----------------------------------------------------------
    function transaction #(ADDR_WIDTH, DATA_WIDTH) copy();
        transaction #(ADDR_WIDTH, DATA_WIDTH) t = new(
            this.addr, this.data, this.direction,
            this.size, this.trans_type, this.burst_type
        );
        t.strb     = this.strb;
        t.pslverr  = this.pslverr;
        t.beat_num = this.beat_num;
        return t;
    endfunction

    // ----------------------------------------------------------
    //  Display helper
    // ----------------------------------------------------------
    function string to_str();
        return $sformatf(
            "[TXN] %s addr=0x%08h data=0x%08h sz=%0d burst=%s trans=%s strb=%04b err=%0b beat#%0d",
            direction.name(), addr, data, size,
            burst_type.name(), trans_type.name(),
            strb, pslverr, beat_num
        );
    endfunction

endclass : transaction
