
bits 32

org 0x4000
main:
  mov ebx, 0x1386
  push ebx
  pop eax
  hlt

