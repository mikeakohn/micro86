
bits 32

org 0x4000
main:
  call delay
  call set_led_on
  call delay
  call set_led_off
  jmp main

  hlt

set_led_on:
  mov al, 1
  mov [0x8008], al
  ret

set_led_off:
  mov al, 0
  mov [0x8008], al
  ret

delay:
  mov ebx, 0xffff
delay_loop:
  dec ebx
  jnz delay_loop
  ret

