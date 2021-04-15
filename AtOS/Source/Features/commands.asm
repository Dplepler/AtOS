
; Executes all basic commands uppon choice
choose_command:
	
	pusha
	
.display_commands:
	
	call read_rootdir 		; Starting point in directories
	
	mov word [.first_cluster], 0
	mov word [.first_cluster_tmp], 0
	
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
	
	mov byte [.only_copy], 0
	
	cmp dh, 5
	je .move_files
	
	mov ax, .write_file_caption
	mov si, .write_file_message1
	call text_box
	
	mov bl, 1 				; Directory flag
	call show_all_files 	; Get comma seperated string of all directories
	
	cmp cx, 0 			; If directory is empty, we want to use it
	je .write_file_to_dir
	
	mov di, .directory
	call move_marker
	jc .write_to_root
	
	
	mov ax, .directory
	mov cx, disk_buffer
	call load_file

	mov ax, word [si]
	mov word [.first_cluster], ax 		; Now this variable will contain the first cluster of the current directory
	
	call choose_or_open 		; Asking if user wants to choose or open directory
	
	call wait_for_key 		; If user presses enter, we will choose the directory, any other key will show files inside it
	cmp ah, 1Ch
	je .write_file_to_dir

	
	jmp .write_file
	
.write_to_root:
	call read_rootdir
	
.write_file_to_dir:


	mov ax, .write_file_caption
	mov si, .write_file_message2
	call command_box
	
	mov di, .filename 		; Then, we get the filename input into .new_filename
	call input_new_filename 	; Input filename
	jc .display_commands

	mov ax, di 		; Now, make file FAT12 style
	call fatten_file
	call uppercase
	
	mov ax, .write_text_caption 	; Now, we ask the user to write some cool text!
	mov si, .write_text_message
	call text_box
	
	call show_cursor
	
	mov di, 32768			; Starting location
	mov si, 32768			; Starting location as well
	mov cl, 1 				; Page number
	call input_new_string
	
	; Now we are going to make a new file
	mov cx, bx 		; CX = amount of data to write (number of chars = number of bytes)
	mov bx, 32768 	; BX = location of data to write
	mov ax, .filename 		; AX = filename
	mov dl, 0

	
	mov si, .first_cluster
	call write_file
	
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
	
	cmp dh, 5 		; If DH = 5, copy file
	je .copy_file
	
	mov ax, .rename_caption 	; Printing text box with the correct caption
	mov si, .rename_message1
	call text_box
	
	mov bl, 0 				; Directory flag
	call show_all_files 	; Get comma seperated string of all files
	mov dl, 1
	cmp cx, 0
	je .file_to_rename_chosen
	xor dl, dl
	
	
	mov di, .filename
	call move_marker
	jc .display_commands
	
	mov ax, .filename
	mov di, disk_buffer
	call get_root_entry 	; Move DI to file
	
	mov dl, 0 				; Directory flag turned off
	test byte [di+11], 00010000b 	; Check if file is a directory
	jz .file_to_rename_chosen 		; If not, choose it
	
	call choose_or_open 		; Asking if user wants to choose or open directory
	
	mov dl, 1
	call wait_for_key 		; If user presses enter, we will choose the directory, any other key will open it
	cmp ah, 1Ch
	je .file_to_rename_chosen
	
	mov ax, .filename 		; If file is a directory we want to load it to disk buffer and loop this process
	mov cx, disk_buffer
	call load_file
	
	mov ax, word [si] 		; Get directory's first cluster
	mov word [.first_cluster], ax
	
	mov dh, 0
	jmp .rename_file
	
	
.file_to_rename_chosen:

	mov ax, .rename_caption
	mov si, .rename_message2
	call command_box
	
	cmp dl, 0
	jne .rename_dir
	mov di, .new_filename 		; Then, we get the filename inputted into .new_filename
	call input_new_filename 	; Input filename
	jc .display_commands
	
	mov ax, .filename
	mov bx, .new_filename
	mov dx, [.first_cluster]
	call rename_file
	
	jmp .display_commands
	
	
