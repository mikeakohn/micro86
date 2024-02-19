#!/usr/bin/env python

import sys, os

if len(sys.argv) != 3 or (sys.argv[1] != "32" and sys.argv[1] != "64"):
  print("Usage: " + sys.argv[0] + " <32 or 64> <asm>")
  sys.exit(0)

out = open("/tmp/test.asm", "w")

out.write("BITS " + sys.argv[1] + "\n")
out.write(sys.argv[2] + "\n")
out.close()

os.system("nasm -o /tmp/test.bin /tmp/test.asm")

code = []
fp = open("/tmp/test.bin", "rb")
while True:
  a = fp.read(1)
  if not a: break
  code.append("0x%02x" % ord(a))
fp.close()

print("  // " + sys.argv[2] + ": " + ",".join(code))
print("  generate_code(generate, " + str(len(code)) + ", " + ", ".join(code) + ");\n")


