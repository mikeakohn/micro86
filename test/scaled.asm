
bits 32

org 0x4000
main:
  ;lea eax, [0x4000]
  ;mov eax, [0x4000]
  lea ebx, [0x4000]
  mov eax, 6
  lea eax, [ebx+eax*2]
  ;mov eax, [ebx+eax]
  hlt

