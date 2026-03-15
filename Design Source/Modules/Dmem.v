module dmem (
    input  wire        clk,
    input  wire        we,
    input  wire [1:0]  size,   // 00=byte, 01=half, 10=word
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata
);

    reg [7:0] mem [0:4095]; // 4KB data memory

    wire [31:0] a = addr;

    // Write
    always @(posedge clk) begin
        if (we) begin
            case (size)
                2'b00: mem[a]     <= wdata[7:0];              // SB
                2'b01: begin                                   // SH
                    mem[a]     <= wdata[7:0];
                    mem[a + 1] <= wdata[15:8];
                end
                2'b10: begin                                   // SW
                    mem[a]     <= wdata[7:0];
                    mem[a + 1] <= wdata[15:8];
                    mem[a + 2] <= wdata[23:16];
                    mem[a + 3] <= wdata[31:24];
                end
            endcase
        end
    end

    // Read
    always @(*) begin
        case (size)
            2'b00: rdata = {24'b0, mem[a]};                    // LB/LBU handled in CPU
            2'b01: rdata = {16'b0, mem[a+1], mem[a]};          // LH/LHU handled in CPU
            2'b10: rdata = {mem[a+3], mem[a+2], mem[a+1], mem[a]};
            default: rdata = 32'b0;
        endcase
    end

endmodule
