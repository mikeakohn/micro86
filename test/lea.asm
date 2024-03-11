
bits 32

org 0x4000
main:
  mov esp, 0xc000
  mov ebx, 0x8000
  mov eax, 8

  ;lea eax, [esp]
  ;lea eax, [ebx+32]
  lea eax, [esp+eax+32]
  hlt

