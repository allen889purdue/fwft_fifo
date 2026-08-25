`timescale 1ns / 1ps

module fwft_axi4s #(
    parameter DEPTH = 5,
    parameter SIZE = 2**DEPTH
)(
    input wire rst,
    input wire wr_clk,
    input wire wr_en,
    input wire [31:0] din,
    output reg full,
    input wire rd_clk,
    input wire t_ready,
    output wire [31:0] tdata,
    output wire t_valid,
    output wire empty
);

    reg [DEPTH:0] wr_bin_pointer;
    reg [DEPTH:0] rd_bin_pointer;

    wire [DEPTH:0] wr_gray_pointer;
    wire [DEPTH:0] rd_gray_pointer;

    reg [DEPTH:0] wr_gray_sync_1;
    reg [DEPTH:0] wr_gray_sync_2;
    reg [DEPTH:0] rd_gray_sync_1;
    reg [DEPTH:0] rd_gray_sync_2;

    reg [31:0] mem [0:SIZE-1];

    reg fifo_empty;
    reg dout_valid;

    assign tdata  = dout;
    assign t_valid = dout_valid;
    assign empty  = !dout_valid;

    wire consume;
    wire wr_en_true;

    //Handshake check
    assign consume = t_valid && t_ready;
    //Can write a request when you and enabeled to write and fifo is not full
    assign wr_en_true = wr_en && !full;

    //wr logic
    always @(posedge wr_clk or posedge rst) begin
        if (rst) begin
            wr_bin_pointer <= 0;
    //When a word is requested and fifo is not full load data into din and increment pointer
        end else if (wr_en_true) begin
            mem[wr_bin_pointer[DEPTH-1:0]] <= din;
            wr_bin_pointer <= wr_bin_pointer + 1'b1;
        end
    end

    //rd logic
    always @(posedge rd_clk or posedge rst) begin
        if (rst) begin
            rd_bin_pointer <= 0;
            dout <= 0;
            dout_valid <= 0;
    //Either read when handshake is valid or when there is no word in dout and we have data in fifo
        end else if (consume || (!dout_valid && !fifo_empty)) begin
    //Check for words in fifo if so load it into dout and increment counter
            if (!fifo_empty) begin
                dout <= mem[rd_bin_pointer[DEPTH-1:0]];
                rd_bin_pointer <= rd_bin_pointer + 1'b1;
                dout_valid <= 1'b1;
            end else begin
                dout_valid <= 1'b0;
            end
        end
    end

    //Bin2gray
    assign wr_gray_pointer = wr_bin_pointer ^ (wr_bin_pointer >> 1);
    assign rd_gray_pointer = rd_bin_pointer ^ (rd_bin_pointer >> 1);

    //Reset or sync pointer
    always @(posedge rd_clk or posedge rst) begin
        if (rst) begin
            wr_gray_sync_1 <= 0;
            wr_gray_sync_2 <= 0;
        end else begin
            wr_gray_sync_1 <= wr_gray_pointer;
            wr_gray_sync_2 <= wr_gray_sync_1;
        end
    end

    //Reset or sync pointer
    always @(posedge wr_clk or posedge rst) begin
        if (rst) begin
            rd_gray_sync_1 <= 0;
            rd_gray_sync_2 <= 0;
        end else begin
            rd_gray_sync_1 <= rd_gray_pointer;
            rd_gray_sync_2 <= rd_gray_sync_1;
        end
    end

    //Empty check
    always @(posedge rd_clk or posedge rst) begin
        if (rst) begin
            fifo_empty <= 1'b1;
        end else begin
            fifo_empty <= (rd_gray_pointer == wr_gray_sync_2);
        end
    end

    //Full check with wraparound
    always @(posedge wr_clk or posedge rst) begin
        if (rst) begin
            full <= 1'b0;
        end else begin
            full <= (wr_gray_pointer == {
                ~rd_gray_sync_2[DEPTH:DEPTH-1],
                 rd_gray_sync_2[DEPTH-2:0]
            });
        end
    end

endmodule
