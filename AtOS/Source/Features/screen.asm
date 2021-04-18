
; The screen file contains graphic functions working on text and color of the screen

; hide cursor hides text mode cursor
; Input: None
; Output: None
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
	

; commands_dialog draws the list of commands
; Input: None
; Output: DL = Command pressed X location
commands_dialog:
	
	pusha	
	
	; Drawing frame for the command box
	mov dh, 2
	mov dl, 20
	mov bl, 01110000b ; Black on gray
	mov bh, 0
	mov si, 40
	mov di, 7
	call draw_blocks
	
.drawing:

	; Drawing red box
	mov dh, 3 		; Y = 3
	mov dl, 21		; X = 21  (80/2) - (41/2) = 20, calculating middle of the screen minus middle of the red box
	mov bl, 11001111b
	mov bh, 0
	mov si, 38  	; Width
	mov di, 6 		; Finish Y = 6
	call draw_blocks
	

	; Drawing file marker
	mov dl, [cursor_xlocation]
	mov dh, [cursor_ylocation]
	mov si, 11 					; Width of currently selected file
	mov bl, 11111100b 			; Red text on white background
	mov di, [cursor_ylocation]
	inc di
	call draw_blocks
	
	call write_commands
	
.get_input:
	
	call wait_for_key
	
	cmp ah, 4Dh ; Right key 
	je .right_pressed
	
	cmp ah,  4Bh ; Left pressed
	je .left_pressed
	
	cmp ah, 50h  ; Down pressed
	je .down_pressed
	
	cmp ah, 48h
	je .up_pressed
	
	cmp ah, 1Ch ; Enter pressed
	je .command_selected
	
	jmp .get_input
	
	
.right_pressed:
	
	cmp dl, 47 ; Max right position
	jae .go_left ; If we're at the max right position and we want to move right, go to the max left position
	
	add byte [cursor_xlocation], 13 ; Move right
	jmp .drawing
	
.left_pressed:

	cmp dl, 21 ; Max left position
	jbe .go_right ; If we're at the max left position and we want to move left, go to the max right position 

	sub byte [cursor_xlocation], 13 ; Move right
	jmp .drawing
	
.down_pressed:
	
	cmp dh, 5
	je .drawing
	
	inc byte [cursor_ylocation]
	jmp .drawing
	
.up_pressed:

	cmp dh, 3
	je .drawing
	
	dec byte [cursor_ylocation]
	jmp .drawing
	

.go_left:
	
	mov byte [cursor_xlocation], 21 	 ; Max left position
	jmp .drawing
	
.go_right:

	mov byte [cursor_xlocation], 47 	; Max right position
	jmp .drawing
	

	
.command_selected:
	
	mov [.save_locationX], dl ; Saving X position to return
	mov [.save_locationY], dh ; Saving Y position to return
	
	popa	
	
	mov dl, [.save_locationX]
	mov dh, [.save_locationY]
	ret
	
	.save_locationX db 0
	.save_locationY db 0
	
; write_commands writes all the commands 
; Input: None
; Output: None
write_commands:
	
	pusha 
	
	; Here we are drawing all the available commands of the operating system
	mov dh, 3  	
	mov dl, 21
	call move_cursor
	mov si, command_list1
	call print_string 
	inc dh
	call move_cursor
	mov si, command_list2
	call print_string
	inc dh
	call move_cursor
	mov si, command_list3
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
	mov bl, 11001111b 	; White text on red
	mov bh, 0
	mov si, 40 	 ; Width 
	mov di, 14 	; Height
	call draw_blocks
	
	; Drawing gray square inside the red square
	mov dl, 21 	
	mov dh, 5
	mov bl, 11110000b 	 ; Black text on white
	mov bh, 0
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
	
	
; text_box prints the box where the user will write some fresh text
; Input: AX = Caption, SI = Message
; Output: None
text_box:

	pusha
	push si
	
	call draw_background
	
	; Drawing red square
	mov dl, 23 	 ; X location to start
	mov dh, 2 	; Y location to start
	mov bl, 11001111b 	; Red color on white text
	mov bh, 0
	mov si, 34 	 ; Width 
	mov di, 25 	; Height
	call draw_blocks
	
	; Drawing white square inside the red square
	mov dl, 24 	
	mov dh, 3
	mov bl, 11110000b 	 ; Black text on white
	mov si, 32
	mov di, 24
	call draw_blocks

	mov dl, 23
	mov dh, 2
	call move_cursor
	
	pop si
	call print_string
	
	inc dh
	inc dl
	
	call move_cursor
	
	popa
	ret
	
