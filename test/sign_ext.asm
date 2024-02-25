
bits 32

org 0x4000
main:
  mov al, 0x80
  cbw
  hlt

loop:
  ;jmp loop

