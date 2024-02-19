
bits 32

org 0x4000
main:
  ;mov bh, 0x14
  ;mov al, 0xff
  ;add al, bh
  ;mov ebx, 0x4000
  mov al, [0x4000]
  hlt

loop:
  ;jmp loop

