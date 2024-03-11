
bits 32

org 0x4000
main:
  mov esp, 0xc000
  mov ebx, 0x8000

  ;lea eax, [esp]
  ;lea eax, [ebx+32]
  lea eax, [esp+32]
  hlt

