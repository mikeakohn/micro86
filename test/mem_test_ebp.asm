
bits 32

org 0x4000
main:
  call run
  hlt

run:
  mov ecx, 1024
run_loop:
  call test_memory
  dec ecx
  jnz run_loop
  ret

test_memory:
  mov ebp, 0xc000
  mov edx, 0
test_memory_loop_write:
  mov [ebp+edx], dx
  add edx, 2
  cmp edx, 200
  jne test_memory_loop_write

  ;ret

  mov eax, 0
  mov ebp, 0xc000
  mov edx, 0
test_memory_loop_read:
  mov ax, [ebp+edx]
  cmp eax, edx
  jne error_1
  add edx, 2
  cmp edx, 200
  jne test_memory_loop_read
  ret

error_1:
  mov eax, edx
  hlt

