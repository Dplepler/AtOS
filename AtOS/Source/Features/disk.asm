

;Function reads the root directory from the disk to disk buffer
;Input: Nothing
;Output: Carry flag if function failed
read_rootdir:
	pusha
	
	mov ax, 19 ;Read from sector 19 (root directory)
	call disk_convert_l2hts
	
	mov bx, disk_buffer ;ES:BX will point to disk_buffer
	mov ax, ds
	mov es, ax
	
	mov ah, 2 ;Param to read
	mov al, 14 ;Read 14 sectors 
	
	pusha ;Save registers, enter loop
	
.read_dir:
	popa
	pusha

	int 13h
	jnc .done ;If no carry, everything worked
	call disk_reset_floppy ;If something went wrong, try reset disk
	jnc .read_dir ;Try again if reset went okay
	popa ;Didn't work? bring back the registers and abort
	jmp .fail
	
	
.done: ;Clear carry flag and pop registers to the beginning of system call
	clc
	popa
	popa
	ret

.fail: ;Turn on carry flag if function failed, bring back registers from the beginning of the system call and return
	stc
	popa
	ret
	
;Function reads the FAT from the disk to disk buffer
;Input: Nothing
;Output: Carry flag if function failed
read_fat:
	
	pusha
	
	
	mov ax, 1 ;The fat table starts after the bootloader, at sector 1
	call disk_convert_l2hts 
	
	mov bx, disk_buffer
	mov ax, ds
	mov es, ax
	
	mov ah, 2 ;Param for BIOS to read sectors
	mov al, 9
	
	int 13h
	jc .failure ;If there's an error, carry flag will turn on and we will return it
	
	popa
	clc ;Otherwise, clear carry
	ret

.failure:
	popa
	stc
	ret


;Function writes the root directory from the disk buffer to the disk
;Input: Nothing
;Output: Carry flag if function failed
write_rootdir:

	pusha
	
	mov ax, 19 ;The root directory starts at sector 19
	call disk_convert_l2hts
	
	mov bx, disk_buffer ;ES:BX now points at 8K buffer
	mov ax, ds
	mov es, ax
	
	mov ah, 3 ;Param for BIOS to write sectors
	mov al, 14 ;Writing 14 sectors (root directory takes the place of sectors 19-32)
	
	int 13h ;Interupt
	jc .failure ;If there's an error, carry flag will turn on and we will return it
	
	popa
	clc ;Otherwise, clear carry
	ret

.failure:
	popa
	stc
	ret

;Function writes the first FAT from the disk buffer to the disk
;Input: Nothing
;Output: Carry flag if function failed
write_fat:
	pusha
	
	mov ax, 1 ;The fat table starts after the bootloader, at sector 1
	call disk_convert_l2hts 
	
	mov bx, disk_buffer
	mov ax, ds
	mov es, ax
	
	mov ah, 3 ;Param for BIOS to write sectors
	mov al, 9
	
	int 13h
	jc .failure ;If there's an error, carry flag will turn on and we will return it
	
	popa
	clc ;Otherwise, clear carry
	ret

.failure:
	popa
	stc
	ret
	
;Make a filename fat12 style - remove dot and add spaces so the file will be 11 bytes long
;Input: SI = filename string
;Output: AX = location of string
fatten_file:
	pusha
	
	call string_length
	
	cmp ax, 13 ;If filename is larger or equal to 13 bytes, it is a bad filename
	jge .fail
	
	cmp ax, 0 ;If filename is 0, it is also a bad filename
	je .fail
	
	mov di, .fat_string ;Get location of new string
	
	xor cx, cx
	
.loopy:

	lodsb 
	cmp al, '.'
	je .add_space
	stosb
	inc cx
	cmp cx, 8
	jg .fail ;If filename does not have a dot after 8 bytes it's a bad filename
	jmp .loopy
	
.add_space:
	cmp cx, 8
	je .extention
	mov byte [di], ' '
	inc di
	inc cx
	jmp .add_space
	
.extention:
	mov cx, 3
.extention_loop: ;Adding file extention
	lodsb
	stosb
	loop .extention_loop
	mov byte [di], 0 
	
	popa
	clc
	
	
	mov ax, .fat_string
	
	ret

