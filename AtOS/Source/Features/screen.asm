
; The screen file contains graphic functions working on text and color of the screen

; hide cursor hides text mode cursor
; IN/OUT: Nothing
hide_cursor:
	pusha

	mov ch, 32
	mov ah, 1
	mov al, 3			; Must be video mode for buggy BIOSes!
	int 10h

	popa
	ret
	
; show_cursor turns on cursor
; Input: None
; Output: None
show_cursor:
	pusha

	mov ch, 6
	mov cl, 7
	mov ah, 1
	mov al, 3
	int 10h

	popa
	ret

; clear screen destroys the operating system, just kidding, it clears the screen to background color
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
	

; draw_background draws the default background
; Input: AX = top string locations, CX = color
draw_background:

	pusha
	
	push ax				; Store params to pop out later
	
	call hide_cursor
	
	mov bl, 10001111b 	; Drawing dark gray line on top of screen with white text
	mov bh, 0
	xor dx, dx 		; Location (0,0)
	mov si, 80 		; Draw 80 characters
	mov di, 1 	; 1 line
	call draw_blocks 	; Drawing line
	
	xor dx, dx 		 ; Draw Bright blue background
	mov dh, 1
	mov bl, 10011111b 	; White on bright blue
	mov di, 25
	call draw_blocks
	
	pop si 	 ; Popping message input to SI
	mov ax, si
	call string_length
	
	; Calculating X location for the middle of the screen
	; (String length / 2) - (Screen width / 2) will give us the appropriate starting X point
	mov bl, 2
	div bl
	mov dl, 40 	; 40 is the middle of the screen width
	sub dl, al
	
	mov dh, 0 	; Y = 0 (top of screen)
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
	
; move_cursor moves the cursor to given location
; Input: DL = Y, DH = Y
; Output: None
move_cursor:
	
	pusha
	
	mov ah, 2
	mov bh, 0
	int 10h
	
	popa
	ret

	
; get_cursor_pos returns position of cursor
; Input: None
; Output: Position of cursor in DX
; DH = X, DL = Y
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
	
	
; files writes all files into screen
; Input: None
; Output: None
files:
	
	pusha
	
	;Position to start writing files from
	xor dx, dx
	mov dh, 4
	call move_cursor
	
	mov si, file_list ;File list is a comma separated string of files
	
	mov ah, 0Eh			; int 10h teletype function
	
	
.repeat:
	lodsb 
	cmp al, ','
	je .replace_comma
	cmp al, 0
	je .done
	int 10h
	
	jmp .repeat
	
;Instead of comma, go down a line
.replace_comma:
	inc dh
	mov dl, 0
	call move_cursor

	jmp .repeat
	
.done:

	popa
	ret
	
; file_list_dialog draws a gray block with all the current files in the system by getting a string of all filenames seperated by a comma
; Input: File list seperated by a comma
; Output: None
file_list_dialog:

	pusha
	
	xor dx, dx
	call move_cursor
	
	mov dh, max_cursor_pos
	dec dh
	mov si, 22
	mov di, 21
	mov bl, 01111111b 	; Color - white text on gray
	
	call draw_blocks
	
	
	; Parameters to draw a drak gray block
	mov dh, max_cursor_pos 	; Starting y position
	mov dl, 0  ; Starting x position
	mov bl, 10001111b ;Color - white text on gray
	mov si, 20 	; Finish x position
	mov di, 20 	; Finish y position
	
	call draw_blocks	
	call files
	
; Draw white file mark
.draw_mark:
	xor dx, dx
	mov dh, [cursor_ylocation] 	 ; Y position
	mov bl, 11110000b 	; Color - Black text on white
	mov si, 20 	; Width - 20
	mov di, [cursor_ylocation] 	; Max Y = Y + 1
	inc di
	call draw_blocks
	
	call files
	
.scroll_files:

	call wait_for_key
	
	cmp ah, 48h ; Up 
	je .up_pressed
	
	cmp ah, 50h ;Down
	je .down_pressed
	
	jmp .scroll_files
	
