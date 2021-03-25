
; The string file contains all simple string operations


; print_string to print a string in si
; Input: SI = string, bl = color
; Output: String in SI to screen
print_string:
	pusha

	mov ah, 0Eh			; int 10h teletype function

.repeat:
	lodsb				; Get char from string
	cmp al, 0
	je .done			; If char is zero, end of string

	int 10h				; Otherwise, print it
	jmp .repeat			; And move on to next char

.done:
	popa
	ret
	
	

; uppercase takes a string in AX and makes it all uppercase
; Input: AX = String
; Output: AX = Uppercase string
uppercase:

	pusha
	
	mov si, ax
	
.change_chars:

	cmp byte [si], 0 ;0 is the end of the string
	je .done
	
	cmp byte [si], 'a' ;If char is not a lower-case string, don't change it
	jb .dont_change
	cmp byte [si], 'z'
	ja .dont_change
	
	sub byte [si], 32
	
	inc si
	
	jmp .change_chars
	
.dont_change:
	inc si
	jmp .change_chars

.done:
	popa
	ret
	
; compare_strings compares two strings
; Input: SI = first string, DI = second string
; Output: Carry set if strings are equal
compare_strings:
	pusha
.do:
	cmp byte [si], 0 ; If at least one string is finished, they're equal
	je .equal ; lol "jump equal equal"
	
	mov al, [si] ; Can't compare two memory addresses
	mov ah, [di]
	cmp al, ah 
	jne .not_equal ; If one char is not equal, nothing is
	inc si ; Next char
	inc di
	
	jmp .do
	
.equal: ; If equal, set carry flag and return
	popa
	stc
	ret

.not_equal:
	popa
	clc
	ret
	
; string_length gets a string in AX and returns the length in AX
; Input: AX = string
; Output: AX = length
string_length:
	pusha
	
	mov si, ax
	xor cx, cx
	
.repeat:
	
	lodsb
	
	cmp al, 0
	je .finish
	
	inc cx
	
	jmp .repeat
	
.finish:
	
	mov [.tmp_size], cx
	popa
	
	mov ax, [.tmp_size]
	
	ret
	
	.tmp_size dw 0
	
; input_new_filename will ask the user to write a filename
; Input: DI = string to overwrite with a new filename
; Output: None
input_new_filename:

	pusha
	mov cx, 1 	 	; Char counter
	
.start:

	call wait_for_key 	; Char input
	
	cmp ah, 1
	je .cancel
	
	cmp al, '.' 	; If user finished name earlier than expected
	je .extention
	
	cmp al, 8 	; If user pressed backspace
	je .backspace
	
	cmp al, 1Fh 	; Anything below and including 1F is not a valid filename character
	jbe .start
	
	mov byte [di], al 	; Add filename char to string
	inc di 		; Move to the next one
	mov ah, 0Eh			; int 10h teletype function
	int 10h
	
	
	inc cx 		; Counter
	cmp cx, 8  		; Name without extention finished
	ja .extention	
	
	jmp .start

	
.backspace:
	
	call get_cursor_pos
	cmp dl, 21 	; If no characters were printed yet
	je .start
	mov ah, 0Eh			; int 10h teletype function
	int 10h 	; Moving cursor backwards
	mov al, 20h 	; Deleting printed char
	int 10h
	mov al, 8 	; Going backwards again
	int 10h
	
	dec di 		; Overwrite last input char later
	
	dec cx 		; Counter
	
	jmp .start
	
.extention:

	mov ah, 0Eh 	; Print the extention dot
	mov al, '.'
	int 10h
	
	mov byte [di], al 		; Add . to string
	inc di 		; Next byte..
	
	mov cx, 3 	; Ready to write an extention
	
.three_letters:

	call wait_for_key
	
	cmp ah, 1
	je .cancel
	
	cmp al, 1Fh
	jbe .three_letters
	
	cmp al, '.'
	je .three_letters
	
	mov byte [di], al
	inc di
	
	mov ah, 0Eh
	int 10h
	
	loop .three_letters
	
	mov byte [di], 0 	; Adding a string terminator

	popa
	clc
	ret
	
.cancel:
	popa
	stc
	ret
	

; input_new_string will save the text written in the text box
; Input: DI = Location of string
; Output: None
input_new_string:

	pusha
	mov [.string], di
	
.start:

	call wait_for_key 	; Char input
	
	cmp al, 8 	; If user pressed backspace
	je .backspace
	
	cmp al, 0Dh 	; If enter pressed, new line
	je .enter
	
	call get_cursor_pos
	cmp dl, 55 		; If we just got back from deleting a new line
	je .remember_char 	; We want to go to a new line but also remember our last input char and print it
	
	cmp ah, 3Fh 	; If F5 pressed, finish (3F = F5)
	je .finish
	
	cmp al, 1Fh 	; Anything below and including 1F is not a valid string character
	jbe .start
	
	cmp al, 7Eh 	; Anything above and including 7E is not a valid string character
	jae .start 
	
	mov ah, 0Eh			; int 10h teletype function
	int 10h 			; Display char on screen	
	
	mov byte [di], al 	; Add char to string
	inc di 		; Move to the next one
	
	inc dl
	cmp dl, 55 		; End of line
	jae .enter
	
	jmp .start
	
