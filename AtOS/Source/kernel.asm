	BITS 16

disk_buffer equ 24576

os_main:
	cli				; Clear interrupts
	xor ax, ax
	mov ss, ax			; Set stack segment and pointer
	mov sp, 0FFFFh
	sti				; Restore interrupts

	cld				; The default direction for string operations
					; will be 'up' - incrementing address in RAM

	mov ax, 2000h			; Set all segments to match where kernel is loaded
	mov ds, ax			; After this, we don't need to bother with
	mov es, ax			; segments ever again, as MikeOS and its programs
	mov fs, ax			; live entirely in 64K
	mov gs, ax

	cmp dl, 0
	je no_change
	mov [bootdev], dl		; Save boot device number
	push es
	mov ah, 8			; Get drive parameters
	int 13h
	pop es
	and cx, 3Fh			; Maximum sector number
	mov [SecsPerTrack], cx		; Sector numbers start at 1
	movzx dx, dh			; Maximum head number
	add dx, 1			; Head numbers start at 0 - add 1 for total
	mov [Sides], dx


no_change:
	mov ax, 1003h			; Set text output with certain attributes
	mov bx, 0			; to be bright, and not blinking
	int 10h


;mov ax, welcome_message
;call draw_background
;call file_list_dialog
xor dx, dx
call move_cursor

mov si, message
call fatten_file
mov si, ax
call print_string

	
foo:
	jmp foo
	

	
	
	
	
	
;=====================================
;			     DATA				     
;=====================================
	
	welcome_message db "AtOS, made from my suffering", 0
	message db "123.exe", 0
	

	
	
;=====================================
;			     INCLUDES				     
;=====================================

	%INCLUDE "Source\Features\string.asm"
	%INCLUDE "Source\Features\screen.asm"
	%INCLUDE "Source\Features\keyboard.asm"
	%INCLUDE "Source\Features\disk.asm"