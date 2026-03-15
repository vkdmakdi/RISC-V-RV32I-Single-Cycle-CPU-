module cpu (
    input wire clk,
    input wire reset
);

    // PC
    reg [31:0] pc;
    reg [31:0] next_pc;

    // Instruction Memory (SIM ONLY)
    reg  [31:0] imem [0:1023];
    wire [31:0] instr;

    assign instr = imem[pc[31:2]];
    
    
    reg [1:0] mem_size; // 00=byte, 01=half, 10=word

    // Decode
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    // Immediates
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7],
                          instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
                          instr[20], instr[30:21], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};

    // Register File
    wire [31:0] rdata1, rdata2;
    reg         reg_write;
    reg  [31:0] write_data;

    regfile RF (
        .clk (clk),
        .we  (reg_write),
        .rs1 (rs1),
        .rs2 (rs2),
        .rd  (rd),
        .wd  (write_data),
        .rd1 (rdata1),
        .rd2 (rdata2)
    );
    
    
    dmem DMEM (
    .clk   (clk),
    .we    (mem_we),
    .size  (mem_size),
    .addr  (alu_out),
    .wdata (rdata2),
    .rdata (mem_rdata)
);

    // ALU
    reg  [3:0]  alu_ctrl;
    wire [31:0] alu_out;
    wire        zero;
    wire [31:0] alu_b =
    (opcode == 7'b0010011) ? imm_i :
    (opcode == 7'b0000011) ? imm_i :
    (opcode == 7'b0100011) ? imm_s :
                             rdata2;


    alu ALU (
        .a        (rdata1),
        .b        (alu_b),
        .alu_ctrl(alu_ctrl),
        .result  (alu_out),
        .zero    (zero)
    );
    
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLL  = 4'b0010;
    localparam ALU_SLT  = 4'b0011;
    localparam ALU_SLTU = 4'b0100;
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_OR   = 4'b1000;
    localparam ALU_AND  = 4'b1001;

// Data Memory Control
wire        mem_we;
wire [31:0] mem_rdata;

// Write enable ONLY for valid STORE instructions
assign mem_we = (opcode == 7'b0100011) &&
                (funct3 == 3'b000 ||  // SB
                 funct3 == 3'b001 ||  // SH
                 funct3 == 3'b010);   // SW

    // CONTROL + WRITEBACK + PC LOGIC
    always @(*) begin
    // defaults
    reg_write  = 1'b0;
    alu_ctrl   = ALU_ADD;
    write_data = alu_out;
    next_pc    = pc + 4;
    mem_size   = 2'b10;  

    case (opcode)

        // R-TYPE
        7'b0110011: begin
            reg_write = 1'b1;
            case (funct3)
                3'b000: alu_ctrl = (funct7 == 7'b0100000) ? ALU_SUB  : ALU_ADD;
                3'b001: alu_ctrl = ALU_SLL;
                3'b010: alu_ctrl = ALU_SLT;
                3'b011: alu_ctrl = ALU_SLTU;
                3'b100: alu_ctrl = ALU_XOR;
                3'b101: alu_ctrl = (funct7 == 7'b0100000) ? ALU_SRA  : ALU_SRL;
                3'b110: alu_ctrl = ALU_OR;
                3'b111: alu_ctrl = ALU_AND;
                default: reg_write = 1'b0;
            endcase
        end

        // I-TYPE
        7'b0010011: begin
            reg_write = 1'b1;
            case (funct3)
                3'b000: alu_ctrl = ALU_ADD;   // ADDI
                3'b010: alu_ctrl = ALU_SLT;   // SLTI
                3'b011: alu_ctrl = ALU_SLTU;  // SLTIU
                3'b100: alu_ctrl = ALU_XOR;   // XORI
                3'b110: alu_ctrl = ALU_OR;    // ORI
                3'b111: alu_ctrl = ALU_AND;   // ANDI
                3'b001: alu_ctrl = ALU_SLL;   // SLLI
                3'b101: alu_ctrl = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                default: reg_write = 1'b0;
            endcase
        end

        // LOAD
        7'b0000011: begin
    reg_write = 1'b1;
    alu_ctrl  = ALU_ADD;

    case (funct3)
        3'b000: begin // LB
            mem_size  = 2'b00;
            write_data = {{24{mem_rdata[7]}}, mem_rdata[7:0]};
        end
        3'b001: begin // LH
            mem_size  = 2'b01;
            write_data = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
        end
        3'b010: begin // LW
            mem_size  = 2'b10;
            write_data = mem_rdata;
        end
        3'b100: begin // LBU
            mem_size  = 2'b00;
            write_data = {24'b0, mem_rdata[7:0]};
        end
        3'b101: begin // LHU
            mem_size  = 2'b01;
            write_data = {16'b0, mem_rdata[15:0]};
        end
        default: reg_write = 1'b0;
    endcase
end

        // STORE
        7'b0100011: begin
    alu_ctrl = ALU_ADD;
    case (funct3)
        3'b000: mem_size = 2'b00; // SB
        3'b001: mem_size = 2'b01; // SH
        3'b010: mem_size = 2'b10; // SW
        default: ;
    endcase
end

        // BRANCHES
        7'b1100011: begin
            case (funct3)
                3'b000: begin // BEQ
                    alu_ctrl = ALU_SUB;
                    if (zero) next_pc = pc + imm_b;
                end
                3'b001: begin // BNE
                    alu_ctrl = ALU_SUB;
                    if (!zero) next_pc = pc + imm_b;
                end
                3'b100: begin // BLT
                    alu_ctrl = ALU_SLT;
                    if (alu_out == 32'b1) next_pc = pc + imm_b;
                end
                3'b101: begin // BGE
                    alu_ctrl = ALU_SLT;
                    if (alu_out == 32'b0) next_pc = pc + imm_b;
                end
                3'b110: begin // BLTU
                    alu_ctrl = ALU_SLTU;
                    if (alu_out == 32'b1) next_pc = pc + imm_b;
                end
                3'b111: begin // BGEU
                    alu_ctrl = ALU_SLTU;
                    if (alu_out == 32'b0) next_pc = pc + imm_b;
                end
            endcase
        end

        // JAL
        7'b1101111: begin
            reg_write  = 1'b1;
            write_data = pc + 4;
            next_pc    = pc + imm_j;
        end

        // JALR
        7'b1100111: begin
            if (funct3 == 3'b000) begin
                reg_write  = 1'b1;
                write_data = pc + 4;
                next_pc    = (rdata1 + imm_i) & 32'hFFFFFFFE;
            end
        end

        // LUI
        7'b0110111: begin
            reg_write  = 1'b1;
            write_data = imm_u;
        end

        // AUIPC
        7'b0010111: begin
            reg_write  = 1'b1;
            write_data = pc + imm_u;
        end
    endcase
end

    // SEQUENTIAL STATE
    always @(posedge clk) begin
        if (reset)
            pc <= 32'b0;
        else
            pc <= next_pc;
    end

    // PROGRAM LOAD (SIM ONLY)
    initial begin
        $readmemh("test.mem", imem);
    end

endmodule
