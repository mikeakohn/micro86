// micro86 (reduced Intel x86) FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

module micro86
(
  output [7:0] leds,
  output [3:0] column,
  input raw_clk,
  output eeprom_cs,
  output eeprom_clk,
  output eeprom_di,
  input  eeprom_do,
  output speaker_p,
  output speaker_m,
  output ioport_0,
  output ioport_1,
  output ioport_2,
  output ioport_3,
  output ioport_4,
  input  button_reset,
  input  button_halt,
  input  button_program_select,
  input  button_0,
  output spi_clk_0,
  output spi_mosi_0,
  input  spi_miso_0
);

// iceFUN 8x4 LEDs used for debugging.
reg [7:0] leds_value;
reg [3:0] column_value;

assign leds = leds_value;
assign column = column_value;

// Memory bus (ROM, RAM, peripherals).
reg [15:0] mem_address = 0;
reg [7:0] mem_data_in = 0;
wire [7:0] mem_data_out;
reg mem_bus_enable = 0;
reg mem_write_enable = 0;

// Clock.
reg [21:0] count = 0;
reg [5:0] state = 0;
reg [5:0] next_state = 0;
reg [19:0] clock_div;
reg [14:0] delay_loop;
wire clk;
assign clk = clock_div[1];

// Registers.
// 000 eax
// 001 ecx
// 010 edx
// 011 ebx
// 100 esp  / ah
// 101 ebp  / ch
// 110 esi  / dh
// 111 edi  / bh
reg [31:0] registers [7:0];

// Instruction.
reg [15:0] rip = 0;
reg [3:0] alu_op;
reg [2:0] dst_reg;
reg [7:0] instruction;
reg [7:0] mod_rm;
reg [1:0] mem_count = 0;
reg [1:0] mem_last = 0;
reg [7:0] sib;
wire [1:0] sib_scale;
wire [2:0] sib_index;
wire [2:0] sib_base;
assign sib_scale = sib[7:6];
assign sib_index = sib[5:3];
assign sib_base  = sib[2:0];
reg long_jmp = 0;
reg do_lea;
reg do_imm;
reg do_alu_imm;
reg is_mov;
reg ea_has_no_reg;
reg do_ea;
reg no_write_back;
reg [31:0] temp;
reg [31:0] dest_value;
reg [32:0] result;
reg [31:0] orig;
// Since RIP Is only 16 bit, this can be 16 bit too.
reg [15:0] ea = 0;
reg [15:0] ea_save;
wire direction;
reg reverse_direction;
//wire [1:0] addressing_mode;
wire [2:0] inc_reg;
assign direction = instruction[1] ^ reverse_direction;
//assign addressing_mode = mod_rm[7:6];
assign inc_reg = instruction[2:0];

reg  [4:0] shift_count;
wire [2:0] shift_op;
assign shift_op = mod_rm[5:3];

// ALU and opcode loading size.
// bit 0: 8 bit.
// bit 1: 16 bit.
// If both are set or both cleared, it's 32 bit.
reg [1:0] opcode_size;
reg [1:0] alu_size;

// Flags.
wire [15:0] flags;
reg flag_overflow = 0;
reg flag_sign = 0;
reg flag_zero = 0;
reg flag_aux_carry = 0;
reg flag_parity = 0;
reg flag_carry = 0;

//reg break = 0;

assign flags[15] = 0;
assign flags[14] = 0;
assign flags[13] = 0;
assign flags[12] = 0;
assign flags[11] = flag_overflow;
assign flags[10] = 0;
assign flags[9] = 0;
assign flags[8] = 0;
assign flags[7] = flag_sign;
assign flags[6] = flag_zero;
assign flags[5] = 0;
assign flags[4] = flag_aux_carry;
assign flags[3] = 0;
assign flags[2] = flag_parity;
assign flags[1] = 0;
assign flags[0] = flag_carry;

// Eeprom.
reg  [8:0] eeprom_count;
wire [7:0] eeprom_data_out;
reg [10:0] eeprom_address;
reg eeprom_strobe = 0;
wire eeprom_ready;

// Debug.
//reg [7:0] debug_0 = 0;
//reg [7:0] debug_1 = 0;
//reg [7:0] debug_2 = 0;
//reg [7:0] debug_3;

// This block is simply a clock divider for the raw_clk.
always @(posedge raw_clk) begin
  count <= count + 1;
  clock_div <= clock_div + 1;
end

// This block simply drives the 8x4 LEDs.
always @(posedge raw_clk) begin
  case (count[9:7])
    //3'b000: begin column_value <= 4'b0111; leds_value <= ~ea[7:0]; end
    //3'b000: begin column_value <= 4'b0111; leds_value <= ~instruction; end
    3'b000: begin column_value <= 4'b0111; leds_value <= ~registers[0]; end
    //3'b010: begin column_value <= 4'b1011; leds_value <= ~flags[7:0]; end
    //3'b010: begin column_value <= 4'b1011; leds_value <= ~mod_rm[7:0]; end
    //3'b010: begin column_value <= 4'b1011; leds_value <= ~ea[15:8]; end
    3'b010: begin column_value <= 4'b1011; leds_value <= ~registers[0][15:8]; end
    //3'b010: begin column_value <= 4'b1011; leds_value <= ~dst_reg; end
    //3'b010: begin column_value <= 4'b1011; leds_value <= ~mem_last; end
    //3'b010: begin column_value <= 4'b1011; leds_value <= ~temp[7:0]; end
    3'b100: begin column_value <= 4'b1101; leds_value <= ~rip[7:0]; end
    3'b110: begin column_value <= 4'b1110; leds_value <= ~state; end
    default: begin column_value <= 4'b1111; leds_value <= 8'hff; end
  endcase
end

parameter STATE_RESET =             0;
parameter STATE_DELAY_LOOP =        1;
parameter STATE_FETCH_OP_0 =        2;
parameter STATE_FETCH_OP_1 =        3;
parameter STATE_START_DECODE =      4;
parameter STATE_INC_DEC_0 =         5;
parameter STATE_INC_DEC_1 =         6;
parameter STATE_ALU_0 =             7;
parameter STATE_ALU_1 =             8;
parameter STATE_COMPUTE_EA_0 =      9;
parameter STATE_COMPUTE_EA_1 =     10;
parameter STATE_ALU_EXECUTE_0 =    11;
parameter STATE_ALU_EXECUTE_1 =    12;
parameter STATE_ALU_WB_REG     =   13;
parameter STATE_ALU_WB_MEM     =   14;
parameter STATE_MOV_REG_IMM_0 =    15;
parameter STATE_MOV_REG_IMM_1 =    16;
parameter STATE_FETCH_MOD_RM_0 =   17;
parameter STATE_FETCH_MOD_RM_1 =   18;
parameter STATE_FETCH_SIB_0 =      19;
parameter STATE_FETCH_SIB_1 =      20;
parameter STATE_COMPUTE_SIB_EA_0 = 21;
parameter STATE_COMPUTE_SIB_EA_1 = 22;