.fail:
	
	popa
	stc
	
	
	mov ax, .fat_string
	ret
	
	
	.fat_string times 12 db 0
	
	
	
get_file_list:
	pusha

	mov word [.file_list_tmp], ax

	mov eax, 0			; Needed for some older BIOSes

	call disk_reset_floppy		; Just in case disk was changed

	mov ax, 19			; Root dir starts at logical sector 19
	call disk_convert_l2hts

	mov si, disk_buffer		; ES:BX should point to our buffer
	mov bx, si

	mov ah, 2			; Params for int 13h: read floppy sectors
	mov al, 14			; And read 14 of them

	pusha				; Prepare to enter loop


.read_root_dir:
	popa
	pusha

	stc
	int 13h				; Read sectors
	call disk_reset_floppy		; Check we've read them OK
	jnc .show_dir_init		; No errors, continue

	call disk_reset_floppy		; Error = reset controller and try again
	jnc .read_root_dir
	jmp .done			; Double error, exit 'dir' routine

.show_dir_init:
	popa

	mov ax, 0
	mov si, disk_buffer		; Data reader from start of filenames

	mov word di, [.file_list_tmp]	; Name destination buffer


.start_entry:
	mov al, [si+11]			; File attributes for entry
	cmp al, 0Fh			; Windows marker, skip it
	je .skip

	test al, 18h			; Is this a directory entry or volume label?
	jnz .skip			; Yes, ignore it

	mov al, [si]
	cmp al, 229			; If we read 229 = deleted filename
	je .skip

	cmp al, 0			; 1st byte = entry never used
	je .done


	mov cx, 1			; Set char counter
	mov dx, si			; Beginning of possible entry

.testdirentry:
	inc si
	mov al, [si]			; Test for most unusable characters
	cmp al, ' '			; Windows sometimes puts 0 (UTF-8) or 0FFh
	jl .nxtdirentry
	cmp al, '~'
	ja .nxtdirentry

	inc cx
	cmp cx, 11			; Done 11 char filename?
	je .gotfilename
	jmp .testdirentry


.gotfilename:				; Got a filename that passes testing
	mov si, dx			; DX = where getting string

	mov cx, 0
.loopy:
	mov byte al, [si]
	cmp al, ' '
	je .ignore_space
	mov byte [di], al
	inc si
	inc di
	inc cx
	cmp cx, 8
	je .add_dot
	cmp cx, 11
	je .done_copy
	jmp .loopy

.ignore_space:
	inc si
	inc cx
	cmp cx, 8
	je .add_dot
	jmp .loopy

.add_dot:
	mov byte [di], '.'
	inc di
	jmp .loopy

.done_copy:
	mov byte [di], ','		; Use comma to separate filenames
	inc di

.nxtdirentry:
	mov si, dx			; Start of entry, pretend to skip to next

.skip:
	add si, 32			; Shift to next 32 bytes (next filename)
	jmp .start_entry


.done:
	dec di
	mov byte [di], 0		; Zero-terminate string (gets rid of final comma)

	popa
	ret


	.file_list_tmp		dw 0
	

;Input: AX = string
;Output: BX = file size
load_file:
	
	pusha
	
	call uppercase
	call fatten_file
	
	mov [.filename], ax
	mov [.load_loc], cx
	
	
	call read_rootdir
	
.search:

	pusha
	
	mov cx, 1
	mov di, disk_buffer
	mov bx, -32
	
.next:
	cmp cx, 224
	je .error
	
	inc cx
	
	add bx, 32
	add di, bx
	mov al, [di]
	
	cmp al, 0
	je .error
	
	cmp al, 0E5h ;0xE5 means file was deleted
	je .next
	
	test byte [di+11], 00011000b ;If this is a volume label or sub directory skip to the next entry
	jnz .next
	
	mov byte [di+11], 0 ;Adding a terminator so name will be comparable
	mov ax, di
	call uppercase
	
	mov si, [.filename]
	
	call compare_strings
	jnc .next ;If strings aren't equal, search the next entry

