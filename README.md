# micro86

This is an implementation of 32 bit Intel x86 in an FPGA. The
board being used here is an iceFUN with a Lattice iCE40 HX8K FPGA.

https://www.mikekohn.net/micro/micro_x86_68000_fpga.php

This only implements the important instructions, but does include all
the strange addressing modes. Example of some instructions:

    mov eax, [ebx+0x4000]
    mov ebx, 0xf1
    mov [0x0004], ebx
    mov eax, [0x0004]
    lea eax, [ebx+eax*2]
    call eax
    test ebx, 1
    jz skip_led
    call led_on
    hlt
    ret
    push ebx
    rol eax, cl
    shr eax, 5

* 32, 16, 8 bit register access.
* All the standard ALU and mov instructions with their addressing modes.
* The push and pop only work with 32 bit registers.

The memory model is 8 bit, so reading and writing 32 bits takes 4 memory
cycles. Kind of slow, but easier to implement.

Implemnted Instructions
=======================

Here's a list of instructions that are implemented. There are possibly
others missing here.

    adc
    add
    and
    call
    cbw
    cwde
    cmp
    dec (reg only, only 16 and 32 bit)
    inc (reg only, only 16 and 32 bit)
    jcc
    jmp
    lea
    mov
    neg
    or
    pop
    push
    pushf
    ret
    sbb
    sha
    shl
    shr
    sub
    xor
    test

Unsupported addressing modes (This should work now, haven't tested fully):

    // lea eax, [ebp+ecx*4]: 0x8d,0x44,0x8d,0x00
    // lea eax, [ebp+ecx*4+100]: 0x8d,0x44,0x8d,0x64
    // lea eax, [ebp+ecx*4+128]: 0x8d,0x84,0x8d,0x80,0x00,0x00,0x00
    // lea eax, [ebx+ecx*4+100]: 0x8d,0x44,0x8b,0x64

Looks like ebp is kind of special due to the weird x86 instruction
encodings. This would actually be pretty easy to implement, but
this design is running out of LUTs. Trying to keep it under 4200
to target a smaller FPGA.

Shifted out bits on the shift instructions also won't correctly
compute the carry flag if the shift is more than 1 bit. This can
be corrected later after branching the code for a smaller FPGA.

Shifts also only work on registers.

Memory Map
==========

This implementation of the Intel x86 has 4 banks of memory.

* Bank 0: RAM (4096 bytes)
* Bank 1: ROM (4096 bytes loaded from rom.txt)
* Bank 2: Peripherals
* Bank 3: RAM (4096 bytes)

On start-up by default, the chip will load a program from a AT93C86A
2kB EEPROM with a 3-Wire (SPI-like) interface but wll run the code
from the ROM. To start the program loaded to RAM, the program select
button needs to be held down while the chip is resetting.

The peripherals area contain the following:

* 0x8000: input from push button
* 0x8008: ioport0 output (in my test case only 1 pin is connected)
* 0x8009: MIDI note value (60-96) to play a tone on the speaker or 0 to stop

