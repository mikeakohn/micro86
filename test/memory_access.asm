
bits 32

BUTTON     equ 0x8000

org 0x4000
main:
  ;mov byte [0x000a], 5
  ;mov al, 5
  ;mov [0x000a], al

  ;mov ebp, 8
  ;add word [ebp+0x2],0x41
  ;mov al, [0x000a]

  ;mov word [ebp+0x2],0xfc00
  ;mov word [ebp+0x2],0xfc
  ;mov [ebp+0x2], word 0xfc00
  ;mov [ebp+0x2], word 0xfc
  ;mov ax, [0x000a]

  ;cmp [BUTTON], byte 1
  ;je button_set
  ;hlt

  ;mov ax, 0xffff
  add bx, 1
  add ax, 1

  ;pushf
  ;pop eax

button_set:
  hlt

  ;mov ebp, 8
  ;mov word [ebp+0x2],0x40
  ;mov al, [ebp+0x000a]

  ;mov eax, 4

  ;; Test scaled
  ;mov word [ebx+eax*4],0x40

  ;mov word [ebp+0x6],0xfc00
  ;mov eax, [ebx+0x4000]
  ;mov eax, [ebx+0x0002]
  ;mov al, [ebx+0x4000]

  hlt

loop:
  ;jmp loop