parameter STATE_FETCH_DATA32_0 =   23;
parameter STATE_FETCH_DATA32_1 =   24;
parameter STATE_FETCH_EA_0 =       25;
parameter STATE_FETCH_EA_1 =       26;
parameter STATE_WRITE_EA_0 =       27;
parameter STATE_WRITE_EA_1 =       28;

parameter STATE_POP_0 =            29;
parameter STATE_POP_1 =            30;
parameter STATE_PUSH_0 =           31;
parameter STATE_RET_0 =            32;
parameter STATE_RET_1 =            33;

parameter STATE_CALL_0 =           34;
parameter STATE_JCC_0 =            35;
parameter STATE_JCC_1 =            36;
parameter STATE_JCC_2 =            37;
parameter STATE_JMP_0 =            38;
parameter STATE_JMP_1 =            39;

parameter STATE_TST_IMM32_0 =      40;

parameter STATE_SHIFT_0 =          41;
parameter STATE_SHIFT_1 =          42;
parameter STATE_SHIFT_2 =          43;
parameter STATE_SHIFT_WB_REG =     44;

parameter STATE_ALU_IMM_TO_MEM_0 = 45;
parameter STATE_ALU_IMM_TO_MEM_1 = 46;

parameter STATE_HALTED =           57; // 0x39
parameter STATE_ERROR =            58; // 0x3a
parameter STATE_EEPROM_START =     59;
parameter STATE_EEPROM_READ =      60;
parameter STATE_EEPROM_WAIT =      61;
parameter STATE_EEPROM_WRITE =     62;
parameter STATE_EEPROM_DONE =      63;

parameter ALU_ADD = 0;
parameter ALU_OR  = 1;
parameter ALU_ADC = 2;
parameter ALU_SBB = 3;
parameter ALU_AND = 4;
parameter ALU_SUB = 5;
parameter ALU_XOR = 6;
parameter ALU_CMP = 7;
parameter ALU_MOV = 8;
parameter ALU_JMP = 9;
parameter ALU_NEG = 10;
parameter ALU_TEST = 11;
parameter ALU_SHIFT = 12;

parameter SHIFT_ROL = 0;
parameter SHIFT_ROR = 1;
parameter SHIFT_SHL = 4;
parameter SHIFT_SHR = 5;
parameter SHIFT_SAR = 7;

task set_flags16_nocf(input [16:0] data, input [15:0] old);
  flag_overflow <= data[16] ^ old[15];
  flag_zero <= data[15:0] == 0;
  flag_sign <= data[15];
endtask

task set_flags32_nocf(input [32:0] data, input [31:0] old);
  flag_overflow <= data[32] ^ old[31];
  flag_zero <= data[31:0] == 0;
  flag_sign <= data[32];
endtask

task set_flags8(input [8:0] data, input [7:0] old);
  flag_overflow <= data[8] ^ old[7];
  flag_zero <= data[7:0] == 0;
  flag_sign <= data[7];
  flag_carry <= data[8];
endtask

task set_flags16(input [16:0] data, input [15:0] old);
  flag_overflow <= data[16] ^ old[15];
  flag_zero <= data[15:0] == 0;
  flag_sign <= data[15];
  flag_carry <= data[16];
endtask

task set_flags32(input [32:0] data, input [31:0] old);
  flag_overflow <= data[32] ^ old[31];
  flag_zero <= data[31:0] == 0;
  flag_sign <= data[31];
  flag_carry <= data[32];
endtask

// This block is the main CPU instruction execute state machine.
always @(posedge clk) begin
  if (!button_reset)
    state <= STATE_RESET;
  else if (!button_halt)
    state <= STATE_HALTED;
  else begin
    case (state)
      STATE_RESET:
        begin
          registers[4] <= 16'h1000;
          flag_zero <= 0;
          flag_carry <= 0;
          flag_sign <= 0;
          flag_parity <= 0;
          mem_address <= 0;
          mem_write_enable <= 0;
          mem_data_in <= 0;
          instruction <= 0;
          delay_loop <= 12000;
          eeprom_strobe <= 0;
          state <= STATE_DELAY_LOOP;
        end
      STATE_DELAY_LOOP:
        begin
          // This is probably not needed. The chip starts up fine without it.
          if (delay_loop == 0) begin
            // If button is not pushed, start rom.v code otherwise use EEPROM.
            if (button_program_select) begin
              rip <= 16'h4000;
              state <= STATE_FETCH_OP_0;
            end else begin
              rip <= 0;
              state <= STATE_EEPROM_START;
            end
          end else begin
            delay_loop <= delay_loop - 1;
          end
        end
      STATE_FETCH_OP_0:
        begin
          result <= 0;
          opcode_size <= 0;
          long_jmp <= 0;
          alu_size <= 0;
          do_lea <= 0;
          do_imm <= 0;
          do_alu_imm <= 0;
          is_mov <= 0;
          do_ea <= 0;
          no_write_back <= 0;
          ea_has_no_reg <= 0;
          reverse_direction <= 0;
          mem_bus_enable <= 1;
          mem_address <= rip;
          mem_write_enable <= 0;

