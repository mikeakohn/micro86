// micro86 (reduced Intel x86) FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2022-2024 by Michael Kohn

// This creates 256 bytes of RAM on the FPGA itself. Written this
// way makes it inferred by the IceStorm tools. It seems like it
// only infers it to BlockRam when using double_clk, which based
// on the timing chart in the Lattice documentation seems to make
// sense.

module ram
(
  input  [11:0] address,
  input  [7:0] data_in,
  output reg [7:0] data_out,
  input write_enable,
  input clk,
  input double_clk
);

reg [7:0] storage [4095:0];

always @(posedge double_clk) begin
  if (write_enable)
    storage[address] <= data_in;
  else
    data_out = storage[address];
end

endmodule

