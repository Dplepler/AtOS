

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
	