# micro86

This is an implementation of 32 bit Intel x86 in an FPGA. The
board being used here is an iceFUN with a Lattice iCE40 HX8K FPGA.

https://www.mikekohn.net/micro/micro86_x86_fpga.php

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

Memory Map
==========

This implementation of the Intel 8008 has 4 banks of memory.

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

