module audio_pipeline_top (
    input wire clk_in,            // 100 MHz clock
    input wire reset,             // Reset signal
    output wire clk_mic,          // Clock to drive the mic
    input wire pdm_in,            // PDM input from microphone
    output wire pwm_left,         // PWM output for left channel
    output wire pwm_right         // PWM output for right channel
);

    // Clock signal
    wire clk_4mhz;

    // PCM signal
    wire [23:0] pcm_out; // Updated to 24-bit

    // Instantiate Clock Divider
    clock_divider clock_div_inst (
        .clk_in(clk_in),
        .reset(reset),
        .clk_4mhz(clk_4mhz)
    );

    assign clk_mic = clk_4mhz;

    // Instantiate PDM to PCM Converter
    pdm_to_pcm pdm_to_pcm_inst (
        .clk(clk_mic),          // 4.55 MHz clock
        .reset(reset),
        .pdm_in(pdm_in),
        .pcm_out(pcm_out)       // Updated to 24-bit
    );

    // Instantiate PCM to PWM Converter for Left Channel
    pcm_to_pwm pcm_to_pwm_left (
        .clk(clk_in),
        .reset(reset),
        .pcm_in(pcm_out),
        .pwm_out(pwm_left)
    );

    // Instantiate PCM to PWM Converter for Right Channel
    pcm_to_pwm pcm_to_pwm_right (
        .clk(clk_in),
        .reset(reset),
        .pcm_in(pcm_out),
        .pwm_out(pwm_right)
    );

endmodule

module clock_divider (
    input wire clk_in,          // 100 MHz clock
    input wire reset,           // Reset signal
    output reg clk_4mhz         // 4.55 MHz clock output
);

    // Parameters for clock division
    parameter HC_4mhz = 11;    // 100 MHz / 4.55 MHz = ~22 -> 11 for half-cycle

    // Counters for clock division
    reg [3:0] counter_4mhz = 0;

    // 4.55 MHz Clock Divider
    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            counter_4mhz <= 0;
            clk_4mhz <= 0;
        end else if (counter_4mhz >= (HC_4mhz - 1)) begin
            counter_4mhz <= 0;
            clk_4mhz <= ~clk_4mhz;
        end else begin
            counter_4mhz <= counter_4mhz + 1;
        end
    end

endmodule

module pcm_to_pwm (
    input wire clk,              // High-frequency clock
    input wire reset,            // Reset signal
    input wire [23:0] pcm_in,    // Updated to 24-bit signed PCM input
    output reg pwm_out           // PWM output signal
);

    // Parameters
    parameter PWM_FREQ = 96000;  // Desired PWM frequency (48 kHz)
    parameter CLK_FREQ = 1000000; // Clock frequency driving this module
    parameter MAX_VAL = 24'hFFFFFF; // Maximum PCM value (unsigned 24-bit)

    // Derived parameters
    localparam COUNTER_MAX = CLK_FREQ / PWM_FREQ; // Clock cycles per PWM period

    // Registers
    reg [31:0] counter;          // PWM period counter
    reg [23:0] duty_cycle;       // Current duty cycle value (unsigned)

    // PCM to duty cycle conversion
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            duty_cycle <= 0;
        end else begin
            // Convert signed PCM to unsigned duty cycle
            duty_cycle <= pcm_in; // Adjust as needed for scaling
        end
    end

    // PWM signal generation
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            pwm_out <= 0;
        end else begin
            if (counter < duty_cycle) begin
                pwm_out <= 1; // "ON" time
            end else begin
                pwm_out <= 0; // "OFF" time
            end

            // Increment counter
            counter <= counter + 1;

            // Reset counter at end of PWM period
            if (counter >= COUNTER_MAX) begin
                counter <= 0;
            end
        end
    end

endmodule

module pdm_to_pcm (
    input wire clk,              // 4.55 MHz clock
    input wire reset,            // Reset signal
    input wire pdm_in,           // PDM input from microphone
    output reg [23:0] pcm_out    // Updated to 24-bit signed PCM output
);

    // Parameters
    parameter FILTER_TAPS = 256; // Increased filter taps for better smoothing
    parameter SHIFT = 8;         // Adjust SHIFT to log2(FILTER_TAPS)

    // Registers and variables
    reg [FILTER_TAPS-1:0] shift_reg;  // Shift register to store PDM samples
    reg [31:0] accumulator;          // Accumulator for summing PDM samples
    integer i;

    // Main FIR filter logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers
            shift_reg <= 0;
            accumulator <= 0;
            pcm_out <= 0;
        end else begin
            // Shift in the new PDM sample
            shift_reg <= {shift_reg[FILTER_TAPS-2:0], pdm_in};

            // Accumulate the PDM samples
            accumulator = 0;
            for (i = 0; i < FILTER_TAPS; i = i + 1) begin
                if (shift_reg[i]) begin
                    accumulator = accumulator + 1; // Count '1' bits
                end
            end

            // Convert the accumulated value to signed PCM
            pcm_out <= (accumulator - (FILTER_TAPS >> 1)); // Center around 0
        end
    end

endmodule
