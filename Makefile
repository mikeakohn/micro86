
PROGRAM=micro86
SOURCE= \
  src/$(PROGRAM).v \
  src/eeprom.v \
  src/memory_bus.v \
  src/peripherals.v \
  src/ram.v \
  src/rom.v \
  src/spi.v

default:
	yosys -q -p "synth_ice40 -top $(PROGRAM) -json $(PROGRAM).json" $(SOURCE)
	nextpnr-ice40 -r --hx8k --json $(PROGRAM).json --package cb132 --asc $(PROGRAM).asc --opt-timing --pcf icefun.pcf
	icepack $(PROGRAM).asc $(PROGRAM).bin

tang_nano:
	yosys -q \
	  -D TANG_NANO \
	  -p "read_verilog $(SOURCE); synth_gowin -json $(PROGRAM).json -family gw2a"
	nextpnr-himbaechel -r \
	  --json $(PROGRAM).json \
	  --write $(PROGRAM)_pnr.json \
	  --freq 27 \
	  --vopt family=GW2A-18C \
	  --vopt cst=tangnano20k.cst \
	  --device GW2AR-LV18QN88C8/I7
	gowin_pack -d GW2A-18C -o $(PROGRAM).fs $(PROGRAM)_pnr.json

program:
	iceFUNprog $(PROGRAM).bin

blink:
	nasm -o rom.bin test/blink.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

lcd:
	nasm -o rom.bin test/lcd.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

music:
	nasm -o rom.bin test/music.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

memory:
	nasm -o rom.bin test/memory_access.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

immediate:
	nasm -o rom.bin test/immediate.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

scaled:
	nasm -o rom.bin test/scaled.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

write_mem:
	nasm -o rom.bin test/write_mem.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

memory_access:
	nasm -o rom.bin test/memory_access.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

stack:
	nasm -o rom.bin test/stack.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

call:
	nasm -o rom.bin test/call.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

neg:
	nasm -o rom.bin test/neg.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

shift:
	nasm -o rom.bin test/shift.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

jump:
	nasm -o rom.bin test/jump.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

sign_ext:
	nasm -o rom.bin test/sign_ext.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

lea:
	nasm -o rom.bin test/lea.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

mem_test:
	nasm -o rom.bin test/mem_test.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

mem_test_ebp:
	nasm -o rom.bin test/mem_test_ebp.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

disasm:
	ndisasm -b 32 rom.bin

clean:
	@rm -f $(PROGRAM).bin $(PROGRAM).json $(PROGRAM).asc *.lst
	@rm -f blink.bin test_alu.bin test_shift.bin test_subroutine.bin
	@rm -f button.bin
	@echo "Clean!"