.rename_dir:
	
	mov di, .new_filename 		; Then, we get the filename inputted into .new_filename
	call input_new_dirname 		; Input filename
	jc .display_commands
	
	mov ax, .filename
	mov bx, .new_filename
	mov dx, [.first_cluster]
	call rename_file
	
	jmp .display_commands
	
	
	
.file_already_exists:
	
	call file_already_exists 		; Print message that informs user the file already exists
	jmp .display_commands 			; Go back
	
	
.delete_file:

	cmp dh, 4
	je .write_directory
	
	mov ax, .delete_caption 	; Printing text box with the correct caption
	mov si, .delete_message
	call text_box
	
	mov bl, 0 				; Directory flag
	call show_all_files 	; Get comma seperated string of all files
	cmp cx, 0
	je .dir_empty 	; If directory is empty, abort
	
	mov di, .filename
	call move_marker
	jc .display_commands
	
	mov ax, .filename
	mov di, disk_buffer
	call get_root_entry 	; Move DI to file
	
	test byte [di+11], 00010000b 	; Check if file is a directory
	jz .file_to_delete_chosen 		; If not, choose it
	
	call choose_or_open 		; Asking if user wants to choose or open directory
	
	call wait_for_key 		; If user presses enter, we will choose the directory, any other key will open it
	cmp ah, 1Ch
	je .file_to_delete_chosen
	
	mov ax, .filename 		; If file is a directory we want to load it to disk buffer and loop this process
	mov cx, disk_buffer
	call load_file
	
	mov ax, word [si] 		; Get directory's first cluster
	mov word [.first_cluster], ax
	
	mov dh, 0
	jmp .delete_file
	
.file_to_delete_chosen:
	
	mov ax, .filename
	mov bx, [.first_cluster]
	call delete_file
	
	jmp .display_commands
	
	
.load_a_file:
	
	mov ax, .load_caption 	; Printing text box with the correct caption
	mov si, .load_message
	call text_box
	
	mov bl, 0
	call show_all_files 	; Get comma seperated string of all files
	cmp cx, 0
	je .display_commands
	
	mov di, .filename
	call move_marker
	jc .display_commands
	
	mov ax, .filename
	mov di, disk_buffer
	call get_root_entry 	; Move DI to file
	
	
	test byte [di+11], 00010000b     ; Check if file is a directory
	jz .file_to_load_chosen          ; If not, choose it

	
	mov ax, .filename
	mov cx, disk_buffer
	call load_file
	
	mov ax, word [si]         ; Get directory's first cluster
    mov word [.first_cluster], ax
	
	jmp .load_a_file
	
.file_to_load_chosen:

	mov ax, .write_text_caption 	; Printing text box with the correct caption
	mov si, .filename
	call text_box

	mov ax, .filename
	mov cx, disk_buffer
	call load_file
	
	
	mov word [.file_size], bx
	
	mov si, disk_buffer 	; This is the location we loaded the file at 
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
	inc bl 				; Page number
	
	mov ax, si 		; Now we will see if we are done with loading file
	call string_length
	add cx, ax
	inc cx 	; Adding the 0 terminator
	
	add si, ax 		; Add next page
	inc si 			; Terminator
	
	cmp cx, [.file_size] 	; Checking..
	jae .edit 	; If above or equal we are done!
	
	
	jmp .loopy


