`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ravi Raj
// 
// Create Date: 04/06/2026 07:23:25 PM
// Design Name: 
// Module Name: apb_slave_tb
// Project Name: APB
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


module apb_slave_tb( );

    reg clk, reset_n;
    wire pselx;
    wire enable;
    wire [31:0] paddr;
    wire [31:0] pwdata;
    wire pwrite;
    reg pready;
    reg transfer;
    reg [31:0] addr;
    reg [31:0] wdata;
    reg write;
    
    
 apb_master dut (clk, reset_n, transfer, addr, wdata, write, pselx, 
                   penable, paddr, pwdata, pwrite);
                   
     initial 
        begin 
        {clk, transfer, addr, wdata, write} = 1'b0;
        end
        
     always #5 clk = ~clk;
     
     initial 
        begin   
            reset_n = 0;
            write = 1;
            pready = 0;
            
            #20
            
            reset_n = 1;
            
            @(posedge clk);
                transfer = 1;
                addr = 32'hCDAB_534B;
                wdata = 32'hFADE_56DC;
                write = 1'b1;
                
            @(posedge clk);
                transfer = 0;
                
                repeat(3)
                
                 @(posedge clk);
                    pready = 1'b1;
                    
                 @(posedge clk);
                    pready = 1'b0;
                    
                    
                 #50;
                 
          $finish();
          end
               
                
        
        
    
    
endmodule
