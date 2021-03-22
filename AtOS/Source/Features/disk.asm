
; The disk file is a file containing all the disk operations and FAT12 system on the floppy

;read_rootdir reads the root directory from the disk to disk buffer
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
	jnc .done 	; If no carry, everything worked
	call disk_reset_floppy 	; If something went wrong, try reset disk
	jnc .read_dir 	; Try again if reset went okay
	popa 	; Didn't work? bring back the registers and abort
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
	
;read_fat reads the FAT from the disk to disk buffer
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


;write_rootdir writes the root directory from the disk buffer to the disk
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

;write_fat writes the first FAT from the disk buffer to the disk
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

;fatten_file makes a filename fat12 style - remove dot and add spaces so the file will be 11 bytes long
;Input: SI = filename string
;Output: AX = location of string
fatten_file:
	pusha
	
	call string_length
	
	cmp ax, 13 ; If filename is larger or equal to 13 bytes, it is a bad filename
	jge .fail
	
	cmp ax, 0 ; If filename is 0, it is also a bad filename
	je .fail
	
	mov di, .fat_string ; Get location of new string
	
	xor cx, cx
	
.loopy:

	lodsb 
	cmp al, '.'
	je .add_space
	stosb
	inc cx
	cmp cx, 8
	jg .fail ; If filename does not have a dot after 8 bytes it's a bad filename
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
	mov ax, .fat_string
	stc
	ret
	
	
	.fat_string times 12 db 0
	
	
; get_file_list makes a comma seperated string of all filenames in the floppy disk
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

	test al, 00011000b			; Is this a directory entry or volume label?
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
	
; Function loads a file into given location
; Input: AX = string, CX = location to load file at
; Output: BX = file size 
load_file:
	
	pusha
	
	call uppercase
	call fatten_file
	
	mov [.filename], ax
	mov [.load_position], cx
	
	
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
	
	cmp al, 0E5h ; 0xE5 means file was deleted
	je .next
	
	test byte [di+11], 00011000b ; If this is a volume label or sub directory skip to the next entry
	jnz .next
	
	mov byte [di+11], 0 ; Adding a terminator so name will be comparable
	mov ax, di
	call uppercase
	
	mov si, [.filename]
	
	call compare_strings
	jnc .next ; If strings aren't equal, search the next entry
	jmp .found_file_to_load
	
.error:

	xor dx, dx ; Moving cursor to (0, 0)
	call move_cursor
	
	mov si, [.file_not_found] ; Print proper message
	call print_string
	
	popa 
	
	mov bx, 0 ; Return file size = 0
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
	jmp .error


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
	.load_position dw 0
	.file_size	dw 0		
	.err_msg_floppy_reset	db 'os_load_file: Floppy failed to reset', 0
	

	
; write_file -- Save (max 64K) file to disk
; IN: AX = filename, BX = data location, CX = bytes to write
; OUT: Carry clear if OK, set if failure
write_file:
	pusha

	mov si, ax ;Error if string is null
	call string_length
	cmp ax, 0
	je near .failure
	mov ax, si

	call uppercase
	call fatten_file	; Make filename FAT12-style 
	jc near .failure

	mov word [.filesize], cx 	; Store parameters
	mov word [.location], bx
	mov word [.filename], ax

	call file_exists		; Don't overwrite a file if it exists!
	jnc near .failure


	; First, zero out the .free_clusters list from any previous execution
	pusha

	mov di, .free_clusters
	mov cx, 128
.clean_free_loop:
	mov word [di], 0
	inc di
	inc di
	loop .clean_free_loop

	popa


	; Next, we need to calculate now many 512 byte clusters are required

	mov ax, cx
	mov dx, 0
	mov bx, 512			; Divide file size by 512 to get clusters needed
	div bx
	cmp dx, 0
	jg .add_a_bit			; If there's a remainder, we need another cluster
	jmp .carry_on

.add_a_bit:
	add ax, 1
.carry_on:

	mov word [.clusters_needed], ax

	mov word ax, [.filename]	; Get filename back

	call create_file		; Create empty root dir entry for this file
	jc near .failure		; If we can't write to the media, jump out

	mov word bx, [.filesize]
	cmp bx, 0
	je near .finished ; If size is 0..

	call read_fat		; Get FAT copy into RAM
	mov si, disk_buffer + 3		; And point SI at it (skipping first two clusters)

	mov bx, 2			; Current cluster counter
	mov word cx, [.clusters_needed]
	mov dx, 0			; Offset in .free_clusters list

.find_free_cluster:
	lodsw				; Get a word
	and ax, 0FFFh			; Mask out for even
	jz .found_free_even		; Free entry?

.more_odd:
	inc bx				; If not, bump our counter
	dec si				; 'lodsw' moved on two chars; we only want to move on one

	lodsw				; Get word
	shr ax, 4			; Shift for odd
	or ax, ax			; Free entry?
	jz .found_free_odd

.more_even:
	inc bx				; If not, keep going
	jmp .find_free_cluster


