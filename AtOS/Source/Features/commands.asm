

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
	;je .delete_file
	
.write_file:
	
	cmp dh, 4 	; if DH = 4, show files
	je .show_files

	mov ax, .write_file_caption 	; First, we ask the user to name the file
	mov si, .write_file_message
	call command_box
	
	mov di, .new_filename 		; Then, we get the filename inputted into .new_filename
	call input_new_filename 	; Input filename
	jc .display_commands
	
	mov ax, .write_text_caption 	; Now, we ask the user to write some cool text!
	mov si, .write_text_message
	call text_box
	call show_cursor
	mov di, .text_string
	call input_new_string
	
	; Now we are going to make a new file
	mov bx, .text_string 	; BX = location of data to write
	mov ax, bx 
	call string_length 
	mov cx, ax 		; CX = amount of data to write (number of chars = number of bytes)
	
	mov ax, .new_filename 		; AX = filename

	call write_file
	jc .fail
	
	jmp .display_commands
	
	
.show_files:

	call hide_cursor 	; Don't display cursor
	
	mov ax, .files_caption 	; Printing text box with the correct caption
	mov si, .files_message
	call text_box
	call show_all_files 	; Get comma seperated string of all files
	
.waiting:

	call wait_for_key 	; Wait for key
	
	cmp ah, 1 	; If Esc pressed go back
	je .display_commands
	
	jmp .waiting 	; Otherwise, wait for a different key stroke
	
	
.rename_file:
	
	mov ax, .rename_caption 	; Printing text box with the correct caption
	mov si, .rename_message1
	call text_box
	call show_all_files 	; Get comma seperated string of all files
	mov di, .new_filename
	call move_marker
	
	
.fail:
	popa
	stc
	ret

.finish:
	popa
	clc
	ret
	
	
	
	
	.welcome_message db "AtOS, made from my suffering", 0
	.write_file_caption db "Write file", 0
	.write_text_caption db "Write text", 0
	.files_caption db "Files", 0
	.rename_caption db "Rename", 0
	.write_file_message db "Enter a new file name: ", 0
	.write_text_message db "Start writing: ", 0
	.files_message db "Files on this disk: ", 0
	.rename_message1 db "Select file to rename: ", 0
	.new_filename times 12 dw 0
	.text_string dw 0
	
	