; move_marker moves the marker
; Input: CX = number of files, DI = location of empty filename, BL = directory flag (if set this will only move through directories)
; Output: selected filename string location in DI, carry if canceled
move_marker:

	pusha
	push di	
	
	mov byte [.dir_flag], bl
	
	call hide_cursor
	
	cmp cx, 21
	ja .adjust_num_of_files 			; If there are more files than can be displayed adjust number
	
	mov word [.num_of_files], cx 	; Store CX param
	add word [.num_of_files], 2 	; Now .num_of_files will contain the max Y position
	
	mov byte [.Xlocation], 24
	mov byte [.Ylocation], 3
	
.drawing:
	
	;drawing marker
	mov dl, [.Xlocation]
	mov dh, [.Ylocation]
	mov bl, 10001111b 	; White text on gray
	mov bh, 0
	mov si, 12
	xor ax, ax
	mov al, dh
	inc al 
	mov di, ax
	call draw_blocks
	
	mov bl, [.dir_flag]

	call show_all_files 	; Get comma seperated string of all files
	cmp cx, 0
	je .cancel
	
.get_input:

	call wait_for_key
	
	cmp ah, 50h  ; Down pressed
	je .down_pressed
	
	cmp ah, 48h  ; Up pressed
	je .up_pressed
	
	cmp ah, 1Ch ; Enter pressed
	je .file_selected
	
	cmp ah, 1 		; Esc pressed
	je .cancel
	
	
	jmp .get_input
	
.down_pressed:
	
	cmp dh, [.num_of_files]
	je .get_input
	
	; Drawing white square to cover previous marker
	mov dl, 24 	
	mov dh, [.Ylocation]
	mov bl, 11110000b 	 ; Black text on white
	mov si, 12 		; We only need to fill the max string length
	xor ax, ax
	mov al, dh
	inc al
	mov di, ax
	call draw_blocks
	
	inc byte [.Ylocation]
	jmp .drawing
	
.up_pressed:

	cmp dh, 3
	je .get_input
	
	; Drawing white square to cover previous marker
	mov dl, 24 	
	mov dh, [.Ylocation]
	mov bl, 11110000b 	 ; Black text on white
	mov si, 12 		; We only need to fill the max string length
	xor ax, ax
	mov al, dh
	inc al
	mov di, ax
	call draw_blocks
	
	
	dec byte [.Ylocation]
	jmp .drawing
	
.file_selected:
	
	mov dl, 24
	mov dh, [.Ylocation]
	call move_cursor
	
	pop si	  		; Location to put the selected filename
	push si
	
.read_filename:

	mov ah, 8
	int 10h
	
	mov byte [si], al
	inc si
	mov dh, [.Ylocation]
	inc dl
	call move_cursor
	
	cmp al, 0
	je .done
	
	jmp .read_filename

.adjust_num_of_files:
	
	mov word [.num_of_files], 21
	add word [.num_of_files], 2 	; Now .num_of_files will contain the max Y position
	
	mov byte [.Xlocation], 24
	mov byte [.Ylocation], 3
	
	
	jmp .drawing
	

.done:
	
	pop si 	 		; Check if string name is equal to kernel name
	mov di, .kernel
	call compare_strings
	jc .kernel_file		; If so, print a message and don't continue 
	

	popa
	clc 
	ret 
	
.cancel:
	pop di
	popa
	stc
	ret
	
