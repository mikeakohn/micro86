
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
  mov edi, 0xc000
  mov edx, 0
test_memory_loop_write:
  mov [edi+edx], dx
  add edx, 2
  cmp edx, 200
  jne test_memory_loop_write

  mov esi, 0xc000
  mov eax, 0
  mov edx, 0
test_memory_loop_read:
  mov ax, [esi+edx]
  cmp eax, edx
  jne error_1
  add edx, 2
  cmp edx, 200
  jne test_memory_loop_read
  ret

error_1:
  hlt

