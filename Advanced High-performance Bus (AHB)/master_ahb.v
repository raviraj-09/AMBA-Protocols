`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ravi Raj
// 
// Create Date: 04/07/2026 07:46:57 PM
// Design Name: 
// Module Name: master_ahb
// Project Name: AHB
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module master_ahb(
    
    // AHB Input Signals
    input CLK_MASTER,
    input RESET_MASTER,
    input HREADY,   // output of Slave and Input of Master
    input HRESP,     
    input [31:0] HRDATA,    // output of Slave and Input to Master
    
    // User defined Signals
    input [31:0] data_top,  // Input to the Master given by Testbench
    input write_top,    // Write and Read control signal -- 1 for Write operation and 0 for Read operation
    input [3:0] beat_length,    //Used to describe no. of beat/packet of data fron testbench
    input enb,  // Master will start Write or Read operation only if enb = 1
    input [31:0] addr_top, // Base address give from Testbench
    input wrap_enb,     // 1 for WRAP burst or else INCR burst
    
    // AHB Output Signals
    output [31:0] HADDER,   // Address bus
    output reg HWRITE,      // Write Control Signal
    output reg [2:0] HSIZE,     // Used for determining the transfer size
    output reg [31:0] HWDATA,   // Data bus
    output reg [2:0] HBURST,
    output reg [1:0] HTRANS,
    
    // User defined signls (FIFO)
    output fifo_empty, fifo_full );
    
    // Defining Internal User defined Signals
    reg [1:0] present_state, next_state;
    reg [31:0] addr_internal = 32'h0000_0000;    
    integer i = 0;
    reg [3:0] count = 3'b000;
    reg hburst_internal;
    reg [31:0] internal_data;
    reg [7:0] wrap_base;
    reg [7:0] wrp_boundary;
    reg [31:0] prev_address;
    
    // FIFO Signals
    reg [3:0] wr_ptr, rd_ptr;
    reg [31:0] mem [14:0];
    parameter idle = 3'b000;
    parameter write_state_address = 3'b001;
    parameter raed_state_address = 3'b010;
    parameter write_state_data = 3'b011;
    parameter read_state_data = 3'b100;
    assign fifo_empty = (wr_ptr == rd_ptr);
    assign fifo_full = (wr_ptr + 1 == rd_ptr);
    
    // FIFO RESET logic
    always@(posedge CLK_MASTER)
        begin
            if(RESET_MASTER)
                begin
                    for(i=0; i<15; i = i+1)
                        mem[i] <= 0;
                        wr_ptr = 0;
                        rd_ptr = 0;
                end
                
             else if(write_top)
                begin 
                    mem[wr_ptr] <= data_top;
                    wr_ptr <= wr_ptr + 1'b1;
                end
         end
         
      // Present State logic
      always@(posedge CLK_MASTER or RESET_MASTER)
         begin
            if(RESET_MASTER)
                begin
                    present_state = idle;
                    count = 0;
                end
                
            else 
                begin
                    present_state = next_state;
                end
         end
         
      // NEXT state logic
      always @(*)
        begin
            case( present_state )
                idle: begin
                        HSIZE = 'bx;
                        HBURST = 'bX;
                        HTRANS = 2'b00; // MASTER in idle state
                        HWDATA = 'bx;
                        count = 0;
                        addr_internal = addr_top;
                        
                    // Logic for WRITE operation
                    if(write_top && HREADY && beat_length==1 && enb && wrap_enb == 0) 
                        begin
                            next_state = write_state_address;
                            HBURST = 3'b000;
                            HWRITE = 1'b1;
                        end 
                end
                
                // WRITE state address logic        
                write_state_address: begin
                    
                        HSIZE = 3'b010;     // 4 BYTE
                        HWRITE = 1'b1;
                        if(HBURST == 3'b000) 
                            begin
                                HTRANS =  2'b10;  // NONSEQ
                                next_state = write_state_data;
                            end
                end
                
               // WRITE state data logic
               write_state_data: begin
                        
                        if(HBURST == 3'b000) begin
                            next_state = idle;
                            HWDATA = data_top;
                        end
               end
               
               default: next_state = idle;
         endcase
      end
      
      assign HADDR = addr_internal;
      
      
      
      
      
      
                
                
                        
                                        
                
                    
                        
                       
               
                                      
                
                       
    
    
    
    
endmodule


