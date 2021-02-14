import os


COMMANDS = ["nasm -O0 -f bin -o Source\\Bootload\\bootload.bin Source\\Bootload\\bootload.asm", 
			"nasm -O0 -f bin -o Source\\kernel.bin Source\\kernel.asm", 
			"PartCopy Source\\Bootload\\bootload.bin DiskImages\\AtOS.flp 0d 511d", 
			"imdisk -a -f DiskImages\\AtOS.flp -s 1440K -m B:", 
			"copy Source\\kernel.bin b:\\",
			"imdisk -D -m B:"]




for command in COMMANDS:
	os.system(command)