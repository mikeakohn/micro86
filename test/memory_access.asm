
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

  ;mov [ebp+0x8],ax
  ;mov [ebp+0xa],bx

  mov ebp,0xc000
  mov ebx,0x4000
  mov ecx, 10

  mov ax, 0
  mov word [ebp+0x2],0x20

  ;mov ecx, 0x1234
  ;mov ebx,0xc000

  ;mov word [0xc002], 0x1234
  ;sub word [0xc002], 1
  ;sub word [0xc002], 0x1000
  ;mov eax, [ebx+0xf]
  ;mov ax, [0x400f]

loop_1:
  add ax,1 
  ;sub cx, 128
  ;sub word [ebp+0x4], 0x1
  sub word [ebp+0x2], 0x1
  jnz loop_1

  ;mov ax, cx

  ;mov ax, 0xff
  ;add ax, 1
  ;mov ax, 7

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

