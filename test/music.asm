
bits 32

;org 0x4000
org 0x0000

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

start:

main:

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
  call play_song
  jmp main_while_1

play_song:
  mov esi, song
play_song_loop:
  mov edx, 0
  mov ax, [esi]
  mov dx, [esi+2]
  cmp edx, 0
  jz play_song_exit
  add esi, 4
  mov [0x8009], ax
play_song_delay:
  mov ecx, 100
play_song_delay_inner:
  dec ecx
  jnz play_song_delay_inner
  dec edx
  jnz play_song_delay
  jmp play_song_loop
play_song_exit:
  ;mov ax, 0
  mov byte [0x8009], 0
  ret

delay:
  mov ebx, 0xffff
delay_loop:
  dec ebx
  jnz delay_loop
  ret

song:
  dw 85,  250, 83,  250, 85, 1000, 78, 1000, 0,  1500, 86, 250,
  dw 85,  250, 86,  500, 85,  500, 83, 1000, 0,  1500, 86, 250,
  dw 85,  250, 86, 1000, 78, 1000,  0, 1500, 83,  250, 81, 250,
  dw 83,  500, 81,  500, 80,  500, 83,  500, 81, 1500, 85, 250,
  dw 83,  250, 85, 1000, 78, 1000,  0, 1500, 86,  250, 85, 250,
  dw 86,  500, 85,  500, 83, 1000,  0, 1500, 86,  250, 85, 250,
  dw 86, 1000, 78, 1000,  0, 1500, 83,  250, 81,  250, 83, 500,
  dw 81,  500, 80,  500, 83,  500, 81, 1500, 80,  250, 81, 250,
  dw 83, 1500, 81,  250, 83,  250, 85,  500, 83,  500, 81, 500,
  dw 80,  500, 78, 1000, 86, 1000, 85, 3000, 85,  250, 86, 250,
  dw 85,  250, 83,  250, 85, 4000,  0, 2000,  0,    0

