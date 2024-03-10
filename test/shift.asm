
bits 32

org 0x4000
main:
  mov esi, 0x0c
  shr esi, 1
  mov eax, esi
  hlt

