
bits 32

org 0x4000
main:
  mov bh, 0x14
  mov ch, 0x31
  ;mov al, 0x26
  ;add al, 10
  mov al, bh
  add al, ch
  ;mov ebx, 0x4000
  ;mov al, [0x4000]
  hlt

loop:
  ;jmp loop

