#!/usr/bin/env python3

pixels = "FEDCBA9876543210"

def multiply_signed(edi, esi):
  ebp = 0

  if (edi & 0x8000) != 0:
    edi = ((edi ^ 0xffff) + 1) & 0xffff;
    ebp += 1

  if (esi & 0x8000) != 0:
    esi = ((esi ^ 0xffff) + 1) & 0xffff;
    ebp += 1

  #print(esi)
  #print(edi)
  #print(ebp)

  eax = 0

  while esi != 0:
    if (esi & 1) != 0:
      eax += edi

    esi = esi >> 1
    edi = edi << 1

  eax = (eax >> 10) & 0xffff

  if (ebp & 1) != 0:
    eax = ((eax ^ 0xffff) + 1) & 0xffff;

  return eax

# ----------------------------- fold here -------------------------------

curr_i = 0xfc00

for y in range(0, 64):
  curr_r = 0xf800

  for x in range(0, 96):

    zr = curr_r
    zi = curr_i

    for c in range(0, 16):
      zr2 = multiply_signed(zr, zr)
      zi2 = multiply_signed(zi, zi)

      if zr2 + zi2 > (4 << 10): break

      tr = (zr2 - zi2) & 0xffff
      ti = (multiply_signed(zr, zi) << 1) & 0xffff

      zr = (tr + curr_r) & 0xffff
      zi = (ti + curr_i) & 0xffff

    print(pixels[c], end="")
    #print(c, end="")
    curr_r += 0x0020

  print("")
  curr_i += 0x0020

print("%04x" % multiply_signed(0xfc00, 0xf800))

