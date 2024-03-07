
bits 32

org 0x4000
main:
  mov byte [0x0002], 5

  ;mov word [ebx+0x2],0x40
  mov word [ebx+eax*4],0x40
  mov al, [ebp+0x0002]

  ;mov word [ebp+0x6],0xfc00
  ;mov eax, [ebx+0x4000]
  ;mov eax, [ebx+0x0002]
  ;mov al, [ebx+0x4000]

  hlt

loop:
  ;jmp loop

