
; Executes all basic commands uppon choice
choose_command:
	
	pusha
.display_commands:
	
	mov ax, .welcome_message  	 ; Message to print at top of the screen
	call draw_background
	call commands_dialog 	 ; Show list of commands to choose
	
.command_selected:
	cmp dl, 21
	je .write_file
	
	cmp dl, 34
	je .rename_file
	
	cmp dl, 47
	je .delete_file
	
.write_file:
	
	cmp dh, 4 	; if DH = 4, show files
	je .show_files
	
	;mov ax, .write_file_caption 	; First, we ask the user to name the file
	;mov si, .write_file_message1
	;call text_box
	;mov bl, 1
	;call show_all_files
	;mov di, .filename
	;call move_marker
	
	mov ax, .write_file_caption
	mov si, .write_file_message2
	call command_box
	
	mov di, .new_filename 		; Then, we get the filename input into .new_filename
	call input_new_filename 	; Input filename
	jc .display_commands

	mov ax, di 		; Now, make file FAT12 style
	call fatten_file
	call uppercase

	call read_rootdir 	; Point DI to root directory in disk buffer
	mov di, disk_buffer
	
	call get_root_entry 	; And check if new filename already exists
	jnc .file_already_exists 	; If it does, print an error and leave this function
	
	mov ax, .write_text_caption 	; Now, we ask the user to write some cool text!
	mov si, .write_text_message
	call text_box
	
	call show_cursor
	
	mov di, .text_string
	mov si, .text_string
	mov cl, 1
	call input_new_string
	
	; Now we are going to make a new file
	mov cx, bx 		; CX = amount of data to write (number of chars = number of bytes)
	mov bx, .text_string 	; BX = location of data to write
	mov ax, .new_filename 		; AX = filename
	mov dl, 0
	call write_file
	jc .finish
	
	jmp .display_commands
	
	
.show_files:

	call hide_cursor 	; Don't display cursor
	
	mov ax, .files_caption 	; Printing text box with the correct caption
	mov si, .files_message
	call text_box
	mov bl, 0
	call show_all_files 	; Get comma seperated string of all files
	
.waiting:

	call wait_for_key 	; Wait for key
	
	cmp ah, 1 	; If Esc pressed go back
	je .display_commands
	
	jmp .waiting 	; Otherwise, wait for a different key stroke
	
	
.rename_file:

	cmp dh, 4 		; If DH = 4, load file
	je .load_a_file
	
	mov ax, .rename_caption 	; Printing text box with the correct caption
	mov si, .rename_message1
	call text_box
	mov bl, 0
	call show_all_files 	; Get comma seperated string of all files
	mov di, .filename
	call move_marker
	jc .display_commands
	
	mov ax, .rename_caption
	mov si, .rename_message2
	call command_box
	
	mov di, .new_filename 		; Then, we get the filename inputted into .new_filename
	call input_new_filename 	; Input filename
	jc .display_commands
	
	mov ax, di 		; Now, make file FAT12 style
	call fatten_file
	call uppercase

	call read_rootdir 	; Point DI to root directory in disk buffer
	mov di, disk_buffer
	
	call get_root_entry 	; And check if new filename already exists
	jnc .file_already_exists 	; If it does, print an error and leave this function alone
	
	
	mov ax, .filename
	mov bx, .new_filename
	call rename_file
	jmp .display_commands
	
.file_already_exists:
	
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
	jmp .display_commands
	
	
.delete_file:

	cmp dh, 4
	;je .write_directory
	
	mov ax, .delete_caption
	mov si, .delete_message
	call text_box
	mov bl, 0 	; Directory flag
	call show_all_files 	; Get comma seperated string of all files
	mov di, .filename
	call move_marker
	jc .display_commands
	
	mov ax, di
	call delete_file
	
	jmp .display_commands
	
.load_a_file:
	
	mov ax, .load_caption 	; Printing text box with the correct caption
	mov si, .load_message
	call text_box
	
	mov bl, 0
	call show_all_files 	; Get comma seperated string of all files
	mov di, .filename
	call move_marker
	jc .display_commands
	
	mov ax, .filename 	; Filename
	mov cx, 32768 	; Location to load file at
	call load_file
	mov word [.file_size], bx

	mov ax, .load_caption
	mov si, .filename
	call text_box
	
	mov si, 32768 	; This is the location we loaded the file at 
	xor cx, cx
	xor bx, bx

.loopy:

	pusha
	; Drawing white square inside the red square
	mov dl, 24 	
	mov dh, 3
	mov bl, 11110000b 	 ; Black text on white
	mov si, 32
	mov di, 24
	call draw_blocks
	
	call move_cursor
	popa
	
	
	call write_page 	; Writing page
	inc bl
	
	mov ax, si 		; Now we will see if we are done with loading file
	call string_length
	add cx, ax
	inc cx 	; Adding the 0 terminator
	
	add si, ax 		; Otherwise, move on to the next page
	inc si 			; Terminator
	
	cmp cx, [.file_size] 	; Checking..
	jae .edit 	; If above or equal we are done!
	
	
	jmp .loopy


.edit:

	dec si

	mov ax, .filename
	call delete_file
	
	call show_cursor
	mov di, si 		; Location to load to
	mov si, 32768 	; Starting location of data
	mov cx, bx 			; Starting page number
	call input_new_string
	mov ax, bx
	
	add word [.file_size], ax 	; Change file size after file edit

	
	mov bx, 32768
	mov ax, .filename
	mov cx, [.file_size]
	
	call write_file
	

	jmp .display_commands
	
	
.write_directory:

	mov ax, .write_file_caption 	; First, we ask the user to name the directory
	mov si, .write_file_message2
	call command_box
	
	mov di, .new_filename 		; Then, we get the filename input into .new_filename
	call input_new_dirname 	; Input directory name
	jc .display_commands

	mov ax, di 		; Now, make file FAT12 style
	call fatten_dir
	call uppercase

	call read_rootdir 	; Point DI to root directory in disk buffer
	mov di, disk_buffer
	
	call get_root_entry 	; And check if new filename already exists
	jnc .file_already_exists 	; If it does, print an error and leave this function
	
	mov word [.file_size], 0
	
	mov cx, 2
	
	mov bx, .file_size
	
	mov dl, 1 	; Turn on directory flag
	call write_file
	
	jmp .display_commands
	

.finish:
	popa
	clc
	ret
	
	
	
	.error_message 			db "ERROR", 0
	.welcome_message 		db "AtOS, made from my suffering", 0
	.write_file_caption 	db "Write file", 0
	.write_text_caption 	db "Write text", 0
	.files_caption 			db "Files", 0
	.rename_caption 		db "Rename", 0
	.delete_caption 		db "Delete", 0
	.load_caption 			db "Load", 0
	.write_file_message1 	db "Choose a directory", 0
	.write_file_message2 	db "Enter a new file name: ", 0
	.write_text_message 	db "Start writing: ", 0
	.files_message 			db "Files on this disk: ", 0
	.rename_message1 		db "Select file to rename: ", 0
	.rename_message2 		db "Enter a new name: ", 0
	.delete_message 		db "Choose file to extarminate: ", 0
	.load_message 			db "Select file to load: ", 0
	.file_exists_message 	db "Filename already exists, be original", 0
	.new_filename times 13 	dw 0
	.filename times 13 		dw 0
	.text_length		 	dw 0
	.file_size 				dw 0
	.text_string 			dw 0
	
	