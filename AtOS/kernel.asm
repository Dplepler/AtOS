	BITS 16

start:
	
	disk_buffer	equ	24576
	
	mov al, 'D'
	mov ah, 0Eh
	int 10h



