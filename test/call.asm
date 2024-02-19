
bits 32

org 0x4000
main:
  mov eax, led_on
  call eax
  call blah
  hlt

blah:
  mov ebx, 0xf1
  mov [0x0004], ebx
  mov eax, [0x0004]
  ret

led_on:
  ; 0x8008 is the LED.
  mov ebx, 0x8008
  mov eax, 1
  mov [ebx], eax
  ret

