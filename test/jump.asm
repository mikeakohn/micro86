
bits 32

org 0x4000
main:
  ;add eax, 1
  ;test eax, 2

  add ebx, 1
  test ebx, 1

  jz skip_led
  call led_on
  jmp blah
  nop
  nop
  nop

blah:
  mov eax, 10
  hlt
  nop

skip_led:
  mov eax, 0xf1
  hlt

led_on:
  ; 0x8008 is the LED.
  mov ebx, 0x8008
  mov eax, 1
  mov [ebx], al
  ret

