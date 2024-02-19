// micro86 (reduced Intel x86) FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

module alu
(
  input [7:0] data_0,
  input [7:0] data_1,
  input flag_carry,
  input [2:0] command,
  output [8:0] alu_result
);

reg [8:0] result;
assign alu_result = result;

parameter OP_ADD = 3'b000;
parameter OP_ADC = 3'b001;
parameter OP_SUB = 3'b010;
parameter OP_SBB = 3'b011;
parameter OP_ANA = 3'b100;
parameter OP_XRA = 3'b101;
parameter OP_ORA = 3'b110;
parameter OP_CMP = 3'b111;

always @(command, data_0, data_1, flag_carry) begin
  case (command)
     OP_ADD: result = data_0 + data_1;
     OP_ADC: result = data_0 + data_1 + flag_carry;
     OP_SUB: result = data_0 - data_1;
     OP_SBB: result = data_0 - data_1 + flag_carry;
     OP_ANA: result = data_0 & data_1;
     OP_XRA: result = data_0 ^ data_1;
     OP_ORA: result = data_0 | data_1;
     OP_CMP: result = data_0 - data_1;
  endcase
end

endmodule