.edit:


	mov si, disk_buffer
	mov cx, [.file_size]
	mov di, 32768
	
	rep movsb 			; Changing location of data from disk buffer to RAM
	
	mov si, di
	
	call show_cursor
	mov di, si 						; Location to load to
	mov si, 32768 					; Starting location of data, where we first started writing the text
	mov cx, bx 						; Starting page number
	call input_new_string
	mov ax, bx
	
	add word [.file_size], ax 	; Change file size after file edit

	
	mov ax, [.first_cluster] 		; Load parent directory
	call load_with_first_cluster

	
	mov ax, .filename 				; Deleting file we want to update
	mov bx, [.first_cluster]
	call delete_file
	
	mov ax, [.first_cluster] 		; Load parent directory
	call load_with_first_cluster
	
	mov bx, 32768
	mov ax, .filename 		; Filename
	mov cx, [.file_size] 	; File size
	mov si, .first_cluster 	; Parent directory's first cluster
	mov dl, 0				; Directory flag
	call write_file 		; Write file with above params

	jmp .display_commands
	
	
.write_directory:

	mov ax, .write_dir_caption
	mov si, .write_file_message1
	call text_box
	
	mov bl, 1 				; Directory flag
	call show_all_files 	; Get comma seperated string of all directories
	
	cmp cx, 0 			; If directory is empty, we want to use it
	je .write_dir_to_dir
	
	mov di, .directory
	call move_marker
	jc .write_dir_to_dir
	
	mov ax, .directory
	mov cx, disk_buffer
	call load_file
	
	mov ax, [.first_cluster]

	mov ax, word [si]
	mov word [.first_cluster], ax 		; Now this variable will contain the first cluster of the current directory
	
	call choose_or_open 		; Asking if user wants to choose or open directory
	
	call wait_for_key 		; If user presses enter, we will choose the directory, any other key will show files inside it
	cmp ah, 1Ch
	je .write_dir_to_dir

	
	jmp .write_directory
	
.write_dir_to_dir:

	mov ax, .write_dir_caption
	mov si, .write_dir_message1
	call command_box
	
	mov di, .filename 		; Then, we get the filename input into .new_filename
	call input_new_dirname 	; Input filename
	jc .display_commands

	mov ax, di 		; Now, make file FAT12 style
	call fatten_file
	call uppercase
	
	mov di, 32768 		; RAM
	mov cx, 1024 		; Two clusters
	mov al, 0
	
	rep stosb 			; Clean 1024 bytes in RAM to use as empty directory data
	
	mov ax, .filename
	mov bx, 32768
	mov si, .first_cluster
	mov cx, 1024
	mov dl, 1
	call write_file


	jmp .display_commands
	
	
.move_files:
	
	call read_rootdir

.choose_file_to_move:
	
	
	mov ax, .move_caption
	mov si, .move_message1
	
	call text_box
	mov bl, 0 				; Directory flag
	call show_all_files 	; Get comma seperated string of all files
	cmp cx, 0
	je .dir_empty 	; If directory is empty, abort
	
	
	mov di, .filename
	call move_marker
	jc .display_commands
	
	mov ax, .filename
	mov di, disk_buffer
	call get_root_entry 	; Move DI to file
	
	test byte [di+11], 00010000b 	; Check if file is a directory
	jz .file_to_move_chosen 		; If not, choose it
	
	call choose_or_open 		; Asking if user wants to choose or open directory
	
	call wait_for_key 		; If user presses enter, we will choose the directory, any other key will open it
	cmp ah, 1Ch
	je .file_to_move_chosen
	
	mov ax, .filename 		; If file is a directory we want to load it to disk buffer and loop this process
	mov cx, disk_buffer
	call load_file
	
	mov ax, word [si] 		; Get directory's first cluster
	mov word [.first_cluster_tmp], ax
	
	jmp .choose_file_to_move
	
.file_to_move_chosen:
	
	mov di, disk_buffer 	; Point DI at chosen file
	mov ax, .filename
	
	call get_root_entry
	
	mov si, di 					; Point SI at chosen file
	mov di, .entry 				; Point DI at an empty entry variable
	mov cx, 32 					; We want to copy the entire entry
	
	rep movsb 					; Copying from SI to DI

	
	mov ax, .filename 			; Delete file entry from previous location
	mov bx, [.first_cluster_tmp]
	call delete_file_from_dir
	
	call read_rootdir
	
	mov di, .directory
	mov word [di], 0 	; Reset name in case of pervious uses
	
	mov ax, .move_caption
	mov si, .move_message2
	call text_box
	