.kernel_file:
	
	pusha
	
	mov ax, .kernel_file_caption 	; First make the appropriate background
	call draw_background 	
	mov dl, 4 	; Drawing a red square
	mov dh, 6
	mov si, 72
	mov di, 9
	mov bh, 0
	mov bl, 01001111b	; White on red
	call draw_blocks 	
	mov dh, 7 	;Drawing a white line
	mov dl, 5
	mov si, 70
	mov di, 8
	mov bl, 11110100b  	; Red on white
	call draw_blocks
	
	mov dl, 23 		; Get ready to print string
	call move_cursor
	
	mov si, .kernel_file_message1 	; Printing message
	call print_string
	
	; Drawing white bar under red square
	mov dh, 9
	mov dl, 4
	mov si, 72
	mov di, 10
	mov bl, 11110100b 	; Red on white
	call draw_blocks
	mov dl, 37
	call move_cursor
	mov si, .kernel_file_message2
	call print_string
	
	call wait_for_key 	; Any other key being pressed will also cancel the crime that was about to occur
	
	popa
	popa
	stc
	ret
	
	
	.dir_flag db 0
	.Xlocation db 24
	.Ylocation db 3
	.num_of_files dw 0
	.rename_message1 db "Select file to rename: ", 0
	.rename_caption db "Rename", 0
	.kernel_file_caption db "The danger zone", 0
	.kernel_file_message1 db "Don't destroy the kernel please :(", 0
	.kernel_file_message2 db "Okay!!", 0
	.kernel db "KERNEL.BIN", 0
	.dir_name dw 0
	
	
	
; file_already_exists prints a message that informs user that the filename he chose already exists in the directory
; Input: None
; Output: None
file_already_exists:
	
	pusha
	; Printing error background
	mov ax, .error_message
	call draw_background
	
	; Red square
	mov dl, 21
	mov dh, 6
	mov si, 38
	mov di, 9
	mov bh, 0
	mov bl, 01001111b ; White on red
	call draw_blocks
	
	; White square
	mov dh, 7
	mov dl, 22
	mov si, 36
	mov di, 8
	mov bl, 11110100b 	; Red on white
	call draw_blocks
	
	; Print file exists message
	mov dl, 22
	call move_cursor
	mov si, .file_exists_message
	call print_string
	
	call wait_for_key 	; Wait for key
	
	popa
	ret
	
	.error_message 			 db "ERROR", 0
	.file_exists_message 	 db "Filename already exists, be original", 0
	
	
	
; choose_or_open just prints a message asking if user wants to open a directory or choose it
; Input: None 
; Output: None
choose_or_open:
	; Printing message that asks if user wants to open directory or choose it
	pusha
	mov ax, .move_caption
	call draw_background
	
	mov dl, 17
	mov dh, 5
	mov bl, 11110000b
	mov bh, 0
	mov si, 44
	mov di, 10
	call draw_blocks
	
	mov dl, 18
	mov si, 42
	mov bl, 01001111b
	mov dh, 6
	mov di, 9
	call draw_blocks
	
	mov si, .choose_dir_message1
	mov dl, 21
	mov dh, 6
	call move_cursor
	
	call print_string
	
	add dh, 2
	sub dl, 3
	call move_cursor
	
	mov si, .choose_dir_message2
	call print_string
	popa
	ret
	
	
	.choose_dir_message1     db "Do you want to choose this directory?", 0
	.choose_dir_message2     db "Press enter to choose or escape to open it", 0
	.move_caption 			 db "Move", 0
	
	
	
;================================
;DATA
;================================
	command_list1 db "Write file   Rename file  Delete file", 0 ; Size = 37 bytes/characters
	command_list2 db "Show files   Load a file  Create dir", 0
	command_list3 db "Move files   Copy files", 0
	message_files db "Select a file", 0
	cursor_ylocation dw 3
	cursor_xlocation dw 21
	max_cursor_pos equ 4
	min_cursor_pos equ 19

 