/*
if (break == 1) begin
state <= STATE_HALTED;
end else
*/
          state <= STATE_FETCH_OP_1;
        end
      STATE_FETCH_OP_1:
        begin
          mem_bus_enable <= 0;
          instruction <= mem_data_out;
          rip <= rip + 1;
          state <= STATE_START_DECODE;
        end
      STATE_START_DECODE:
        begin
          case (instruction[7:6])
            2'b00:
              begin
                if (instruction[5:0] == 6'b001111) begin
                  // 0xff prefix for long jump.
                  long_jmp <= 1;
                  mem_bus_enable <= 1;
                  mem_address <= rip;
                  state <= STATE_FETCH_OP_1;
                end else begin
                  alu_op <= instruction[5:3];
                  alu_size[0] <= ~instruction[0];
                  state <= STATE_ALU_0;
                end
              end
            2'b01:
              begin
                case (instruction[5:4])
                  2'b00:
                     // inc eax: 0x40  (32 bit only, prefix is ignored).
                     state <= STATE_INC_DEC_0;
                  2'b01:
                     begin
                       // push edx: 0x52
                       // pop edx: 0x5a
                       if (instruction[3] == 0) begin
                         temp <= registers[instruction[2:0]];
                         state <= STATE_PUSH_0;
                       end else begin
                         state <= STATE_POP_0;
                       end

                       mem_count <= 0;
                     end
                  2'b10:
                    begin
                      if (instruction[3:0] == 4'h6) begin
                        // 0x66 prefix (16 bit mode).
                        alu_size[1] <= 1;
                        mem_bus_enable <= 1;
                        mem_address <= rip;
                        state <= STATE_FETCH_OP_1;
                      end else begin
                        state <= STATE_ERROR;
                      end
                    end
                  2'b11:
                    begin
                      state <= STATE_JCC_0;
                    end
                endcase
              end
            2'b10:
              begin
                case (instruction[5:4])
                  2'b00:
                    if (long_jmp == 1) begin
                      state <= STATE_JCC_0;
                    end else begin
                      case (instruction[3:2])
                        2'b00:
                          begin
                            // add eax, 1: 0x83,0xc0,0x01
                            // and eax, 1: 0x83,0xe0,0x01
                            // add dword [ebx+0x2],0x40: 0x83,0x43,0x02,0x40
                            // add byte [ebx+0x2],0x40: 0x80,0x43,0x02,0x40
                            // ALU [ 1000 00sw ] [ mod alu_op r/m ] [ imm8 ]
                            do_imm <= 1;
                            do_alu_imm <= 1;
                            alu_size[0] <= ~instruction[0];
                            //mem_count <= 0;
                            //mem_last <= 0;
                            //next_state <= STATE_ALU_IMM8_0;
                            //state <= STATE_FETCH_DATA32_0;
                            state <= STATE_FETCH_MOD_RM_0;
                          end
                        2'b01:
                          begin
                            // test ebx, edx: 0x85,0xd3
                            alu_op <= ALU_TEST;
                            no_write_back <= 1;
                            alu_size[0] <= ~instruction[0];
                            state <= STATE_FETCH_MOD_RM_0;
                          end
                        2'b10:
                          begin
                            // mov eax, [mod_rm]
                            alu_op <= ALU_MOV;
                            alu_size[0] <= ~instruction[0];
                            state <= STATE_ALU_0;
                          end
                        2'b11:
                          begin
                            // LEA.
                            do_lea <= 1;
                            state <= STATE_FETCH_MOD_RM_0;
                          end
                      endcase
                    end
                  2'b01:
                    begin
                      if (instruction[3:0] == 4'b1000) begin
                        if (alu_size[1] == 1)
                          // cbw (sign extend al to ax).
                          registers[0][15:0] <= { {8{registers[0][7]}}, registers[0][7:0] };
                        else
                          // cwde (sign extend ax to eax).
                          registers[0][31:0] <= { {16{registers[0][15]}}, registers[0][15:0] };
                        state <= STATE_FETCH_OP_0;
                      end else if (instruction[3:0] == 4'b1100) begin
                        // pushf
                        temp <= flags;
                        mem_count <= 0;
                        state <= STATE_PUSH_0;
                      end else begin
                        // nop (plus some other unsupported stuff).
                        state <= STATE_FETCH_OP_0;
                      end
                    end
                  2'b10:
                    begin
                      alu_size[0] <= ~instruction[0];
                      reverse_direction <= 1;
                      ea_has_no_reg <= 1;
                      dst_reg <= 0;
                      mem_count <= 0;
                      mem_last <= 3;
                      state <= STATE_FETCH_DATA32_0;
                      next_state <= STATE_COMPUTE_EA_0;

                      if (instruction[3] == 0) begin
                        // mov eax, [0x4000]
                        alu_op <= ALU_MOV;
                      end else begin
                        // test eax, 1: 0xa9,0x01,0x00,0x00,0x00
                        alu_op <= ALU_TEST;
                        no_write_back <= 1;
                      end
                    end
                  2'b11:
                    begin
                      // mov eax, 0x400
                      opcode_size[0] <= ~instruction[3];
                      alu_size[0] <= ~instruction[3];
                      state <= STATE_MOV_REG_IMM_0;
                    end
                  default:
                    state <= STATE_ERROR;
                endcase
              end
            2'b11:
              begin
                case (instruction[5:4])
                  2'b00:
                    if (instruction[3:1] == 3'b000) begin
                      // shl eax, 5: 0xc1,0xe0,0x05
                      alu_op <= ALU_SHIFT;
                      state <= STATE_FETCH_MOD_RM_0;
                      alu_size[0] <= ~instruction[0];
                    end else if (instruction[3:1] == 3'b001) begin
                      // ret: 0xc3
                      state <= STATE_RET_0;
                    end else if (instruction[3:1] == 3'b011) begin
                      // mov [0x0004], 1: 0xc6,0x05,0x04,0x00,0x00,0x00,0x01
                      //is_mov <= 1;
                      alu_op <= ALU_MOV;
                      do_imm <= 1;
                      //reverse_direction <= 1;
                      alu_size[0] <= ~instruction[0];
                      state <= STATE_FETCH_MOD_RM_0;
                    end else begin
                      state <= STATE_ERROR;
                    end
                  2'b01:
                    begin
                      // shl eax, 1:  0xd1,0xe0
                      // shl eax, cl: 0xd3,0xe0
                      alu_op <= ALU_SHIFT;
                      state <= STATE_FETCH_MOD_RM_0;
                      alu_size[0] <= ~instruction[0];
                    end
                  2'b10:
                    begin
                      if (instruction[3:0] == 4'b1000) begin
                        // call 0xd: 0xe8 0x03 0x00 0x00 0x00
                        mem_count <= 0;
                        mem_last <= 3;
                        dst_reg <= 3'b011;
                        state <= STATE_FETCH_DATA32_0;
                        next_state <= STATE_CALL_0;
                      end else if (instruction[3:0] == 4'b1011) begin
                        // jmp short
                        state <= STATE_JMP_0;
                      end else if (instruction[3:0] == 4'b1001) begin
                        // jmp long
                        long_jmp <= 1;
                        state <= STATE_JMP_0;
                      end else begin
                        state <= STATE_ERROR;
                      end
                    end
                  2'b11:
                    case (instruction[3:0])
                      4'b0100: state <= STATE_HALTED;
                      4'b0101:
                        begin
                          flag_carry <= ~flag_carry;
                          state <= STATE_FETCH_OP_0;
                        end
/*
                      4'b0010:
                        begin
                          alu_op <= ALU_TEST;
                          state <= STATE_FETCH_MOD_RM_0;
                        end
                      4'b0011:
                        begin
                          alu_op <= ALU_TEST;
                          state <= STATE_FETCH_MOD_RM_0;
                        end
*/
                      4'b0110:
                        begin
                          alu_op <= ALU_NEG;
                          state <= STATE_FETCH_MOD_RM_0;
                        end
                      4'b0111:
                        begin
                          alu_op <= ALU_NEG;
                          state <= STATE_FETCH_MOD_RM_0;
                        end
                      4'b1111:
                        begin
                          // call eax: 0xff 0xd0 (MOD_RM)
                          alu_op <= ALU_JMP;
                          state <= STATE_FETCH_MOD_RM_0;
                        end
                      default: state <= STATE_ERROR;
                    endcase
                  default:
                    case (instruction[3:1])
                      3'b100:
                        begin
                          flag_carry <= instruction[0];
                          state <= STATE_FETCH_OP_0;
                        end
                      default: state <= STATE_ERROR;
                    endcase
                endcase
              end
          endcase
        end
      STATE_INC_DEC_0:
        begin
          if (instruction[3] == 0)
            result <= registers[inc_reg] + 1;
          else
            result <= registers[inc_reg] - 1;

          orig <= registers[inc_reg];
          state <= STATE_INC_DEC_1;
        end
      STATE_INC_DEC_1:
        begin
          if (alu_size[1] == 0) begin
            registers[inc_reg] <= result;
            set_flags16_nocf(result, orig);
          end else begin
            registers[inc_reg][15:0] <= result[15:0];
            set_flags32_nocf(result, orig);
          end

          state <= STATE_FETCH_OP_0;
        end
      STATE_ALU_0:
        begin
          if (instruction[2] == 0) begin
            state <= STATE_FETCH_MOD_RM_0;
          end else begin
            // 00 ALU 10w
            // add al, imm8
            // add ax, imm16
            // add eax, imm32

            dst_reg <= 0;
            alu_size[0] <= ~instruction[0];
            reverse_direction <= 1;

            if (opcode_size[1] == 1) begin
              mem_last <= 1;
            end else if (instruction[0] == 0) begin
              mem_last <= 0;
            end else begin
              mem_last <= 3;
            end

            mem_count <= 0;
            state <= STATE_FETCH_DATA32_0;
            next_state <= STATE_ALU_EXECUTE_0;
          end
        end
      STATE_ALU_1:
        begin
          mem_count <= 0;

          case (mod_rm[7:6])
            2'b00:
              begin
                // Register indirect.
                if (mod_rm[2:0] == 3'b100) begin
                  // rm == 100 (esp) == SIB.
                  state <= STATE_FETCH_SIB_0;
                end else if (mod_rm[2:0] == 3'b101) begin
                  // rm == 101 (ebp) == displacement only.
                  ea_has_no_reg <= 1;
                  mem_count <= 0;
                  mem_last <= 3;
                  state <= STATE_FETCH_DATA32_0;
                  next_state <= STATE_COMPUTE_EA_0;
                end else begin
                  ea <= registers[mod_rm[2:0]];
                  ea_save <= registers[mod_rm[2:0]];
                  state <= STATE_COMPUTE_EA_1;
                end

                dst_reg <= mod_rm[5:3];
              end
            2'b01:
              begin
                // One byte displacement.
                // add eax, [ebx+80]: 0x03,0x43,0x50
                mem_last <= 0;
                opcode_size <= 1;
                state <= STATE_FETCH_DATA32_0;
                next_state <= STATE_COMPUTE_EA_0;
                dst_reg <= mod_rm[5:3];
              end
            2'b10:
              begin
                // Four byte displacement.
                // add eax, [ebx+1024]: 0x03,0x83,0x00,0x04,0x00,0x00
                mem_last <= 3;
                state <= STATE_FETCH_DATA32_0;
                next_state <= STATE_COMPUTE_EA_0;
                dst_reg <= mod_rm[5:3];
              end
            2'b11:
              begin
                // reg, reg.
                case (alu_size)
                  2'b01:
                    begin
                      if (mod_rm[5] == 0)
                        temp <= registers[mod_rm[4:3]][7:0];
                      else
                        temp <= registers[mod_rm[4:3]][15:8];
                    end
                  2'b10:
                    begin
                      temp <= registers[mod_rm[5:3]][15:0];
                    end
                  default:
                    begin
                      temp <= registers[mod_rm[5:3]];
                    end
                endcase

                dst_reg <= mod_rm[2:0];

                if (do_imm == 0)
                  state <= STATE_ALU_EXECUTE_0;
                else
                  state <= STATE_ALU_IMM_TO_MEM_0;
              end
          endcase
        end
      STATE_COMPUTE_EA_0:
        begin
          if (ea_has_no_reg) begin
            ea <= temp;
          end else begin
            if (mod_rm[7:6] == 2'b01)
              ea <= registers[mod_rm[2:0]] + $signed(temp[7:0]);
            else
              ea <= registers[mod_rm[2:0]] + temp;
          end

          state <= STATE_COMPUTE_EA_1;
        end
      STATE_COMPUTE_EA_1:
        begin
          if (do_lea == 1) begin
            registers[mod_rm[5:3]] <= ea;
            state <= STATE_FETCH_OP_0;
          end else begin
            mem_count <= 0;
            ea_save <= ea;

            case (opcode_size)
              2'b01: mem_last <= 0;
              2'b10: mem_last <= 1;
              default: mem_last <= 3;
            endcase

            if (alu_op == ALU_JMP) begin
              next_state <= STATE_CALL_0;
              state <= STATE_FETCH_EA_0;
            end else if (do_imm == 1) begin
              next_state <= STATE_ALU_IMM_TO_MEM_0;
              state <= STATE_FETCH_EA_0;
            end else begin
              next_state <= STATE_ALU_EXECUTE_0;
              state <= STATE_FETCH_EA_0;
            end
          end
        end
      STATE_ALU_EXECUTE_0:
        begin
          if (direction == 1) begin
            case (alu_size)
              2'b01:
                if (dst_reg[2] == 0)
                  dest_value <= registers[dst_reg[1:0]][7:0];
                else
                  dest_value <= registers[dst_reg[1:0]][15:8];
              2'b10:
                dest_value <= registers[dst_reg][15:0];
              default:
                dest_value <= registers[dst_reg];
            endcase
          end else begin
            dest_value <= temp;

            case (alu_size)
              2'b01:
                if (dst_reg[2] == 0)
                  temp <= registers[dst_reg[1:0]][7:0];
                else
                  temp <= registers[dst_reg[1:0]][15:8];
              2'b10:
                temp <= registers[dst_reg][15:0];
              default:
                temp <= registers[dst_reg];
            endcase
          end

//if (instruction[7:0] == 8'h04) begin
//if (instruction[7:0] == 8'hc7) begin
//if (instruction[7:0] == 8'hc0) begin
//state <= STATE_ERROR;
//registers[0] <= dest_value;
//registers[0] <= temp;
//registers[0] <= ea;
//registers[0] <= direction;
//end else
          state <= STATE_ALU_EXECUTE_1;
        end
      STATE_ALU_EXECUTE_1:
        begin
          orig <= dest_value;

          case (alu_size)
            2'b01:
              case (alu_op)
                ALU_ADD: result <= dest_value[7:0] + temp[7:0];
                ALU_OR:  result <= dest_value[7:0] | temp[7:0];
                ALU_ADC: result <= dest_value[7:0] + temp[7:0] + flag_carry;
                ALU_SBB: result <= { flag_carry, dest_value[7:0] } + temp[7:0];
                ALU_AND: result <= dest_value[7:0] & temp[7:0];
                ALU_SUB: result <= dest_value[7:0] - temp[7:0];
                ALU_XOR: result <= dest_value[7:0] ^ temp[7:0];
                ALU_CMP: result <= dest_value[7:0] - temp[7:0];
                ALU_MOV: result <= temp[7:0];
                ALU_NEG: result <= 0 - temp[7:0];
                ALU_TEST: result <= dest_value[7:0] & temp[7:0];
              endcase
            2'b10:
              case (alu_op)
                ALU_ADD: result <= dest_value[15:0] + temp[15:0];
                ALU_OR:  result <= dest_value[15:0] | temp[15:0];
                ALU_ADC: result <= dest_value[15:0] + temp[15:0] + flag_carry;
                ALU_SBB: result <= { flag_carry, dest_value[15:0] } + temp[15:0];
                ALU_AND: result <= dest_value[15:0] & temp[15:0];
                ALU_SUB: result <= dest_value[15:0] - temp[15:0];
                ALU_XOR: result <= dest_value[15:0] ^ temp[15:0];
                ALU_CMP: result <= dest_value[15:0] - temp[15:0];
                ALU_MOV: result <= temp[15:0];
                ALU_NEG: result <= 0 - temp[15:0];
                ALU_TEST: result <= dest_value[15:0] & temp[15:0];
              endcase
            default:
              case (alu_op)
                ALU_ADD: result <= dest_value + temp;
                ALU_OR:  result <= dest_value | temp;
                ALU_ADC: result <= dest_value + temp + flag_carry;
                ALU_SBB: result <= { flag_carry, dest_value } + temp;
                ALU_AND: result <= dest_value & temp;
                ALU_SUB: result <= dest_value - temp;
                ALU_XOR: result <= dest_value ^ temp;
                ALU_CMP: result <= dest_value - temp;
                ALU_MOV: result <= temp;
                ALU_NEG: result <= 0 - temp;
                ALU_TEST: result <= dest_value & temp;
              endcase
          endcase

          if (alu_op == ALU_CMP) no_write_back <= 1;

          if (alu_op == ALU_JMP)
            state <= STATE_CALL_0;
          else if (do_imm == 1)
            if (is_mov == 1)
              state <= STATE_ALU_WB_REG;
            else
              state <= STATE_ALU_WB_MEM;
          else if (direction == 0)
            state <= STATE_ALU_WB_MEM;
          else
            state <= STATE_ALU_WB_REG;
        end
      STATE_ALU_WB_REG:
        begin
          case (alu_size)
            2'b01:
              begin
                if (no_write_back == 0) begin
                  if (dst_reg[2] == 0)
                    registers[dst_reg[1:0]][7:0] <= result[7:0];
                  else
                    registers[dst_reg[1:0]][15:8] <= result[7:0];
                end

                if (alu_op != ALU_MOV) set_flags8(result[8:0], orig[7:0]);
              end
            2'b10:
              begin
                if (no_write_back == 0)
                  registers[dst_reg][15:0] <= result[15:0];

                if (alu_op != ALU_MOV == 0)
                  set_flags16(result[16:0], orig[15:0]);
              end
            default:
              begin
                if (no_write_back == 0) registers[dst_reg] <= result;
                if (alu_op != ALU_MOV) set_flags32(result, orig);
              end
          endcase

          state <= STATE_FETCH_OP_0;
        end
      STATE_ALU_WB_MEM:
        begin
          mem_count <= 0;
          temp <= result;
          ea <= ea_save;

          case (alu_size)
            2'b01:
              begin
                mem_last <= 0;
                if (alu_op != ALU_MOV) set_flags8(result[8:0], orig[7:0]);
              end
            2'b11:
              begin
                mem_last <= 1;
                if (alu_op != ALU_MOV) set_flags16(result[16:0], orig[15:0]);
              end
            default:
              begin
                mem_last <= 3;
                if (alu_op != ALU_MOV) set_flags32(result, orig);
              end
          endcase

          if (no_write_back == 0) begin
            state <= STATE_WRITE_EA_0;
            next_state <= STATE_FETCH_OP_0;
          end else begin
            state <= STATE_FETCH_OP_0;
          end
        end
      STATE_MOV_REG_IMM_0:
        begin
          mem_count <= 0;

          case (opcode_size)
            2'b01: mem_last <= 0;
            2'b10: mem_last <= 1;
            default: mem_last <= 3;
          endcase

          state <= STATE_FETCH_DATA32_0;
          next_state <= STATE_MOV_REG_IMM_1;
        end
      STATE_MOV_REG_IMM_1:
        begin
          case (opcode_size)
            2'b01:
              if (instruction[2] == 0)
                registers[instruction[1:0]][7:0] <= temp[7:0];
              else
                registers[instruction[1:0]][15:8] <= temp[7:0];
            2'b10:
              registers[instruction[2:0]][15:0] <= temp[15:0];
            default:
              registers[instruction[2:0]][31:0] <= temp[31:0];
          endcase

          state <= STATE_FETCH_OP_0;
        end
      STATE_FETCH_MOD_RM_0:
        begin
          mem_bus_enable <= 1;
          mem_address <= rip;
          mem_write_enable <= 1;
          state <= STATE_FETCH_MOD_RM_1;
        end
      STATE_FETCH_MOD_RM_1:
        begin
          // WTF Intel?
          reverse_direction <= mem_data_out[7:6] == 2'b11;

          mem_bus_enable <= 0;
          mod_rm <= mem_data_out;
          rip <= rip + 1;

          if (alu_op == ALU_NEG && mod_rm[5:4] == 3'b000) begin
            alu_op <= ALU_TEST;
            state <= STATE_TST_IMM32_0;
          end else if (alu_op == ALU_SHIFT) begin
            state <= STATE_SHIFT_0;
          end else begin
            state <= STATE_ALU_1;
          end
        end
      STATE_FETCH_SIB_0:
        begin
          mem_bus_enable <= 1;
          mem_address <= rip;
          mem_write_enable <= 1;
          state <= STATE_FETCH_SIB_1;
        end
      STATE_FETCH_SIB_1:
        begin
          mem_bus_enable <= 0;
          sib <= mem_data_out;
          rip <= rip + 1;
          state <= STATE_COMPUTE_SIB_EA_0;
        end
      STATE_COMPUTE_SIB_EA_0:
        begin
          // add eax, [esp]:       0x03,0x04,0x24 (sib = 00 100 100)
          // add eax, [esp+edx*4]: 0x03,0x04,0x94 (sib = 10 010 100)
          // add eax, [ebp]:       0x03,0x45,0x00 (sib = none, this is index)
          // add eax, [ebx+edx]:   0x03,0x04,0x13 (sib = 00 010 011)
          // add eax, [ebx+edx*4]: 0x03,0x04,0x93 (sib = 10 010 011)
          if (sib_base == 3'b100 && sib_index == 3'b100) begin
            ea <= registers[4];
            state <= STATE_COMPUTE_EA_1;
          end else begin
            ea <= registers[sib_base];
            state <= STATE_COMPUTE_SIB_EA_1;
          end
        end
      STATE_COMPUTE_SIB_EA_1:
        begin
          ea <= ea + (registers[sib_index] << sib_scale);
          state <= STATE_COMPUTE_EA_1;
        end
      STATE_FETCH_DATA32_0:
        begin
          mem_bus_enable <= 1;
          mem_address <= rip;
          mem_write_enable <= 0;
          state <= STATE_FETCH_DATA32_1;
        end
      STATE_FETCH_DATA32_1:
        begin
          mem_bus_enable <= 0;
          rip <= rip + 1;

          case (mem_count)
            0: temp[7:0]   <= mem_data_out;
            1: temp[15:8]  <= mem_data_out;
            2: temp[23:16] <= mem_data_out;
            3: temp[31:24] <= mem_data_out;
          endcase

          if (mem_count == mem_last)
            state <= next_state;
          else
            state <= STATE_FETCH_DATA32_0;

          mem_count <= mem_count + 1;
        end
      STATE_FETCH_EA_0:
        begin
          mem_bus_enable <= 1;
          mem_address <= ea;
          mem_write_enable <= 0;
          state <= STATE_FETCH_EA_1;
        end
      STATE_FETCH_EA_1:
        begin
          mem_bus_enable <= 0;
          ea <= ea + 1;

          case (mem_count)
            0: temp[7:0]   <= mem_data_out;
            1: temp[15:8]  <= mem_data_out;
            2: temp[23:16] <= mem_data_out;
            3: temp[31:24] <= mem_data_out;
          endcase

          if (mem_count == mem_last)
            state <= next_state;
          else
            state <= STATE_FETCH_EA_0;

          mem_count <= mem_count + 1;
        end
      STATE_WRITE_EA_0:
        begin
          mem_bus_enable <= 1;
          mem_address <= ea;
          mem_write_enable <= 1;

          case (mem_count)
            0: mem_data_in <= temp[7:0];
            1: mem_data_in <= temp[15:8];
            2: mem_data_in <= temp[23:16];
            3: mem_data_in <= temp[31:24];
          endcase

          state <= STATE_WRITE_EA_1;
        end
      STATE_WRITE_EA_1:
        begin
          mem_bus_enable <= 0;
          mem_write_enable <= 0;
          ea <= ea + 1;

          if (mem_count == mem_last)
            state <= next_state;
          else
            state <= STATE_WRITE_EA_0;

          mem_count <= mem_count + 1;
        end
      STATE_POP_0:
        begin
          mem_last <= 3;
          ea <= registers[4];
          registers[4] <= registers[4] + 4;
          state <= STATE_FETCH_EA_0;
          next_state <= STATE_POP_1;
        end
      STATE_POP_1:
        begin
          registers[instruction[2:0]] <= temp;
          state <= STATE_FETCH_OP_0;
        end
      STATE_PUSH_0:
        begin
          ea <= registers[4] - 4;
          registers[4] <= registers[4] - 4;
          mem_last <= 3;
          state <= STATE_WRITE_EA_0;
          next_state <= STATE_FETCH_OP_0;
        end
      STATE_RET_0:
        begin
          mem_count <= 0;
          mem_last <= 3;
          ea <= registers[4];
          state <= STATE_FETCH_EA_0;
          next_state <= STATE_RET_1;
        end
      STATE_RET_1:
        begin
          rip <= temp;
          registers[4] <= registers[4] + 4;
          state <= STATE_FETCH_OP_0;
        end
      STATE_CALL_0:
        begin
          ea <= registers[4] - 4;
          registers[4] <= registers[4] - 4;
          temp <= rip;
          mem_count <= 0;
          mem_last <= 3;

          if (instruction[4] == 0)
            rip <= rip + temp;
          else
            rip <= temp;

          if (dst_reg == 3'b100) begin
            state <= STATE_FETCH_OP_0;
          end else begin
            state <= STATE_WRITE_EA_0;
            next_state <= STATE_FETCH_OP_0;
          end
        end
      STATE_JCC_0:
        begin
          mem_count <= 0;
          mem_last <= long_jmp == 0 ? 0 : 3;
          state <= STATE_FETCH_DATA32_0;
          next_state <= STATE_JCC_1;
        end
      STATE_JCC_1:
        begin
          if (long_jmp == 0)
            temp <= $signed(rip) + $signed(temp[7:0]);
          else
            // Narrow temp for 16 bit rip.
            temp <= $signed(rip) + $signed(temp[15:0]);

          state <= STATE_JCC_2;
        end
      STATE_JCC_2:
        begin
          case (instruction[3:1])
            3'h0:
              begin
                // Overflow (jo / jno).
                if (flag_overflow == ~instruction[0]) rip <= temp;
              end
            3'h1:
              begin
                // Carry flag (jb, jnae, jc / jnb, jae, jnc).
                if (flag_carry == ~instruction[0]) rip <= temp;
              end
            3'h2:
              begin
                // Zero flag (je, jz / jne, jnz).
                if (flag_zero == ~instruction[0]) rip <= temp;
              end
            3'h3:
              begin
                // (jbe, jna / ja, jnbe)
                // (cf == 1 or zf == 1) / (cf == 0 && zf == 0)
                if (instruction[0] == 0)
                  if (flag_carry == 1 || flag_zero == 1) rip <= temp;
                else
                  if (flag_carry == 0 && flag_zero == 0) rip <= temp;
              end
            3'h4:
              begin
                // Sign flag (js /jns).
                if (flag_sign == ~instruction[0]) rip <= temp;
              end
            3'h5:
              begin
                // Parity flag (jp, jpe, jnp, jpo).
                if (flag_parity == ~instruction[0]) rip <= temp;
              end
            3'h6:
              begin
                // (jl, jnge / jge, jnl)
                // (sf <> of) / (sf == of)
                if (instruction[0] == 0)
                  if (flag_sign != flag_overflow) rip <= temp;
                else
                  if (flag_sign == flag_overflow) rip <= temp;
              end
            3'h7:
              begin
                // (jle, jng / jg, jnle)
                // (zf == 1 or sf <> of) / (zf == 0 and sf == of)
                if (instruction[0] == 0)
                  if (flag_zero == 1 || flag_sign != flag_overflow) rip <= temp;
                else
                  if (flag_zero == 0 && flag_sign == flag_overflow) rip <= temp;
              end
          endcase

          state <= STATE_FETCH_OP_0;
        end
      STATE_JMP_0:
        begin
          mem_count <= 0;
          mem_last <= long_jmp == 0 ? 0 : 3;
          state <= STATE_FETCH_DATA32_0;
          next_state <= STATE_JCC_1;
        end
      STATE_JMP_1:
        begin
          if (long_jmp == 0)
            rip <= rip + $signed(temp[7:0]);
          else
            rip <= rip + temp;

          state <= STATE_FETCH_OP_0;
        end
/*
      STATE_ALU_IMM8_0:
        begin
          mod_rm <= temp;
          mem_count <= 0;
          do_imm <= 1;

          state <= STATE_FETCH_DATA32_0;

          case (temp[7:6])
            2'b01:
              begin
                mem_last <= 0;
                next_state <= STATE_ALU_IMM_TO_MEM_0;
              end
            2'b11:
              begin
                mem_last <= 0;
                next_state <= STATE_ALU_IMM8_1;
              end
            default:
              begin
                mem_last <= 3;
                next_state <= STATE_ALU_IMM_TO_MEM_0;
              end
          endcase

        end
*/
/*
      STATE_ALU_IMM8_1:
        begin
          dst_reg <= mod_rm[2:0];

          if (is_mov == 0)
            alu_op  <= mod_rm[5:3];
          else
            alu_op  <= ALU_MOV;

          if (instruction[1] == 1) temp = $signed(temp);
          state <= STATE_ALU_EXECUTE_1;
        end
*/
      STATE_TST_IMM32_0:
        begin
          dst_reg <= mod_rm[2:0];
          dest_value <= registers[mod_rm[2:0]];
          mem_count <= 0;
          mem_last <= 3;
          state <= STATE_FETCH_DATA32_0;
          next_state <= STATE_ALU_EXECUTE_1;
        end
      STATE_SHIFT_0:
        begin
          if (alu_size == 1)
            if (mod_rm[2] == 0)
              dest_value <= registers[mod_rm[1:0]][7:0];
            else
              dest_value <= registers[mod_rm[1:0]][15:8];
          else
            dest_value <= registers[mod_rm[2:0]];

          if (instruction[4] == 0) begin
            mem_count <= 0;
            mem_last <= 0;
            state <= STATE_FETCH_DATA32_0;
            next_state <= STATE_SHIFT_1;
          end else begin
            shift_count <= instruction[1] == 0 ? 1 : registers[1][4:0];
            state <= STATE_SHIFT_2;
          end
        end
      STATE_SHIFT_1:
        begin
          shift_count <= temp[4:0];
          state <= STATE_SHIFT_2;
        end
      STATE_SHIFT_2:
        begin
          case (alu_size)
            2'b01:
              case (shift_op)
                SHIFT_ROL:
                  begin
                    result[7:0] <=
                      (dest_value[7:0] << shift_count) |
                      (dest_value[7:0] >> (8 - shift_count));
                    flag_carry <= dest_value[7];
                  end
                SHIFT_ROR:
                  begin
                    result[7:0] <=
                      (dest_value[7:0] >> shift_count) |
                      (dest_value[7:0] << (8 - shift_count));
                    flag_carry <= dest_value[0];
                  end
                SHIFT_SHL:
                  begin
                    result[7:0] <= dest_value[7:0] << shift_count;
                    flag_carry <= dest_value[7];
                  end
                SHIFT_SHR:
                  begin
                    result[7:0] <= dest_value[7:0] >> shift_count;
                    flag_carry <= dest_value[0];
                  end
                SHIFT_SAR:
                  begin
                    result[7:0] <= $signed(dest_value[7:0]) >>> shift_count;
                    flag_carry <= dest_value[0];
                  end
              endcase
            2'b10:
              case (shift_op)
                SHIFT_ROL:
                  begin
                    result[15:0] <=
                      (dest_value[15:0] << shift_count) |
                      (dest_value[15:0] >> (16 - shift_count));
                    flag_carry <= dest_value[15];
                  end
                SHIFT_ROR:
                  begin
                    result[15:0] <=
                      (dest_value[15:0] >> shift_count) |
                      (dest_value[15:0] << (16 - shift_count));
                    flag_carry <= dest_value[0];
                  end
                SHIFT_SHL:
                  begin
                    result[15:0] <= dest_value[15:0] << shift_count;
                    flag_carry <= dest_value[15];
                  end
                SHIFT_SHR:
                  begin
                    result[15:0] <= dest_value[15:0] >> shift_count;
                    flag_carry <= dest_value[0];
                  end
                SHIFT_SAR:
                  begin
                    result[15:0] <= $signed(dest_value[15:0]) >>> shift_count;
                    flag_carry <= dest_value[0];
                  end
              endcase
            default:
              case (shift_op)
                SHIFT_ROL:
                  begin
                    result[31:0] <=
                      (dest_value[31:0] << shift_count) |
                      (dest_value[31:0] >> (32 - shift_count));
                    flag_carry <= dest_value[7];
                  end
                SHIFT_ROR:
                  begin
                    result[31:0] <=
                      (dest_value[31:0] >> shift_count) |
                      (dest_value[31:0] << (32 - shift_count));
                    flag_carry <= dest_value[0];
                  end
                SHIFT_SHL:
                  begin
                    result <= dest_value << shift_count;
                    flag_carry <= dest_value[31];
                  end
                SHIFT_SHR:
                  begin
                    result <= dest_value >> shift_count;
                    flag_carry <= dest_value[0];
                  end
                SHIFT_SAR:
                  begin
                    result <= $signed(dest_value) >>> shift_count;
                    flag_carry <= dest_value[0];
                  end
              endcase
          endcase

          state <= STATE_SHIFT_WB_REG;
        end
      STATE_SHIFT_WB_REG:
        begin
          case (alu_size)
            2'b01:
              begin
                if (dst_reg[2] == 0)
                  registers[dst_reg][7:0] <= result[7:0];
                else
                  registers[dst_reg][15:8] <= result[7:0];

                flag_zero <= result[7:0] == 0;
                flag_sign <= result[7];
              end
            2'b10:
              begin
                registers[dst_reg][15:0] <= result[15:0];
                flag_zero <= result[15:0] == 0;
                flag_sign <= result[15];
              end
            default:
              begin
                registers[dst_reg] <= result[31:0];
                flag_zero <= result[31:0] == 0;
                flag_sign <= result[31];
              end
          endcase

          state <= STATE_FETCH_OP_0;
        end
      STATE_ALU_IMM_TO_MEM_0:
        begin
          dest_value <= temp;
          mem_count <= 0;

          if (do_alu_imm == 1 && instruction[1] == 1)
            mem_last <= 0;
          else
            case (alu_size)
              2'b01: mem_last <= 0;
              2'b10: mem_last <= 1;
              default: mem_last <= 3;
            endcase

          if (do_alu_imm == 1) alu_op <= mod_rm[5:3];

          next_state <= STATE_ALU_IMM_TO_MEM_1;
          state <= STATE_FETCH_DATA32_0;
        end
      STATE_ALU_IMM_TO_MEM_1:
        begin
          if (do_alu_imm == 1 && instruction[1] == 1)
            temp <= $signed(temp[7:0]);

//state <= STATE_ERROR;
//registers[0] <= direction;
//registers[0] <= $signed(temp[7:0]);
//registers[0] <= dest_value;
//registers[0] <= 8'h69;
          state <= STATE_ALU_EXECUTE_1;
        end
      STATE_HALTED:
        begin
          state <= STATE_HALTED;
        end
      STATE_ERROR:
        begin
          state <= STATE_ERROR;
          mem_write_enable <= 0;
        end
      STATE_EEPROM_START:
        begin
          // Initialize values for reading from SPI-like EEPROM.
          if (eeprom_ready) begin
            eeprom_count <= 0;
            state <= STATE_EEPROM_READ;
          end
        end
      STATE_EEPROM_READ:
        begin
          // Set the next EEPROM address to read from and strobe.
          eeprom_address <= eeprom_count;
          mem_bus_enable <= 1;
          mem_address <= eeprom_count;
          eeprom_strobe <= 1;
          state <= STATE_EEPROM_WAIT;
        end
      STATE_EEPROM_WAIT:
        begin
          // Wait until 8 bits are clocked in.
          eeprom_strobe <= 0;

          if (eeprom_ready) begin
            mem_bus_enable <= 0;
            mem_data_in <= eeprom_data_out;
            eeprom_count <= eeprom_count + 1;
            state <= STATE_EEPROM_WRITE;
          end
        end
      STATE_EEPROM_WRITE:
        begin
          // Write value read from EEPROM into memory.
          mem_bus_enable <= 1;
          mem_write_enable <= 1;
          state <= STATE_EEPROM_DONE;
        end
      STATE_EEPROM_DONE:
        begin
          // Finish writing and read next byte if needed.
          mem_bus_enable <= 0;
          mem_write_enable <= 0;

          if (eeprom_count == 256)
            state <= STATE_FETCH_OP_0;
          else
            state <= STATE_EEPROM_READ;
        end
    endcase
  end
end

memory_bus memory_bus_0(
  .address      (mem_address),
  .data_in      (mem_data_in),
  .data_out     (mem_data_out),
  .bus_enable   (mem_bus_enable),
  .write_enable (mem_write_enable),
  .clk          (clk),
  .raw_clk      (raw_clk),
  //.double_clk   (clock_div[6]),
  .speaker_p    (speaker_p),
  .speaker_m    (speaker_m),
  .ioport_0     (ioport_0),
  .ioport_1     (ioport_1),
  .ioport_2     (ioport_2),
  .ioport_3     (ioport_3),
  .ioport_4     (ioport_4),
  .button_0     (button_0),
  .reset        (~button_reset),
  .spi_clk_0    (spi_clk_0),
  .spi_mosi_0   (spi_mosi_0),
  .spi_miso_0   (spi_miso_0)
);

eeprom eeprom_0
(
  .address    (eeprom_address),
  .strobe     (eeprom_strobe),
  .raw_clk    (raw_clk),
  .eeprom_cs  (eeprom_cs),
  .eeprom_clk (eeprom_clk),
  .eeprom_di  (eeprom_di),
  .eeprom_do  (eeprom_do),
  .ready      (eeprom_ready),
  .data_out   (eeprom_data_out)
);

endmodule

