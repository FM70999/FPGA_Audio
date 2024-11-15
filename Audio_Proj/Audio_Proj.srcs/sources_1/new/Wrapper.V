`timescale 1ns / 1ps

module audio_pipeline (
    input wire clk,              // System clock
    input wire pdm_in,           // PDM microphone data input
    input wire pdm_clk,          // PDM microphone clock
    output wire pwm_out          // PWM audio output
);
    // Parameters
    parameter PDM_CLK_DIV = 16;  // Divide system clock for PDM clock
    parameter DECIMATION_RATIO = 64;  // PDM decimation ratio
    parameter PWM_FREQ_DIV = 1024;  // Divide system clock for PWM frequency

    // Internal signals
    wire signed [15:0] pcm_data;
    reg [15:0] pwm_duty_cycle;

    // Generate PDM clock
    clk_divider #(PDM_CLK_DIV) pdm_clk_gen (
        .clk_in(CLK),
        .clk_out(pdm_clk)
    );

    // PDM to PCM conversion
    pdm_to_pcm #(
        .DECIMATION_RATIO(DECIMATION_RATIO)
    ) pdm_decoder (
        .clk(pdm_clk),
        .pdm_in(pdm_in),
        .pcm_out(pcm_data)
    );

    // PWM generation
    pwm_generator #(PWM_FREQ_DIV) pwm_gen (
        .clk(CLK),
        .duty_cycle(pcm_data),
        .pwm_out(pwm_out)
    );

endmodule

module clk_divider #(parameter DIV_RATIO = 16)(
    input wire clk_in,
    output reg clk_out
);
    reg [$clog2(DIV_RATIO)-1:0] counter = 0;

    always @(posedge clk_in) begin
        counter <= counter + 1;
        if (counter == (DIV_RATIO - 1)) begin
            counter <= 0;
            clk_out <= ~clk_out;
        end
    end
endmodule
module pdm_to_pcm #(
    parameter DECIMATION_RATIO = 64
)(
    input wire clk,
    input wire pdm_in,
    output reg signed [15:0] pcm_out
);
    reg [15:0] accumulator = 0;
    reg [$clog2(DECIMATION_RATIO)-1:0] counter = 0;

    always @(posedge clk) begin
        accumulator <= accumulator + (pdm_in ? 1 : -1);
        counter <= counter + 1;

        if (counter == (DECIMATION_RATIO - 1)) begin
            pcm_out <= accumulator;
            accumulator <= 0;
            counter <= 0;
        end
    end
endmodule

module pwm_generator #(parameter FREQ_DIV = 1024)(
    input wire clk,
    input signed [15:0] duty_cycle,  // Signed PCM data
    output reg pwm_out
);
    reg [15:0] counter = 0;

    always @(posedge clk) begin
        counter <= counter + 1;
        pwm_out <= (counter < duty_cycle) ? 1 : 0;
    end
endmodule