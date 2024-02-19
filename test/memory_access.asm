
bits 32

org 0x4000
main:
  mov eax, [ebx+0x4000]
  ;mov al, [ebx+0x4000]
  hlt

loop:
  ;jmp loop

