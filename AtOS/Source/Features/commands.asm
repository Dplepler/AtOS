

choose_command:
	
	pusha
	
	mov ax, welcome_message  	 ; Message to print at top of the screen
	call draw_background
	
	call commands_dialog 	 ; Show list of commands to choose
	
.command_selected:
	cmp dl, 21
	je .write_file
	
	cmp dl, 35
	;je .rename_file
	
	cmp dl, 49
	;je .delete_file
	
.write_file:

	mov ax, .write_file_caption
	mov si, .write_file_message
	call command_box
	
	mov cx, 1 	 	; Char counter
	mov di, .new_filename
	
.input_new_filename:

	call wait_for_key
	
	cmp al, '.'
	je .extention
	
	cmp al, 8
	je .backspace
	
	cmp al, 1Fh
	jbe .input_new_filename
	
	mov ah, 0Eh			; int 10h teletype function
	int 10h
	
	inc cx
	cmp cx, 8  	; Name without extention finished
	ja .extention	
	
	jmp .input_new_filename

	
.backspace:
	
	call get_cursor_pos
	cmp dl, 21 	; If no characters were printed yet
	je .input_new_filename
	mov ah, 0Eh			; int 10h teletype function
	int 10h 	; Moving cursor backwards
	mov al, 20h 	; Deleting printed char
	int 10h
	mov al, 8 	; Going backwards again
	int 10h
	
	dec cx
	
	jmp .input_new_filename
	
.extention:

	mov ah, 0Eh
	mov al, '.'
	int 10h
	
	mov cx, 3
	
.three_letters:

	call wait_for_key
	
	cmp al, 1Fh
	jbe .three_letters
	
	cmp al, '.'
	je .three_letters
	
	mov ah, 0Eh
	int 10h
	
	loop .three_letters

	popa
	ret

	
	.write_file_caption db "Write file", 0
	.write_file_message db "Enter a new file name: ", 0
	.new_filename dw 0
	
	
	
	
	
	
	
	
	
welcome_message db "AtOS, made from my suffering", 0