.up_pressed:
	
	cmp dh, max_cursor_pos
	je .move_down
	
	dec byte [cursor_ylocation]
	jmp file_list_dialog
	
.down_pressed:
	
	cmp dh, min_cursor_pos
	je .move_up
	
	inc byte [cursor_ylocation]
	jmp file_list_dialog
	
.move_down:
	
	mov dx, min_cursor_pos
	mov [cursor_ylocation], dx
	jmp file_list_dialog
	
	
.move_up:
	mov dx, max_cursor_pos
	mov [cursor_ylocation], dx
	jmp file_list_dialog
	

; commands_dialog draws the list of commands
; Input: None
; Output: DL = Command pressed X location
commands_dialog:
	
	pusha	
	
.drawing:
	; Drawing red box
	mov dh, 3 		; Y = 3
	mov dl, 21		; X = 21  (80/2) - (39/2) = 21, calculating middle of the screen minus middle of the text
	mov bl, 11001111b
	mov si, 39  	; Width
	mov di, 4 		; Finish Y = 4
	call draw_blocks
	

	; Drawing file marker
	mov dl, [cursor_xlocation]
	mov si, 11 ; Width of currently selected file
	mov bl, 11111100b ; Red text on white background
	call draw_blocks
	
	call write_commands
	
.get_input:
	
	call wait_for_key
	
	cmp ah, 4Dh ; Right key 
	je .right_pressed
	
	cmp ah,  4Bh ; Left pressed
	je .left_pressed
	
	cmp ah, 1Ch ; Enter pressed
	je .command_selected
	
	jmp .get_input
	
	
.right_pressed:
	
	cmp dl, 49 ; Max right position
	je .go_left ; If we're at the max right position and we want to move right, go to the max left position
	
	add word [cursor_xlocation], 14 ; Move right
	jmp .drawing
	
.left_pressed:

	cmp dl, 21 ; Max left position
	je .go_right ; If we're at the max left position and we want to move left, go to the max right position 

	sub word [cursor_xlocation], 14 ; Move right
	jmp .drawing

.go_left:
	
	mov word [cursor_xlocation], 21 	 ; Max left position
	jmp .drawing
	
.go_right:

	mov word [cursor_xlocation], 49 	; Max right position
	jmp .drawing
	
.command_selected:
	
	mov [.save_location], dl ; Saving X position to return
	
	popa	
	
	mov dl, [.save_location]
	ret
	
	
	.filename dw 0
	.save_location db 0
	
; write_commands writes all the commands 
; Input: None
; Output: None
write_commands:
	
	pusha 
	
	; Here we are drawing all the available commands of the operating system
	mov dh, 3  	
	mov dl, 21
	call move_cursor
	mov si, command_list
	call print_string  
	
	
	popa
	ret
	
; command_box prints the basic dialog box appearing when choosing commands
; Input: AX = Caption, SI = Message
; Output: None
command_box:

	pusha
	push si
	
	call draw_background
	
	; Drawing red square
	mov dl, 20 	 ; X location to start
	mov dh, 4 	; Y location to start
	mov bl, 11001111b 	; Red color on white text
	mov si, 40 	 ; Width 
	mov di, 14 	; Height
	call draw_blocks
	
	; Drawing gray square inside the red square
	mov dl, 21 	
	mov dh, 5
	mov bl, 11110000b 	 ; Black text on white
	mov si, 38
	mov di, 12
	call draw_blocks

	mov dl, 20
	mov dh, 4
	call move_cursor
	
	pop si
	call print_string
	
	inc dh
	inc dl
	
	call move_cursor
	
	call show_cursor
	
	popa
	ret
	
	
;================================
;DATA
;================================
	command_list db "write file    rename file   delete file", 0 ; Size = 38 bytes/characters
	file_list db "hello.exe,hello.zip,let'sgo.com", 0
	message_files db "Select a file", 0
	cursor_ylocation dw 4
	cursor_xlocation dw 21
	max_cursor_pos equ 4
	min_cursor_pos equ 19

 