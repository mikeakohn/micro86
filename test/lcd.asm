
bits 32

org 0x4000

;; Variables
curr_x equ 0
curr_y equ 2
curr_r equ 4
curr_i equ 6
zr     equ 8
zi     equ 10
count  equ 12
zr2    equ 14
zi2    equ 16
tr     equ 18
ti     equ 20

;; Registers.
BUTTON     equ 0x8000
SPI_TX     equ 0x8001
SPI_CTL    equ 0x8003
SPI_RX     equ 0x8004
PORT0      equ 0x8008
SOUND      equ 0x8009
SPI_IO     equ 0x800a

;; Bits in SPI_CTL.
SPI_BUSY   equ 0x01
SPI_START  equ 0x02
SPI_16     equ 0x04

;; Bits in SPI_IO.
LCD_RES    equ 0x01
LCD_DC     equ 0x02
LCD_CS     equ 0x04

;; Bits in PORT0
LED0       equ 0x01

COMMAND_DISPLAY_OFF     equ 0xae
COMMAND_SET_REMAP       equ 0xa0
COMMAND_START_LINE      equ 0xa1
COMMAND_DISPLAY_OFFSET  equ 0xa2
COMMAND_NORMAL_DISPLAY  equ 0xa4
COMMAND_SET_MULTIPLEX   equ 0xa8
COMMAND_SET_MASTER      equ 0xad
COMMAND_POWER_MODE      equ 0xb0
COMMAND_PRECHARGE       equ 0xb1
COMMAND_CLOCKDIV        equ 0xb3
COMMAND_PRECHARGE_A     equ 0x8a
COMMAND_PRECHARGE_B     equ 0x8b
COMMAND_PRECHARGE_C     equ 0x8c
COMMAND_PRECHARGE_LEVEL equ 0xbb
COMMAND_VCOMH           equ 0xbe
COMMAND_MASTER_CURRENT  equ 0x87
COMMAND_CONTRASTA       equ 0x81
COMMAND_CONTRASTB       equ 0x82
COMMAND_CONTRASTC       equ 0x83
COMMAND_DISPLAY_ON      equ 0xaf

%macro send_command 1
  mov al, %1
  call lcd_send_cmd
%endmacro

start:

main:
  call lcd_init
  call lcd_clear

main_while_1:
  call delay
  ;; Check button.
  cmp [BUTTON], byte 1
  je run
  ;; LED on.
  mov al, 1
  mov [PORT0], al
  call delay
  ;; Check button.
  cmp [BUTTON], byte 1
  je run
  ;; LED off.
  mov al, 0
  mov [PORT0], al
  jmp main_while_1

run:
  call lcd_clear_2
  call mandelbrot
  jmp main_while_1

lcd_init:
  mov bl, LCD_CS
  mov [SPI_IO], bl
  call delay
  mov bl, LCD_CS | LCD_RES
  mov [SPI_IO], bl

  send_command(COMMAND_DISPLAY_OFF)
  send_command(COMMAND_SET_REMAP)
  send_command(0x72)
  send_command(COMMAND_START_LINE)
  send_command(0x00)
  send_command(COMMAND_DISPLAY_OFFSET)
  send_command(0x00)
  send_command(COMMAND_NORMAL_DISPLAY)
  send_command(COMMAND_SET_MULTIPLEX)
  send_command(0x3f)
  send_command(COMMAND_SET_MASTER)
  send_command(0x8e)
  send_command(COMMAND_POWER_MODE)
  send_command(COMMAND_PRECHARGE)
  send_command(0x31)
  send_command(COMMAND_CLOCKDIV)
  send_command(0xf0)
  send_command(COMMAND_PRECHARGE_A)
  send_command(0x64)
  send_command(COMMAND_PRECHARGE_B)
  send_command(0x78)
  send_command(COMMAND_PRECHARGE_C)
  send_command(0x64)
  send_command(COMMAND_PRECHARGE_LEVEL)
  send_command(0x3a)
  send_command(COMMAND_VCOMH)
  send_command(0x3e)
  send_command(COMMAND_MASTER_CURRENT)
  send_command(0x06)
  send_command(COMMAND_CONTRASTA)
  send_command(0x91)
  send_command(COMMAND_CONTRASTB)
  send_command(0x50)
  send_command(COMMAND_CONTRASTC)
  send_command(0x7d)
  send_command(COMMAND_DISPLAY_ON)
  ret

lcd_clear:
  mov edx, 96 * 64
lcd_clear_loop:
  mov eax, 0x0f0f
  call lcd_send_data
  dec edx
  jnz lcd_clear_loop
  ret

lcd_clear_2:
  mov edx, 96 * 64
lcd_clear_loop_2:
  mov eax, 0xf00f
  call lcd_send_data
  dec edx
  jnz lcd_clear_loop_2
  ret

multiply:
  mov eax, 0
multiply_loop:
  shr esi, 1
  jnc multiply_skip_add
  add eax, edi
multiply_skip_add:
  shl edi, 1
  cmp esi, 0
  jnz multiply_loop
  ;sar eax, 10
  and eax, 0xffff
  ret

multiply_signed:
  mov ebx, 0
  test edi, 0x8000
  jz multiply_signed_edi_plus
  add ebx, 1
  neg di
multiply_signed_edi_plus:
  test esi, 0x8000
  jz multiply_signed_esi_plus
  add ebx, 1
  neg si