.found_free_even:
	push si
	mov si, .free_clusters		; Store cluster
	add si, dx
	mov word [si], bx
	pop si

	dec cx				; Got all the clusters we need?
	cmp cx, 0
	je .finished_list

	inc dx				; Next word in our list
	inc dx
	jmp .more_odd ; Because lodsw moved two bytes, we want to dec si to go to the next byte

.found_free_odd:
	push si
	mov si, .free_clusters		; Store cluster
	add si, dx				; Add offset
	mov word [si], bx
	pop si

	dec cx
	cmp cx, 0
	je .finished_list

	inc dx				; Next word in our list
	inc dx
	jmp .more_even



.finished_list:

	; Now the .free_clusters table contains a series of numbers (words)
	; that correspond to free clusters on the disk; the next job is to
	; create a cluster chain in the FAT for our file

	mov cx, 0			; .free_clusters offset counter
	mov word [.count], 1		; General cluster counter

.chain_loop:
	mov word ax, [.count]		; Is this the last cluster?
	cmp word ax, [.clusters_needed]
	je .last_cluster

	mov di, .free_clusters

	add di, cx
	mov word bx, [di]		; Get cluster

	mov ax, bx			; Find out if it's an odd or even cluster
	mov dx, 0
	mov bx, 3
	mul bx
	mov bx, 2
	div bx				; DX = [.cluster] mod 2
	mov si, disk_buffer
	add si, ax			; AX = word in FAT for the 12 bit entry
	mov ax, word [ds:si]

	or dx, dx			; If DX = 0, [.cluster] = even; if DX = 1 then odd
	jz .even

	; Odd and even make all the free clusters we need for our file point at each other
.odd:
	and ax, 000Fh			; Reset bits we want to use
	mov di, .free_clusters
	add di, cx			; Get offset in .free_clusters
	mov word bx, [di+2]		; Get number of NEXT cluster
	shl bx, 4			; And convert it into right format for FAT
	add ax, bx

	mov word [ds:si], ax		; Store cluster data back in FAT copy in RAM

	inc word [.count]
	inc cx				; Move on a word in .free_clusters
	inc cx

	jmp .chain_loop

.even:
	and ax, 0F000h			; Zero out bits we want to use
	mov di, .free_clusters
	add di, cx			; Get offset in .free_clusters
	mov word bx, [di+2]		; Get number of NEXT free cluster

	add ax, bx

	mov word [ds:si], ax		; Store cluster data back in FAT copy in RAM

	inc word [.count]
	inc cx				; Move on a word in .free_clusters
	inc cx

	jmp .chain_loop



.last_cluster:
	mov di, .free_clusters
	add di, cx
	mov word bx, [di]		; Get last cluster

	mov ax, bx

	mov dx, 0
	mov bx, 3
	mul bx
	mov bx, 2
	div bx				; DX = [.cluster] mod 2
	mov si, disk_buffer
	add si, ax			; AX = word in FAT for the 12 bit entry
	mov ax, word [ds:si]

	or dx, dx			; If DX = 0, [.cluster] = even; if DX = 1 then odd
	jz .even_last

.odd_last:
	and ax, 000Fh			; Set relevant parts to FF8h (last cluster in file)
	add ax, 0FF80h
	jmp .finito

.even_last:
	and ax, 0F000h			; Same as above, but for an even cluster
	add ax, 0FF8h


.finito:
	mov word [ds:si], ax

	call write_fat		; Save our FAT back to disk


	; Now it's time to save the sectors to disk!

	mov cx, 0

.save_loop:
	mov di, .free_clusters
	add di, cx
	mov word ax, [di]

	cmp ax, 0
	je near .write_root_entry

	pusha

	add ax, 31

	call disk_convert_l2hts

	mov word bx, [.location] ; Location to load at ES:BX

	mov ah, 3 ;Loading from cluster to location
	mov al, 1
	stc
	int 13h

	popa

	add word [.location], 512
	inc cx
	inc cx
	jmp .save_loop


.write_root_entry:

	; Now it's time to head back to the root directory, find our
	; entry and update it with the cluster in use and file size

	call read_rootdir

	mov word ax, [.filename]
	call get_root_entry

	mov word ax, [.free_clusters]	; Get first free cluster

	mov word [di+26], ax		; Save cluster location into root dir entry

	mov word cx, [.filesize]
	mov word [di+28], cx

	mov byte [di+30], 0		; File size
	mov byte [di+31], 0

	call write_rootdir

.finished:
	popa
	clc
	ret

.failure:
	popa
	stc				; Couldn't write!
	ret


	.filesize	dw 0
	.cluster	dw 0
	.count		dw 0
	.location	dw 0

	.clusters_needed	dw 0

	.filename	dw 0

	.free_clusters	times 128 dw 0
	
;get_root_entry searches RAM copy of root dir for file entry
;Input: AX = filename
;Output: DI = location in disk_buffer of root dir entry,
;or carry set if file not found

get_root_entry:
	pusha

	mov word [.filename], ax

	mov cx, 224			; Search all (224) entries
	mov ax, 0			; Searching at offset 0

