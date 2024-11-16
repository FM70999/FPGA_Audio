`timescale 1ns / 1ps

module audio_pipeline (
    input wire CLK,            // 100 MHz clock
    input wire MIC_DATA,       // PDM microphone data
    input wire BTN,            // Button to switch between mic and tone
    output wire SPKL,          // Left channel PWM
    output wire SPKR,          // Right channel PWM
    output wire MIC_CLK        // PDM microphone clock
);
    parameter PDM_CLK_DIV = 16;
    parameter DECIMATION_RATIO = 2083;
    parameter PWM_FREQ_DIV = 100000;  // Increased PWM frequency for better resolution
    parameter GAIN = 16'h2000; // Gain for amplification

    wire mic_clk;
    wire signed [15:0] pcm_raw, pcm_amplified, tone_pcm;
    wire selected_pcm;

    // Generate PDM clock
    clk_divider #(PDM_CLK_DIV) pdm_clk_gen (
        .clk_in(CLK),
        .clk_out(mic_clk)
    );
    assign MIC_CLK = mic_clk;

    // PDM to PCM conversion
    pdm_to_pcm #(
        .DECIMATION_RATIO(DECIMATION_RATIO)
    ) pdm_decoder (
        .clk(mic_clk),
        .pdm_in(MIC_DATA),
        .pcm_out(pcm_raw)
    );

    // Amplify the PCM signal (gain stage)
    gain_amplifier #(
        .GAIN(GAIN)
    ) amplifier (
        .clk(CLK),
        .pcm_in(pcm_raw),
        .pcm_out(pcm_amplified)
    );

    // 4040 Hz tone generator
    tone_generator tone_gen (
        .clk(CLK),
        .pcm_out(tone_pcm)
    );

    // Switch between microphone and tone
    assign selected_pcm = BTN ? tone_pcm : pcm_amplified;

    // PWM output
    pwm_generator #(PWM_FREQ_DIV) pwm_left (
        .clk(CLK),
        .duty_cycle(selected_pcm),
        .pwm_out(SPKL)
    );

    assign SPKR = SPKL;

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
    parameter DECIMATION_RATIO = 2083  // For 48 kHz sample rate with 100 MHz clock
)(
    input wire clk,
    input wire pdm_in,
    output reg signed [15:0] pcm_out
);
    reg signed [31:0] accumulator = 0;
    reg [$clog2(DECIMATION_RATIO)-1:0] counter = 0;

    always @(posedge clk) begin
        // Accumulate PDM values
        accumulator <= accumulator + (pdm_in ? 1 : -1);
        counter <= counter + 1;

        // Output PCM value at decimation rate
        if (counter == (DECIMATION_RATIO - 1)) begin
            pcm_out <= accumulator[31:16]; // Scale down accumulator
            accumulator <= 0;
            counter <= 0;
        end
    end
endmodule

module fir_filter (
    input wire clk,
    input wire signed [15:0] pcm_in,
    output reg signed [15:0] pcm_out
);
    parameter N = 8; // Filter length
    reg signed [15:0] shift_reg [0:N-1];
    reg signed [31:0] sum;
    integer i;

    // Manually define filter coefficients
    reg signed [15:0] coeffs [0:N-1];
    initial begin
        coeffs[0] = 16;
        coeffs[1] = 32;
        coeffs[2] = 64;
        coeffs[3] = 128;
        coeffs[4] = 128;
        coeffs[5] = 64;
        coeffs[6] = 32;
        coeffs[7] = 16;
    end

    always @(posedge clk) begin
        // Shift the register
        for (i = N-1; i > 0; i = i - 1) begin
            shift_reg[i] <= shift_reg[i-1];
        end
        shift_reg[0] <= pcm_in;

        // Apply filter
        sum = 0;
        for (i = 0; i < N; i = i + 1) begin
            sum = sum + shift_reg[i] * coeffs[i];
        end

        pcm_out <= sum >>> 8; // Scale output
    end
endmodule

module pwm_generator #(parameter FREQ_DIV = 50000)(
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


module tone_generator (
    input wire clk,                // 100 MHz input clock
    output reg signed [15:0] pcm_out // PCM output for the tone
);
    parameter CLK_FREQ = 100_000_000; // Clock frequency in Hz
    parameter TONE_FREQ = 4040;      // Desired tone frequency in Hz
    parameter AMPLITUDE = 16'h7FFF;  // Max amplitude for the tone (positive peak)

    // Calculate toggle interval
    localparam TOGGLE_COUNT = CLK_FREQ / (TONE_FREQ * 2);

    reg [31:0] counter = 0;
    reg tone_state = 0;

    always @(posedge clk) begin
        if (counter >= TOGGLE_COUNT - 1) begin
            counter <= 0;
            tone_state <= ~tone_state; // Toggle tone state
        end else begin
            counter <= counter + 1;
        end
    end

    // Generate amplified PCM values for tone
    always @(*) begin
        pcm_out = tone_state ? AMPLITUDE : -AMPLITUDE; // Positive and negative peaks
    end

endmodule

module gain_amplifier(
    input wire clk,
    input signed [15:0] pcm_in, // Input PCM signal
    output reg signed [15:0] pcm_out // Amplified PCM signal
);
    parameter GAIN = 16'h2000; // Gain factor (for example, 2x amplification)

    always @(posedge clk) begin
        pcm_out <= pcm_in * GAIN >>> 16; // Apply gain and scale to 16-bit
    end
endmodule