multiply_signed_esi_plus:
  and esi, 0xffff
  and edi, 0xffff
  mov eax, 0
multiply_signed_loop:
  shr esi, 1
  jnc multiply_signed_skip_add
  add eax, edi
multiply_signed_skip_add:
  shl edi, 1
  cmp esi, 0
  jnz multiply_signed_loop
  ;sar eax, 10
  and eax, 0xffff
  cmp ebx, 1
  jnz multiply_signed_exit
  neg ax
multiply_signed_exit:
  ret

mandelbrot:
  ;; Store local variables in 0xc000 pointed to by ebp.
  mov ebp, 0xc000

  ;; 0:  uint16_t x;
  ;; 2:  uint16_t y;
  ;; 4:  uint16_t r;
  ;; 6:  uint16_t i;
  ;; 8:  uint16_t zr;
  ;; 10: uint16_t zi;
  ;; final int DEC_PLACE = 10;
  ;; final int r0 = (-2 << DEC_PLACE);
  ;; final int i0 = (-1 << DEC_PLACE);
  ;; final int r1 = (1 << DEC_PLACE);
  ;; final int i1 = (1 << DEC_PLACE);
  ;; final int dx = (r1 - r0) / 96; (0x0020)
  ;; final int dy = (i1 - i0) / 64; (0x0020)

  ;; for (y = 0; y < 64; y++)
  mov word [ebp+curr_y], 64

  ;; int i = -1 << 10;
  mov word [ebp+curr_i], 0xfc00
mandelbrot_for_y:

  ;; for (x = 0; x < 96; x++)
  mov word [ebp+curr_x], 96

  ;; int r = -2 << 10;
  mov word [ebp+curr_r], 0xf800
mandelbrot_for_x:
  ;; zr = r;
  ;; zi = i;
  mov ax, [ebp+curr_r]
  mov bx, [ebp+curr_i]
  mov [ebp+zr], ax
  mov [ebp+zi], bx

  ;; for (int count = 0; count < 15; count++)
  mov ecx, 15
mandelbrot_for_count:
  ;; zr2 = (zr * zr) >> DEC_PLACE;
  mov si, [ebp+zr]
  mov di, [ebp+zr]
  call multiply_signed
  mov [ebp+zr2], ax

  ;; zi2 = (zi * zi) >> DEC_PLACE;
  mov si, [ebp+zi]
  mov di, [ebp+zi]
  call multiply_signed
  mov [ebp+zi2], ax

  ;; if (zr2 + zi2 > (4 << DEC_PLACE)) { break; }
  ;; cmp does: 4 - (zr2 + zi2).. if it's negative it's bigger than 4.
  add ax, [ebp+zr2]
  cmp ax, 4
  ja mandelbrot_stop

  ;; tr = zr2 - zi2;
  mov ax, [ebp+zr2]
  sub ax, [ebp+zi2]
  mov [ebp+tr], ax

  ;; ti = ((zr * zi) >> DEC_PLACE) << 1;
  mov si, [ebp+zr]
  mov di, [ebp+zi]
  call multiply_signed
  mov [ebp+ti], ax

  ;; zr = tr + curr_r;
  mov ax, [ebp+tr]
  add ax, [ebp+curr_r]
  mov [ebp+zr], ax

  ;; zi = ti + curr_i;
  mov ax, [ebp+ti]
  add ax, [ebp+curr_i]
  mov [ebp+zi], ax

  sub ecx, 1
  jnz mandelbrot_for_count
mandelbrot_stop:

  mov edx, colors
  mov eax, [edx+ecx*2]

  call lcd_send_data

  add word [ebp+curr_r], 0x0020
  sub word [ebp+curr_x], 1
  jnz mandelbrot_for_x

  add word [ebp+curr_i], 0x0020
  sub word [ebp+curr_y], 1
  jnz mandelbrot_for_y

  ;; Test code.
  ;mov edi, 0xfffe
  ;mov esi, 4
  ;call multiply_signed
  ;hlt

  ret

;; lcd_send_cmd(al)
lcd_send_cmd:
  mov bl, LCD_RES
  mov [SPI_IO], bl
  mov [SPI_TX], al
  mov al, SPI_START
  mov [SPI_CTL], al
lcd_send_cmd_wait:
  mov al, [SPI_CTL]
  test al, SPI_BUSY
  jnz lcd_send_cmd_wait
  mov bl, LCD_CS | LCD_RES
  mov [SPI_IO], bl
  ret

;; lcd_send_data(ax)
lcd_send_data:
  mov bl, LCD_DC | LCD_RES
  mov [SPI_IO], bl
  mov [SPI_TX], ax
  mov al, SPI_16 | SPI_START
  mov [SPI_CTL], al
lcd_send_data_wait:
  mov al, [SPI_CTL]
  test al, SPI_BUSY
  jnz lcd_send_data_wait
  mov bl, LCD_CS | LCD_RES
  mov [SPI_IO], bl
  ret

delay:
  mov ebx, 0xffff
delay_loop:
  dec ebx
  jnz delay_loop
  ret

colors:
  dw 0x0000
  dw 0x000c
  dw 0x0013
  dw 0x0015
  dw 0x0195
  dw 0x0335
  dw 0x04d5
  dw 0x34c0
  dw 0x64c0
  dw 0x9cc0
  dw 0x6320
  dw 0xa980
  dw 0xaaa0
  dw 0xcaa0
  dw 0xe980
  dw 0xf800