.dir_to_move_to:

	
	mov bl, 1 				; Directory flag
	call show_all_files 	; Get comma seperated string of all directories
	
	
	cmp cx, 0 			; If directory is empty, we want to use it
	je .find_free_entry
	
	mov di, .directory
	call move_marker
	jc .dir_is_root
	
	mov ax, .directory
	mov cx, disk_buffer
	call load_file

	mov ax, word [si]
	mov word [.first_cluster], ax 		; Now this variable will contain the first cluster of the current directory
	
	call choose_or_open 		; Asking if user wants to choose or open directory
	
	call wait_for_key 		; If user presses enter, we will choose the directory, any other key will show files inside it
	cmp ah, 1Ch
	je .find_free_entry

	
	jmp .dir_to_move_to
	
.dir_is_root:
	
	call read_rootdir
	
	
.find_free_entry:

	mov ax, .filename 				; Check if filename already exists
	mov di, disk_buffer
	call get_root_entry
	jnc .cancel_move 				; If it does, cancel operation


	mov di, disk_buffer 	; DI will point to the start of the directory
	mov cx, 32 				; 32 * 32 available disk space in directories
	
.loopy_find_free_entry:
	
	cmp byte [di], 0 		; Check for free entries in directory
	je .free_entry_found
	cmp byte [di], 0E5h 	; Deleted filename also counts
	je .free_entry_found
	
	add di, 32
	
	loop .loopy_find_free_entry
	jmp .finish
	
	
.cancel_move:

	call file_already_exists
	mov ax, [.first_cluster_tmp]
	mov word [.first_cluster], ax
	call load_with_first_cluster
	jmp .find_free_entry
	
	
.free_entry_found:
	
	mov si, .entry 		; SI will point at our entry
	
	mov cx, 32 			; Amount of bytes per entry
	
	rep movsb 		; Move 32 bytes from SI to DI, meaning we move the entry from our variable to the wanted directory
	
	mov ax, [.first_cluster] 		; First cluster of the directory our file is in now
	
	
	call update_directory 			; Update it with file contents

	jmp .display_commands
	
	
.dir_empty:
	; Printing message if user is trying to open an empty directory
	mov ax, .error_message
	call draw_background
	
	mov dl, 24
	mov dh, 7
	mov bl, 01001111b
	mov bh, 0
	mov si, 32
	mov di, 10
	call draw_blocks
	inc dl
	inc dh
	mov bl, 11110100b
	mov si, 30
	mov di, 9
	call draw_blocks
	call move_cursor
	mov si, .dir_empty_message
	call print_string
	
	call wait_for_key
	
	jmp .display_commands
	
	
.copy_file:

	call read_rootdir

.choose_file_to_copy:
	
	
	; After this, chosen file's directory will be located in the disk buffer
	mov ax, .copy_caption
	mov si, .copy_message
	call text_box
	
	mov bl, 0 				; Directory flag
	call show_all_files 	; Get comma seperated string of all files
	cmp cx, 0
	je .dir_empty 	; If directory is empty, abort
	
	mov di, .filename
	call move_marker
	jc .display_commands
	
	mov ax, .filename
	mov di, disk_buffer
	call get_root_entry 	; Move DI to file
	
	test byte [di+11], 00010000b 	; Check if file is a directory
	jz .file_to_copy_chosen 		; If not, choose it
	
	call choose_or_open 		; Asking if user wants to choose or open directory
	
	
	call wait_for_key 		; If user presses enter, we will choose the directory, any other key will open it
	mov dl, 1 	 			; If we chose a file and it's a directory, pass turned on directory flag in write_file call
	cmp ah, 1Ch
	je .file_to_copy_chosen
	
	mov dl, 0 				; If we didn't choose the directory, reset flag
	
	mov ax, .filename 		; If file is a directory we want to load it to disk buffer and loop this process
	mov cx, disk_buffer
	call load_file
	
	mov ax, word [si] 		; Get directory's first cluster
	mov word [.first_cluster_tmp], ax
	
	jmp .choose_file_to_copy
	
