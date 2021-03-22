

;Function waits for key press
;Input: Nothing
;Output: Key pressed in AX
wait_for_key:

	mov ah, 11h
	int 16h

	jnz .key_pressed

	hlt
	jmp wait_for_key

.key_pressed:
	mov ah, 10h
	int 16h

	ret

wait_key_ascii:

	pusha
	
.searching_for_key:
	xor ax, ax
	mov ah, 1 	 ; Check for key
	int 16h
	jz .searching_for_key
	
	xor ax, ax ; If key pressed, get it from buffer
	int 16h
	
	mov [.tmp_char], ax
	popa
	mov ax, [.tmp_char]
	ret
	
	.tmp_char dw 0