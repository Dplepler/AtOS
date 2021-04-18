

; wait_for_key waits for key press
; Input: Nothing
; Output: Key pressed in AX
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

