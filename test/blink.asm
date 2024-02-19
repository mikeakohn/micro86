
bits 32

org 0x4000
main:
  mov ebx, 0x1f1
  add eax, ebx
  ;and eax, 0x0ff0f
  xor eax, ebx
  nop
  inc eax
  hlt

loop:
  ;jmp loop

