

;Function to print a string in si
;Input: SI = string, DL = row (x), DH = column (y), bl = color
;Output: String in SI to screen
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
	
	
;Function gets a string in SI and returns the length of the string in AX
;Input: SI = String
;Output: AX = Length	
string_length:
	pusha
	xor cx, cx
	
.repeat:

	lodsb				; Get char from string
	cmp al, 0
	je .done			; If char is zero, end of string
	
	inc cx

	jmp .repeat			; And move on to next char

.done:
	mov word [.tmp_counter], cx
	popa
	mov ax, [.tmp_counter]
	ret
	
	.tmp_counter dw 0
	

;Function takes a string in AX and makes it all uppercase
;Input: AX = String
;Output: AX = Uppercase string
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
	
;Function compares to strings
;Input: SI = first string, DI = second string
;Output: Carry set if strings are equal
compare_strings:
	pusha
.do:
	cmp [si], 0 ;If at least one string is finished, they're equal
	je .equal ;lol "jump equal equal"
	
	mov al, [si] ;Can't compare two memory addresses
	mov ah, [di]
	cmp al, ah 
	jne .not_equal ;If one char is not equal, nothing is
	inc si ;Next char
	inc di
	
	jmp .do
	
.equal: ;If equal, set carry flag and return
	popa
	stc
	ret

.not_equal:
	popa
	clc
	ret
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
