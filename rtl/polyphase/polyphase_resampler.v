/*
 * Polyphase Resampler - Top Module
 * Rational resampler L=2, M=3 (9 MHz -> 6 MHz)
 * Implements parallel polyphase structure with 6 branches (M=3 main phases × L=2 sub-phases)
 */
module polyphase_resampler #(
    parameter DATA_WIDTH = 16,
    parameter COEFF_WIDTH = 16,
    parameter NUM_TAPS_PER_BRANCH = 38,
    parameter L = 2,  // Interpolation factor
    parameter M = 3   // Decimation factor
)(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [DATA_WIDTH-1:0] data_in,
    input  wire data_in_valid,
    output reg  signed [DATA_WIDTH-1:0] data_out,
    output reg  data_out_valid
);

    // State machine
    localparam IDLE = 0, PROCESS_M0 = 1, PROCESS_M1 = 2, PROCESS_M2 = 3, OUTPUT = 4;
    reg [2:0] state, next_state;
    
    // Sample counter for M-way decimation
    reg [1:0] sample_count;
    
    // Coefficient ROM
    reg [7:0] coeff_addr;
    wire signed [COEFF_WIDTH-1:0] coeff_data;
    
    coefficient_rom #(
        .COEFF_WIDTH(COEFF_WIDTH),
        .NUM_COEFFS(228)
    ) coeff_rom_inst (
        .clk(clk),
        .addr(coeff_addr),
        .coeff(coeff_data)
    );
    
    // 6 polyphase branches (3 main phases × 2 sub-phases)
    wire signed [DATA_WIDTH-1:0] branch_out [0:5];
    wire [5:0] branch_valid;
    reg [5:0] branch_enable;
    reg signed [DATA_WIDTH-1:0] branch_input;
    
    // Generate 6 branches
    genvar g;
    generate
        for (g = 0; g < 6; g = g + 1) begin : polyphase_branches
            polyphase_branch #(
                .DATA_WIDTH(DATA_WIDTH),
                .COEFF_WIDTH(COEFF_WIDTH),
                .NUM_TAPS(NUM_TAPS_PER_BRANCH),
                .BRANCH_ID(g)
            ) branch_inst (
                .clk(clk),
                .rst_n(rst_n),
                .enable(branch_enable[g]),
                .data_in(branch_input),
                .coeff(coeff_data),
                .data_out(branch_out[g]),
                .data_valid(branch_valid[g])
            );
        end
    endgenerate
    
    // Output accumulation for L=2 sub-phases
    reg signed [DATA_WIDTH:0] sum_phase0_l0, sum_phase0_l1;
    reg signed [DATA_WIDTH:0] sum_phase1_l0, sum_phase1_l1;
    reg signed [DATA_WIDTH:0] sum_phase2_l0, sum_phase2_l1;
    
    // Sample counter and state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_count <= 2'd0;
            state <= IDLE;
        end else begin
            state <= next_state;
            if (data_in_valid && state == IDLE) begin
                sample_count <= sample_count + 1'b1;
                if (sample_count == M-1)
                    sample_count <= 2'd0;
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        branch_enable = 6'b000000;
        branch_input = data_in;
        
        case (state)
            IDLE: begin
                if (data_in_valid) begin
                    case (sample_count)
                        2'd0: next_state = PROCESS_M0;
                        2'd1: next_state = PROCESS_M1;
                        2'd2: next_state = PROCESS_M2;
                    endcase
                end
            end
            
            PROCESS_M0: begin
                branch_enable = 6'b000011; // Branches 0 and 1 (phase 0, sub-phase 0 and 1)
                if (branch_valid[0] && branch_valid[1])
                    next_state = OUTPUT;
            end
            
            PROCESS_M1: begin
                branch_enable = 6'b001100; // Branches 2 and 3 (phase 1, sub-phase 0 and 1)
                if (branch_valid[2] && branch_valid[3])
                    next_state = OUTPUT;
            end
            
            PROCESS_M2: begin
                branch_enable = 6'b110000; // Branches 4 and 5 (phase 2, sub-phase 0 and 1)
                if (branch_valid[4] && branch_valid[5])
                    next_state = OUTPUT;
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Output generation with L=2 interleaving
    reg [1:0] output_phase;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= {DATA_WIDTH{1'b0}};
            data_out_valid <= 1'b0;
            output_phase <= 2'd0;
        end else if (state == OUTPUT) begin
            // Output L=2 samples for each input sample
            case (sample_count)
                2'd0: begin
                    if (output_phase == 0) begin
                        data_out <= branch_out[0];
                        data_out_valid <= 1'b1;
                        output_phase <= 1;
                    end else begin
                        data_out <= branch_out[1];
                        data_out_valid <= 1'b1;
                        output_phase <= 0;
                    end
                end
                2'd1: begin
                    if (output_phase == 0) begin
                        data_out <= branch_out[2];
                        data_out_valid <= 1'b1;
                        output_phase <= 1;
                    end else begin
                        data_out <= branch_out[3];
                        data_out_valid <= 1'b1;
                        output_phase <= 0;
                    end
                end
                2'd2: begin
                    if (output_phase == 0) begin
                        data_out <= branch_out[4];
                        data_out_valid <= 1'b1;
                        output_phase <= 1;
                    end else begin
                        data_out <= branch_out[5];
                        data_out_valid <= 1'b1;
                        output_phase <= 0;
                    end
                end
            endcase
        end else begin
            data_out_valid <= 1'b0;
        end
    end

endmodule
