
bits 32

org 0x4000
main:
  mov eax, 0x06
  ;sar ax, 4
  ror al, 4
  hlt