.remember_char:
	mov [.tmp_char], al
	mov byte [.rem_char], 1
	
	
.enter:
	
	call get_cursor_pos
	cmp dh, 23 	; End of page?
	je .new_page
	
	mov al, 0Ah 	; New line

	mov byte [di], al  	; New line
	inc di
	
	mov ah, 0Eh			; int 10h teletype function
	int 10h
	
	mov dl, 24
	inc dh
	call move_cursor
	
	cmp byte [.rem_char], 1
	je .print_char
	
	jmp .start
	
.new_page:

	inc byte [.page_num]
	
	mov ax, .write_text_caption
	mov si, .write_text_message
	call text_box
	
	mov byte [di], 0 	; End of first page 
	inc di
	
	jmp .start
	

.print_char:

	mov al, [.tmp_char] 	; Sometimes we want to print a character after making a new line
	int 10h
	
	mov byte [.rem_char], 0
	
	mov byte [di], al
	inc di

	jmp .start

.delete_enter:

	call get_cursor_pos
	cmp dh, 3 	; If we haven't written anything yet
	je .scroll_up 	; Go up a page
	
	dec dh 		; Go up one line
	mov dl, 56
	mov bh, 0
	
; We will go back until character is hit on the above row
.go_back:

	dec dl
	call move_cursor 	 
	mov ah, 8 	; Check if there is a character or space 
	int 10h 	; AH = 8, int 10h will read character
	
	cmp dl, 23
	je .skip
	
	cmp al, 32 	; If space..
	je .go_back 	; Go back
	
.skip:
	
	inc dl
	call move_cursor
	
	dec di 	; Overwrite new-line key
	
	jmp .start
	
.scroll_up:
	
	cmp byte [.page_num], 1 	; Skip if we're at the first page
	je .start
	
	dec byte [.page_num]
	mov word si, [.string]
	
	cmp byte [.page_num], 1 	; Skip if we're at the first page
	je .first_page
	
	mov cx, 1 	; 0 terminator counter

.find_page_start:
	inc si
	cmp byte [si], 0
	je .check_start
	
	jmp .find_page_start
	
.check_start:
	inc cx
	cmp byte cl, [.page_num]
	je .found_start
	
	jmp .find_page_start

.first_page:
	dec si
	
.found_start:
	inc si
	
	call write_page
	jmp .start
	
.backspace:
	
	call get_cursor_pos
	cmp dl, 24 	; If no characters were printed yet
	je .delete_enter
	
	mov ah, 0Eh			; int 10h teletype function
	int 10h 	; Moving cursor backwards
	mov al, 20h 	; Deleting printed char
	int 10h
	mov al, 8 	; Going backwards again
	int 10h

	dec di 		; Overwrite last input char later
	
	jmp .start

.finish:
	mov byte [di], 0 	; Zero is the string terminator
	
	popa
	ret
	
	.tmp_char db 0
	.rem_char db 0
	.page_num db 1
	.counter db 0
	.write_text_caption db "Write text", 0
	.write_text_message db "Continue writing: ", 0
	.string dw 0

; Function prints a written page with a given SI page string location
; Input: SI = Start of string
; Output: None
write_page:
	
	pusha
	
	mov dl, 24
	mov dh, 3
	call move_cursor
	
.loopy:

	inc dl
	cmp dl, 56
	je .enter
	
	mov ah, 0Eh
	lodsb
	
	cmp al, 0Ah
	je .enter
	
	cmp al, 0
	je .done
	
	int 10h
	jmp .loopy
	
.enter:
	inc dh
	mov dl, 24
	call move_cursor
	jmp .loopy
	
.done:
	popa
	ret
	
; show_all_files prints all files on the disk into a text box
; Input: None
; Output: CX = number of files
show_all_files:
	
	pusha
	
	xor cx, cx

	mov dh, 3 	; Starting position
	mov dl, 24
	call move_cursor
	
	mov ax, .all_files 	; Get all files
	call get_file_list
	
	mov si, ax
	
	mov bh, 0 	; Page number
	
.loopy:
	lodsb
	mov ah, 0Eh 	; Teletype
	cmp al, ','
	je .enter
	cmp al, 0
	je .done
	int 10h
	jmp .loopy
	
.enter:
	
	mov ah, 0Eh
	mov al, 0Ah 	; New line
	int 10h
	
	inc dh
	mov dl, 24
	call move_cursor
	
	inc cx
	
	jmp .loopy
	
.done:
	mov word [.tmp], cx
	popa
	mov cx, [.tmp]
	ret
	
	.tmp dw 0
	.all_files times 1024 db 0
	
	
	
	
	
	
