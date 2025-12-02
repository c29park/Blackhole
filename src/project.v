/*
 * Blackhole VGA Demoscene
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,    // unused
  output wire [7:0] uo_out,   // {hsync,B0,G0,R0,vsync,B1,G1,R1}
  input  wire [7:0] uio_in,   // unused
  output wire [7:0] uio_out,  // unused
  output wire [7:0] uio_oe,   // unused
  input  wire       ena,      // unused
  input  wire       clk,      // ~25 MHz pixel clock
  input  wire       rst_n     // active-low reset
);

  // -------------------------------------------------------
  // VGA signals
  // -------------------------------------------------------
  wire hsync;
  wire vsync;
  wire activevideo;
  wire [9:0] x_px;
  wire [9:0] y_px;

  hvsync_generator hvsync_gen(
    .clk        (clk),
    .reset      (~rst_n),
    .hsync      (hsync),
    .vsync      (vsync),
    .display_on (activevideo),
    .hpos       (x_px),
    .vpos       (y_px)
  );

  // TinyVGA PMOD mapping
  reg [1:0] R, G, B;
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;
  wire _unused_inputs = &{ui_in, uio_in, ena};

  // -------------------------------------------------------
  // Animation Timer
  // -------------------------------------------------------
  // Extended to 16 bits
  reg [15:0] frame_cnt;
  reg vsync_prev;
  
  always @(posedge clk) begin
    if (!rst_n) begin
        frame_cnt <= 0;
        vsync_prev <= 0;
    end else begin
        vsync_prev <= vsync;
        if (vsync && !vsync_prev) begin
            frame_cnt <= frame_cnt + 1;
        end
    end
  end

  // -------------------------------------------------------
  // Geometry Engine
  // -------------------------------------------------------
  
  // Center screen (320, 240)
  wire signed [10:0] dx = $signed({1'b0, x_px}) - 11'sd320;
  wire signed [10:0] dy = $signed({1'b0, y_px}) - 11'sd240;

  // 1. Squared Distances
  wire [21:0] dx_sq = dx * dx;
  wire [21:0] dy_sq = dy * dy;

  // 2. Metrics
  // Circular (for Shadow and Halo)
  wire [21:0] r2_circ = dx_sq + dy_sq;
  // Flat Elliptical (for Belt) - y squashed by 4x (shift left 4 = mult 16)
  wire [21:0] r2_flat = dx_sq + (dy_sq << 4);

  // -------------------------------------------------------
  // Constants & Thresholds
  // -------------------------------------------------------
  
  // Shadow Radius
  localparam SHADOW_R2 = 22'd7225; // r=85

  // Belt (Front/Back Disk)
  localparam BELT_IN_R2  = 22'd10000;
  localparam BELT_OUT_R2 = 22'd85000;

  // Halo (Lensed Background)
  localparam HALO_IN_R2  = 22'd5000;
  localparam HALO_OUT_R2 = 22'd22000;

  // -------------------------------------------------------
  // Text Logic ("UW") - Wait Then Fall
  // -------------------------------------------------------
  
  // Animation Logic:
  // Use frame_cnt[8] (approx every 4 seconds) to toggle state.
  // If bit 8 is 0: Wait at Top (Y=20)
  // If bit 8 is 1: Fall (Y = 20 + 0..255)
  wire [9:0] text_y_pos = (frame_cnt[8]) ? (10'd20 + {2'b00, frame_cnt[7:0]}) : 10'd20;

  // Dynamic Y-box for text
  wire in_text_y = (y_px >= text_y_pos && y_px < (text_y_pos + 10'd32));
  wire [9:0] diff_y = y_px - text_y_pos;
  wire [4:0] rel_y = diff_y[4:0]; 

  // Letter 'U' (X: 292-315)
  wire in_u_x = (x_px >= 10'd292 && x_px < 10'd316);
  wire [4:0] u_rel_x = x_px[4:0] - 5'd4; 
  wire draw_u = in_text_y && in_u_x && (
                 (u_rel_x < 5'd4) || (u_rel_x >= 5'd20) || (rel_y >= 5'd28));

  // Letter 'W' (X: 324-347)
  wire in_w_x = (x_px >= 10'd324 && x_px < 10'd348);
  wire [4:0] w_rel_x = x_px[4:0] - 5'd4; 
  wire draw_w = in_text_y && in_w_x && (
                 (w_rel_x < 5'd4) || (w_rel_x >= 5'd20) || (rel_y >= 5'd28) || 
                 ((w_rel_x >= 5'd10 && w_rel_x < 5'd14) && (rel_y >= 5'd16)));

  wire draw_text = draw_u || draw_w;

  // -------------------------------------------------------
  // Rendering Logic
  // -------------------------------------------------------
  
  // Textures (Ring patterns)
  // UPDATED: Use frame_cnt[7:0] to keep original ring flow speed
  wire [7:0] belt_tex_val = (r2_flat[15:8]) - frame_cnt[7:0];
  wire belt_gap = belt_tex_val[4];
  wire belt_yellow = belt_tex_val[2]; 
  
  wire [7:0] halo_tex_val = (r2_circ[13:6]) - frame_cnt[7:0];
  wire halo_gap = halo_tex_val[4];
  wire halo_yellow = halo_tex_val[2];

  // Region Flags
  wire in_shadow = (r2_circ < SHADOW_R2);
  wire in_belt   = (r2_flat >= BELT_IN_R2 && r2_flat <= BELT_OUT_R2);
  wire in_halo   = (r2_circ >= HALO_IN_R2 && r2_circ <= HALO_OUT_R2);

  // "3D" Depth Logic
  wire belt_is_in_front = (dy > 4); 

  always @* begin
    // Background: Deep Space Black
    R = 2'b00; G = 2'b00; B = 2'b00;

    if (activevideo) begin

        // PRIORITY 1: The Front Belt (Bottom Half)
        if (in_belt && belt_is_in_front) begin
            if (belt_gap) begin
                R = 2'b01; G = 2'b00; B = 2'b00; // Very Dim Red Gap
            end else if (belt_yellow) begin
                R = 2'b11; G = 2'b10; B = 2'b00; // Yellow/Orange Ring
            end else begin
                R = 2'b11; G = 2'b00; B = 2'b00; // Bright Blood Red
            end

        // PRIORITY 2: The Shadow (Event Horizon)
        // This blocks EVERYTHING behind it (Text, Back Belt)
        end else if (in_shadow) begin
            R = 2'b00; G = 2'b00; B = 2'b00; // Pure Black

        // PRIORITY 3: Falling Text ("UW")
        end else if (draw_text) begin
            R = 2'b11; G = 2'b11; B = 2'b11; // White Text

        // PRIORITY 4: The Back Belt (Top Half)
        end else if (in_belt) begin
            if (belt_gap) begin
                R = 2'b01; G = 2'b00; B = 2'b00; // Very Dim Red Gap
            end else if (belt_yellow) begin
                R = 2'b11; G = 2'b10; B = 2'b00; // Yellow/Orange Ring
            end else begin
                R = 2'b11; G = 2'b00; B = 2'b00; // Bright Blood Red
            end

        // PRIORITY 5: The Halo (Lensed Disk)
        end else if (in_halo) begin
            if (halo_gap) begin
                R = 2'b01; G = 2'b00; B = 2'b00; // Very Dim Red Gap
            end else if (halo_yellow) begin
                R = 2'b11; G = 2'b10; B = 2'b00; // Yellow/Orange Ring
            end else begin
                R = 2'b11; G = 2'b00; B = 2'b00; // Bright Blood Red
            end
        end
    end
  end

endmodule

// VGA sync generator for 640x480 @60Hz using a ~25MHz pixel clock.
module hvsync_generator(
  input  wire       clk,
  input  wire       reset,
  output wire       hsync,
  output wire       vsync,
  output wire       display_on,
  output reg [9:0]  hpos,
  output reg [9:0]  vpos
);
  localparam H_DISPLAY = 10'd640;
  localparam H_FRONT   = 10'd16;
  localparam H_SYNC    = 10'd96;
  localparam H_BACK    = 10'd48;
  localparam H_TOTAL   = H_DISPLAY + H_FRONT + H_SYNC + H_BACK; // 800

  localparam V_DISPLAY = 10'd480;
  localparam V_FRONT   = 10'd10;
  localparam V_SYNC    = 10'd2;
  localparam V_BACK    = 10'd33;
  localparam V_TOTAL   = V_DISPLAY + V_FRONT + V_SYNC + V_BACK; // 525

  always @(posedge clk) begin
    if (reset) begin
      hpos <= 0;
      vpos <= 0;
    end else begin
      if (hpos == H_TOTAL - 1) begin
        hpos <= 0;
        if (vpos == V_TOTAL - 1) begin
          vpos <= 0;
        end else begin
          vpos <= vpos + 1'b1;
        end
      end else begin
        hpos <= hpos + 1'b1;
      end
    end
  end

  assign hsync = ~((hpos >= H_DISPLAY + H_FRONT) && (hpos < H_DISPLAY + H_FRONT + H_SYNC));
  assign vsync = ~((vpos >= V_DISPLAY + V_FRONT) && (vpos < V_DISPLAY + V_FRONT + V_SYNC));
  assign display_on = (hpos < H_DISPLAY) && (vpos < V_DISPLAY);
endmodule

`default_nettype wire