.file_to_copy_chosen:

	mov ax, .copy_caption
	mov si, .move_message2
	call text_box
	
	call read_rootdir
	
.dir_to_copy_to:
	
	mov bl, 1 				; Directory flag
	call show_all_files 	; Get comma seperated string of all directories
	
	cmp cx, 0 			; If directory is empty, we want to use it
	je .dir_to_copy_chosen
	
	mov di, .directory
	call move_marker
	jc .copy_to_root
	
	mov ax, .directory
	mov cx, disk_buffer
	call load_file
	
	mov ax, word [si]
	mov word [.first_cluster], ax 		; Now this variable will contain the first cluster of the current directory
	
	call choose_or_open 		; Asking if user wants to choose or open directory
	
	call wait_for_key 		; If user presses enter, we will choose the directory, any other key will show files inside it
	cmp ah, 1Ch
	je .dir_to_copy_chosen
	
	jmp .dir_to_copy_to
	
	
.copy_to_root:

	mov word [.first_cluster], 0
	call read_rootdir
	
.dir_to_copy_chosen:

	mov ax, [.first_cluster_tmp]
	call load_with_first_cluster
	
	mov ax, .filename
	mov cx, disk_buffer
	call load_file
	
	mov cx, bx
	mov si, disk_buffer
	mov di, 32768
	
	rep movsb
	
	
	mov ax, .filename
	mov cx, bx 			; move file size to CX register
	mov bx, 32768 		; File contents
	mov si, .first_cluster 	; First cluster of parent directory
	mov dl, 0				
	call write_file

	jmp .display_commands
	
	
.finish:
	popa
	clc
	ret
	
	
	.only_copy 				 db 0
	.error_message 			 db "ERROR", 0
	.welcome_message 		 db "AtOS, made from my suffering", 0
	.write_file_caption 	 db "Write file", 0
	.write_dir_caption		 db "Write directory", 0
	.write_text_caption 	 db "Write text", 0
	.files_caption 		 	 db "Files", 0
	.rename_caption 		 db "Rename", 0
	.delete_caption 		 db "Delete", 0
	.load_caption 			 db "Load", 0
	.move_caption 			 db "Move", 0
	.copy_caption 			 db "Copy", 0
	.write_file_message1 	 db "Choose a directory", 0
	.write_file_message2 	 db "Enter new file name:", 0
	.write_dir_message1 	 db "Enter new directory name: ", 0
	.write_text_message 	 db "Start writing:", 0
	.files_message 			 db "Files on this disk:", 0
	.rename_message1 		 db "Select file to rename:", 0
	.rename_message2 		 db "Enter a new name:", 0
	.delete_message 		 db "Choose file to extarminate:", 0
	.load_message 			 db "Select file to load:", 0
	.move_message1 			 db "Select file to move:", 0
	.move_message2 			 db "Select directory to move to:", 0
	.copy_message 			 db "Select file to copy", 0
	.file_exists_message 	 db "Filename already exists, be original", 0
	.dir_empty_message 		 db "Directory is empty, how sad :(", 0
	.entry times 32 		 dw 0
	.new_filename times 13 	 dw 0
	.filename times 13 		 dw 0
	.directory times 13 	 dw 0
	.first_cluster 			 dw 0
	.first_cluster_tmp 		 dw 0
	.tmp_index 				 dw 0
	.text_length		 	 dw 0
	.file_size 				 dw 0
	
	