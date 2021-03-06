




;Function hides text mode cursor
; IN/OUT: Nothing
hide_cursor:
	pusha

	mov ch, 32
	mov ah, 1
	mov al, 3			; Must be video mode for buggy BIOSes!
	int 10h

	popa
	ret




;Function clears screen
clear_screen:
	pusha

	xor dx, dx			; Position cursor at top-left
	call move_cursor

	mov ah, 6			; Scroll full-screen
	mov al, 0			; Normal white on black
	mov bh, 7			;
	mov cx, 0			; Top-left
	mov dh, 35			; Bottom-right
	mov dl, 79
	int 10h

	popa
	ret
	

;Function draws the default background
; IN: AX = top string locations, CX = color

draw_background:

	pusha
	
	push ax				; Store params to pop out later
	
	call hide_cursor
	
	mov bl, 10001111b
	mov bh, 0
	xor dx, dx
	mov si, 80
	mov di, 1
	call draw_blocks
	
	xor dx, dx
	mov dh, 1
	mov bl, 10011111b
	mov di, 25
	call draw_blocks
	
	pop si
	
	xor dx, dx
	mov dl, 23
	
	call move_cursor
	
	call print_string
	
	popa
	ret
	
	
; Function renders a block at a specified location
; IN: BL/DL/DH/SI/DI = color/start X pos/start Y pos/width/finish Y pos

draw_blocks:
	pusha

.more:
	call move_cursor		; Move to block starting position

	mov ah, 9 				; Draw color section
	mov cx, si
	mov al, ' '
	int 10h

	inc dh				; Get ready for next line

	mov ax, 0
	mov al, dh			; Get current Y position into DL
	
	cmp ax, di			; Reached finishing point (DI)?
	jne .more			; If not, keep drawing

	popa
	ret
	

move_cursor:
	
	pusha
	
	mov ah, 2
	mov bh, 0
	int 10h
	
	popa
	ret
	
;Function returns position of cursor
;Input: None
;Output: Position of cursor in dx 
;dh = x, dl = y
get_cursor_pos:
	pusha

	mov bh, 0
	mov ah, 3
	int 10h				; BIOS interrupt to get cursor position

	mov [.tmp], dx
	popa
	mov dx, [.tmp]
	ret


	.tmp dw 0
	
	
;Function writes all files into screen
;Input: None
;Output: None
files:
	
	pusha
	
	;Position to start writing files from
	xor dx, dx
	mov dh, 4
	call move_cursor
	
	mov si, file_list
	
	mov ah, 0Eh			; int 10h teletype function
	
	
.repeat1:
	lodsb 
	cmp al, ','
	je .replace_comma
	cmp al, 0
	je .done
	int 10h
	
	jmp .repeat1
	
;Instead of comma, go down a line
.replace_comma:
	inc dh
	mov dl, 0
	call move_cursor

	jmp .repeat1
	
.done:

	popa
	ret
	
file_list_dialog:

	pusha
	
	;Parameters to draw a drak gray block
	mov dh, 4
	mov dl, 0
	mov bl, 10001111b
	mov si, 20
	mov di, 20
	
	call draw_blocks
	
	call files
	
;Draw white file mark
.draw_mark:
	xor dx, dx
	mov dh, [cursor_ylocation]
	mov bl, 11110000b
	mov si, 20
	mov di, [cursor_ylocation]
	inc di
	call draw_blocks
	
	call files
	
.scroll_files:

	call wait_for_key
	
	cmp ah, 48h
	je .up_pressed
	
	cmp ah, 50h ;Down
	je .down_pressed
	
	jmp .scroll_files
	
.up_pressed:
	
	cmp dh, max_cursor_pos
	je .scroll_files
	
	dec byte [cursor_ylocation]
	jmp file_list_dialog
	
.down_pressed:
	
	cmp dh, min_cursor_pos
	je .scroll_files
	
	inc byte [cursor_ylocation]
	jmp file_list_dialog
	
	popa
	ret
	
	

	
	
;================================
;DATA
;================================
file_list db "hello.exe,toe.mm,shitandpoop.kaki", 0
message_files db "Select a file", 0
cursor_ylocation dw 4
max_cursor_pos equ 4
min_cursor_pos equ 19







 