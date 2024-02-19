
bits 32

org 0x4000
main:
  mov ebx, 0xf1
  mov [0x0004], ebx
  mov eax, [0x0004]

  ; 0x8008 should be LED.
  mov ebx, 0x8008
  mov eax, 1
  mov [ebx], eax

  ;mov ebx, 100
  ;push ebx
  ;mov eax, [0x0ffc]

  hlt