.error:

	xor dx, dx ;Moving cursor to (0, 0)
	call move_cursor
	
	mov si, [.file_not_found] ;Print proper message
	call print_string
	
	popa 
	
	mov bx, 0 ;Return file size = 0
	stc
	ret


.found_file_to_load:			; Now fetch cluster and load FAT into RAM
	mov ax, [di+28]			; Store file size to return to calling routine
	mov word [.file_size], ax

	cmp ax, 0			; If the file size is zero, don't bother trying
	je .end				; to read more clusters

	mov ax, [di+26]			; Now fetch cluster and load FAT into RAM
	mov word [.cluster], ax

	mov ax, 1			; Sector 1 = first sector of first FAT
	call disk_convert_l2hts

	mov di, disk_buffer		; ES:BX points to our buffer
	mov bx, di

	mov ah, 2			; int 13h params: read sectors
	mov al, 9			; And read 9 of them

	pusha

.read_fat:
	popa				; In case registers altered by int 13h
	pusha

	stc
	int 13h
	jnc .read_fat_ok

	call disk_reset_floppy
	jnc .read_fat

	popa
	jmp .root_problem


.read_fat_ok:
	popa


.load_file_sector:
	mov ax, word [.cluster]		; Convert sector to logical
	add ax, 31

	call disk_convert_l2hts		; Make appropriate params for int 13h

	mov bx, [.load_position]


	mov ah, 02			; AH = read sectors, AL = just read 1
	mov al, 01

	stc
	int 13h
	jnc .calculate_next_cluster	; If there's no error...

	call disk_reset_floppy		; Otherwise, reset floppy and retry
	jnc .load_file_sector

	mov ax, .err_msg_floppy_reset	; Reset failed, bail out
	jmp os_fatal_error


.calculate_next_cluster:
	mov ax, [.cluster]
	mov bx, 3
	mul bx
	mov bx, 2
	div bx				; DX = [CLUSTER] mod 2
	mov si, disk_buffer		; AX = word in FAT for the 12 bits
	add si, ax
	mov ax, word [ds:si]

	or dx, dx			; If DX = 0 [CLUSTER] = even, if DX = 1 then odd

	jz .even			; If [CLUSTER] = even, drop last 4 bits of word
					; with next cluster; if odd, drop first 4 bits

.odd:
	shr ax, 4			; Shift out first 4 bits (belong to another entry)
	jmp .calculate_cluster_cont	; Onto next sector!

.even:
	and ax, 0FFFh			; Mask out top (last) 4 bits

.calculate_cluster_cont:
	mov word [.cluster], ax		; Store cluster

	cmp ax, 0FF8h
	jae .end

	add word [.load_position], 512
	jmp .load_file_sector		; Onto next sector!


.end:
	mov bx, [.file_size]		; Get file size to pass back in BX
	clc				; Carry clear = good load
	ret

	.cluster	dw 0 		; Cluster of the file we want to load
	
	.file_not_found db "File not found :(", 0
	.filename dw 0
	.load_loc dw 0
	
	
	
	

;disk_convert_l2hts -- Calculate head, track and sector for int 13h
;IN: logical sector in AX; OUT: correct registers for int 13h

disk_convert_l2hts:
	push bx
	push ax

	mov bx, ax			; Save logical sector

	mov dx, 0			; First the sector
	div word [SecsPerTrack]		; Sectors per track
	add dl, 01h			; Physical sectors start at 1
	mov cl, dl			; Sectors belong in CL for int 13h
	mov ax, bx

	mov dx, 0			; Now calculate the head
	div word [SecsPerTrack]		; Sectors per track
	mov dx, 0
	div word [Sides]		; Floppy sides
	mov dh, dl			; Head/side
	mov ch, al			; Track

	pop ax
	pop bx

; ******************************************************************
	mov dl, [bootdev]		; Set correct device
; ******************************************************************

	ret

	Sides dw 2
	SecsPerTrack dw 18
; ******************************************************************
	bootdev db 0			; Boot device number
; ******************************************************************


;Reset floppy disk
disk_reset_floppy:
	push ax
	push dx
	mov ax, 0
; ******************************************************************
	mov dl, [bootdev]
; ******************************************************************
	stc
	int 13h
	pop dx
	pop ax
	ret
	
	
	