.to_next_root_entry:
	xchg cx, dx			; We use CX in the inner loop...

	mov word si, [.filename]	; Start searching for filename
	mov cx, 11
	rep cmpsb
	je .found_file			; Pointer DI will be at offset 11, if file found

	add ax, 32			; Bump searched entries by 1 (32 bytes/entry)

	mov di, disk_buffer		; Point to next root dir entry
	add di, ax

	xchg dx, cx			; Get the original CX back
	loop .to_next_root_entry

	popa

	stc				; Set carry if entry not found
	ret


.found_file:
	sub di, 11			; Move back to start of this root dir entry

	mov word [.tmp], di		; Restore all registers except for DI

	popa

	mov word di, [.tmp]

	clc
	ret


	.filename	dw 0
	.tmp		dw 0

	
	
	
;create_file creates a new 0-byte file on the floppy disk
;Input: AX = location of filename
;Output: Nothing
create_file:
	clc

	call uppercase
	call fatten_file	; Make FAT12-style filename
	pusha

	push ax				; Save filename for now

	call file_exists		; Does the file already exist?
	jnc .exists_error


	; Root dir already read into disk_buffer by os_file_exists

	mov di, disk_buffer		; So point DI at it!


	mov cx, 224			; Cycle through root dir entries
.next_entry:
	mov byte al, [di]
	cmp al, 0			; Is this a free entry?
	je .found_free_entry
	cmp al, 0E5h			; Is this a free entry?
	je .found_free_entry
	add di, 32			; If not, go onto next entry
	loop .next_entry

.exists_error:				; We also get here if above loop finds nothing
	pop ax				; Get filename back

	popa
	stc				; Set carry for failure
	ret


.found_free_entry:
	pop si				; Get filename back
	mov cx, 11
	rep movsb			; And copy it into RAM copy of root dir (in DI)


	sub di, 11			; Back to start of root dir entry, for clarity


	mov byte [di+11], 0		; Attributes
	mov byte [di+12], 0		; Reserved
	mov byte [di+13], 0		; Reserved
	mov byte [di+14], 0C6h		; Creation time
	mov byte [di+15], 07Eh		; Creation time
	mov byte [di+16], 0		; Creation date
	mov byte [di+17], 0		; Creation date
	mov byte [di+18], 0		; Last access date
	mov byte [di+19], 0		; Last access date
	mov byte [di+20], 0		; Ignore in FAT12
	mov byte [di+21], 0		; Ignore in FAT12
	mov byte [di+22], 0C6h		; Last write time
	mov byte [di+23], 07Eh		; Last write time
	mov byte [di+24], 0		; Last write date
	mov byte [di+25], 0		; Last write date
	mov byte [di+26], 0		; First logical cluster
	mov byte [di+27], 0		; First logical cluster
	mov byte [di+28], 0		; File size
	mov byte [di+29], 0		; File size
	mov byte [di+30], 0		; File size
	mov byte [di+31], 0		; File size

	call write_rootdir
	jc .failure

	popa
	clc				; Clear carry for success
	ret

.failure:
	popa
	stc
	ret
	

	
;file_exists checks if file exists and returns a carry flag if it doesn'table
;Input: AX = Filename
;Output: carry flag set if file not found, otherwise cleared
file_exists:
	pusha
	
	call uppercase
	call fatten_file
	
	mov [.filename], ax		; Store filename
	
	mov ax, 19		; Root directory starts at sector 19
	call disk_convert_l2hts 	; Make params for int 13h
	
	call read_rootdir	; Read root directory to disk buffer
	
	mov si, disk_buffer		; Point SI to disk buffer
	mov bx, -32
	
	mov cx, 224 	; Loop all 224 possible directory entries
	
.search:
	add bx, 32
	
	add si, bx
	
	cmp byte [si], 0 		; If the filename is 0 then we finished searching all filenames
	je .file_not_found
	
	cmp byte [si], 0E5h		; E5 means file was deleted
	je .search
	
	mov byte [si+11], 0 	; 0 will be a string terminator
	
	mov di, .filename
	call compare_strings 	; Compare names
	jc .file_found 		; If carry is set by function, strings are equal
	
	loop .search 	; Loop 224 entries
	
	jmp .file_not_found 	; If all entries were searched..
	
.file_not_found:
	popa
	stc 
	ret
	
.file_found:
	popa
	clc
	ret
	
	
	.filename dw 0

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
	
; ------------------------------------------------------------------
; os_fatal_error displays error message and halts execution
; IN: AX = error message string location

os_fatal_error:
	mov bx, ax			; Store string location for now

	xor dx, dx
	call move_cursor

	pusha
	mov ah, 09h			; Draw red bar at top
	mov bh, 0
	mov cx, 240
	mov bl, 01001111b
	mov al, ' '
	int 10h
	popa

	xor dx, dx
	call move_cursor

	mov si, .msg_inform		; Inform of fatal error
	call print_string

	mov si, bx			; Program-supplied error message
	call print_string

	jmp $				; Halt execution

	
	.msg_inform		db '>>> FATAL OPERATING SYSTEM ERROR', 13, 10, 0
	