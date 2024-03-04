
bits 32

org 0x4000

;; Registers.
BUTTON     equ 0x4000
SPI_TX     equ 0x4001
SPI_RX     equ 0x4002
SPI_CTL    equ 0x4003
PORT0      equ 0x4008
SOUND      equ 0x4009
SPI_IO     equ 0x400a

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

%define send_command(value) \
  mov al, value; \
  call lcd_send_cmd

start:
  call lcd_init
  call lcd_clear

main:

main_while_1:
  call delay
  ;; LED on.
  mov al, 1
  mov [0x8008], al
  call delay
  ;; LED off.
  mov al, 0
  mov [0x8008], al
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

;; lcd_send_cmd(al)
lcd_send_cmd:
  mov bl, LCD_RES
  mov [SPI_IO], bl
  mov [SPI_TX], al
  mov [SPI_CTL], byte SPI_START
lcd_send_cmd_wait:
  test [SPI_CTL], byte SPI_BUSY
  jnz lcd_send_cmd_wait
  mov bl, LCD_CS | LCD_RES
  mov [SPI_IO], bl
  ret

;; lcd_send_data(ax)
lcd_send_data:
  mov bl, LCD_DC | LCD_RES
  mov [SPI_IO], bl
  mov [SPI_TX], ax
  mov [SPI_CTL], byte SPI_16 | SPI_START
lcd_send_data_wait:
  test [SPI_CTL], byte SPI_BUSY
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

