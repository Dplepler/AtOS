; The disk file is a file containing all the disk operations and the FAT12 system on the floppy

; read_rootdir reads the root directory from the disk to disk buffer
; Input: Nothing
; Output: Carry flag if function failed
read_rootdir:

	pusha
	
	mov ax, 19 ; Read from sector 19 (root directory)
	call disk_convert_l2hts
	
	mov bx, disk_buffer ; ES:BX will point to disk_buffer
	mov ax, ds
	mov es, ax
	
	mov ah, 2 ; Param to read
	mov al, 14 ; Read 14 sectors 
	
	pusha ; Save registers, enter loop
	
.read_dir:
	popa
	pusha

	int 13h
	jnc .done 					; If no carry, everything worked
	call disk_reset_floppy 		; If something went wrong, try reset disk
	jnc .read_dir 				; Try again if reset went okay
	popa 						; Didn't work? bring back the registers and abort
	jmp .fail
	
	
.done: ; Clear carry flag and pop registers to the beginning of system call
	clc
	popa
	popa
	ret

.fail: ; Turn on carry flag if function failed, bring back registers from the beginning of the system call and return
	stc
	popa
	ret
	

	
; read_fat reads the FAT from the disk to disk buffer
; Input: Nothing
; Output: Carry flag if function failed
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
	
; read_fat reads the FAT from the disk to RAM (32768)
; Input: Nothing
; Output: Carry flag if function failed
read_fat_to_ram:
	
	pusha
	
	
	mov ax, 1 ;The fat table starts after the bootloader, at sector 1
	call disk_convert_l2hts 
	
	mov bx, 32768
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


; write_rootdir writes the root directory from the disk buffer to the disk
; Input: Nothing
; Output: Carry flag if function failed
write_rootdir:

	pusha
	
	mov ax, 19 ; The root directory starts at sector 19
	call disk_convert_l2hts
	
	mov bx, disk_buffer ; ES:BX now points at 8K buffer
	mov ax, ds
	mov es, ax
	
	mov ah, 3 ; Param for BIOS to write sectors
	mov al, 14 ; Writing 14 sectors (root directory takes the place of sectors 19-32)
	
	int 13h ; Interupt
	jc .failure ; If there's an error, carry flag will turn on and we will return it
	
	popa
	clc ; Otherwise, clear carry
	ret

.failure:
	popa
	stc
	ret
	
	

; write_fat writes the first FAT from the disk buffer to the disk
; Input: Nothing
; Output: Carry flag if function failed
write_fat:
	pusha
	
	mov ax, 1 ; The fat table starts after the bootloader, at sector 1
	call disk_convert_l2hts 
	
	mov bx, disk_buffer
	mov ax, ds
	mov es, ax
	
	mov ah, 3 ; Param for BIOS to write sectors
	mov al, 9
	
	int 13h
	jc .failure ; If there's an error, carry flag will turn on and we will return it
	
	popa
	clc ; Otherwise, clear carry
	ret

.failure:
	popa
	stc
	ret

; fatten_file makes a filename FAT12 style by making it 11 bytes long with spaces filling (example: FOO.EXE = FOO     EXE)
; Input: AX = filename string
; Ouput: AX = location of converted string (carry set if invalid)
fatten_file:
	pusha

	mov si, ax

	call string_length
	cmp ax, 14			; Filename too long?
	jg .failure			; Fail if so

	cmp ax, 0
	je .failure			; Similarly, fail if zero-char string

	mov dx, ax			; Store string length for now

	mov di, .dest_string

	mov cx, 0
.copy_loop:
	lodsb
	cmp al, '.'
	je .extension_found
	stosb
	inc cx
	cmp cx, dx
	je .directory			; No extension found = this is a directory
	jmp .copy_loop

.extension_found:

	cmp cx, 0
	je .failure			; Fail if extension dot is first char

	cmp cx, 8
	je .do_extension		; Skip spaces if first bit is 8 chars

	; Now it's time to pad out the rest of the first part of the filename
	; with spaces, if necessary

.add_spaces:
	mov byte [di], ' '
	inc di
	inc cx
	cmp cx, 8
	jl .add_spaces

	; Finally, copy over the extension
.do_extension:
	lodsb				; 3 characters
	cmp al, 0
	je .failure
	stosb
	lodsb
	cmp al, 0
	je .failure
	stosb
	lodsb
	cmp al, 0
	je .failure
	stosb
	
.done:

	mov byte [di], 0		; Zero-terminate filename

	popa
	mov ax, .dest_string
	clc				; Clear carry for success
	ret

.directory:
	cmp cx, 11
	je .done
	mov byte [di], ' '  	
	inc di
	inc cx
	jmp .directory


.failure:
	popa
	stc				; Set carry for failure
	ret


	.dest_string	times 13 db 0
	
	
	
	
; get_file_list makes a comma seperated string of all file names in the floppy disk
; Input: AX = Empty string, Directory in disk buffer
; Output: AX = Same string with all file names and a 0 at the end
get_file_list:
	pusha

	mov word [.file_list_tmp], ax
	
.show_dir_init:
	
	mov ax, 0
	mov si, disk_buffer		; Data reader from start of filenames

	mov word di, [.file_list_tmp]	; Name destination buffer


.start_entry:

	mov al, [si+11]			; File attributes for entry
	cmp al, 0Fh			; Windows marker, skip it
	je .skip
	
	test al, 00010000b			; Is this a directory entry?
	jnz .directory			; Yes, print the entire name
	
	test al, 00001000b			; Is this a volume label?
	jnz .skip
	
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
	
.directory:
	
	
	mov al, [si]
	cmp al, 229			; If we read 229 = deleted filename
	je .skip

	cmp al, 0			; 1st byte = entry never used
	je .done

	mov dx, si			; Beginning of possible entry
	
	mov cx, 11
	
.directory_loop:
	
	lodsb 	; Loading from SI to al
	cmp al, ' '
	je .done_copy
	stosb 	; Storing from al to DI
	
	loop .directory_loop
	jmp .done_copy

.done:
	dec di
	mov byte [di], 0		; Zero-terminate string (gets rid of final comma)

	popa
	ret


	.file_list_tmp		dw 0
	
; get_directory_list makes a comma seperated string of all directories in a given directory
; Input: AX = Empty string, directory in disk buffer
; Output: AX = Same string with all file names and a 0 at the end
get_directory_list:
	pusha

	mov word [.file_list_tmp], ax

	mov ax, 0
	mov cx, 0
	mov si, disk_buffer		; Data reader from start of filenames

	mov word di, [.file_list_tmp]	; Name destination buffer


.start_entry:
	mov al, [si+11]			; File attributes for entry
	cmp al, 0Fh			; Windows marker, skip it
	je .skip
	
	test al, 00010000b			; Is this a directory entry or volume label?
	jnz .directory			; Yes, print the entire name
	
	cmp byte [si], 0
	je .done
	
	jmp .skip
	
	
.done_copy:
	mov byte [di], ','		; Use comma to separate filenames
	inc di

.nxtdirentry:
	mov si, dx			; Start of entry, pretend to skip to next

.skip:
	add si, 32			; Shift to next 32 bytes (next filename)
	jmp .start_entry
	
.directory:
	mov al, [si]
	cmp al, 229			; If we read 229 = deleted filename
	je .skip

	cmp al, 0			; 1st byte = entry never used
	je .done

	mov dx, si			; Beginning of possible entry
	
	mov cx, 11
	
.directory_loop:
	
	mov al, [si]
	mov byte [di], al
	inc si
	inc di
	
	loop .directory_loop
	jmp .done_copy

.done:
	dec di
	mov byte [di], 0		; Zero-terminate string (gets rid of final comma)
	
	mov si, [.file_list_tmp]

	popa
	ret


	.file_list_tmp		dw 0
	
; load_file will load file clusters into given location 
; Input: AX = filename location, CX = loading position, directory in disk buffer
; Output: BX = file size (in bytes), SI = first cluster word location, carry set if file not found
load_file:

	call fatten_file
	call uppercase

	mov [.filename], ax		; Store filename location
	mov [.load_position], cx	; And where to load the file
	
	
	mov di, disk_buffer
	call get_root_entry 	; Find location of file and put it in DI


.found_file_to_load:			; Now fetch cluster and load FAT into RAM

	mov ax, [di+28]			; Store file size to return to calling routine
	mov word [.file_size], ax

	cmp ax, 0			; If the file size is zero, don't bother trying
	je .end				; to read more clusters
	
	
	mov ax, [di+26]			; Now fetch cluster and load FAT into RAM
	mov word [.cluster], ax
	mov word [.first_cluster], ax
	
	


	call read_fat_to_ram
	mov ax, 32768 	; Point AX at RAM

.load_file_sector:
	mov ax, word [.cluster]
	

	add ax, 31 			; Convert sector to logical

	call disk_convert_l2hts		; Make appropriate params for int 13h

	mov bx, [.load_position]


	mov ah, 2			; AH = read sectors, AL = just read 1
	mov al, 1

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
	mov si, 32768		; AX = word in FAT for the 12 bits
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
	mov si, .first_cluster 		; Save first cluster location to SI
	clc				; Carry clear = good load
	ret


	.cluster	dw 0 		; Cluster of the file we want to load
	.first_cluster dw 0

	.filename	dw 0		; Temporary store of filename location
	.load_position	dw 0		; Where we'll load the file
	.file_size	dw 0		; Size of the file

	.err_msg_floppy_reset	db 'os_load_file: Floppy failed to reset', 0



; write_file saves (max 64K) file to disk
; Input: AX = filename, BX = data location, CX = bytes to write, DL = directory flag (set if file is a subdirectory), SI = start location of first cluster of directory, 0 if root
; Output: Carry clear if OK, set if failure
write_file:
	pusha

	mov byte [.is_dir], dl
	mov [.first_cluster], si

	
	mov si, ax  	; Error if string is null
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

	
	mov si, [.first_cluster] 		; Load directory
	mov ax, [si]
	call load_with_first_cluster
	
	mov ax, [.filename]

	mov di, disk_buffer
	call get_root_entry 	; Check if filename exists
	jnc near .file_exists


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


	mov word bx, [.filesize]
	cmp bx, 0
	je near .finished ; If size is 0..
	
	call read_fat		; Get FAT copy into disk buffer
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
	jmp .more_odd ; Because lodsw moved two bytes, we want to dec SI to go to the next byte

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

	; Now it's time to save the sectors to disk!
	
	mov word [ds:si], ax
	call write_fat

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
	

	mov word bx, [.location] ; Location to read from at ES:BX

	mov ah, 3 		; Writing clusters
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

	
	mov si, [.first_cluster] 		; Load directory
	mov ax, [si]
	call load_with_first_cluster
	
	mov word ax, [.filename]	; Get filename back
	mov si, [.first_cluster] 		; Put first cluster in BX as a parameter 
	mov bx, [si]
	

	call create_file		; Create empty root dir entry for this file
	jc near .failure		; If we can't write to the media, jump out
	
	mov si, [.first_cluster] 		; Load directory
	mov ax, [si]
	call load_with_first_cluster


	mov ax, [.filename]
	mov di, disk_buffer
	call get_root_entry

	

	mov word ax, [.free_clusters]	; Get first free cluster

	mov word [di+26], ax		; Save cluster location into root dir entry

	mov word cx, [.filesize]
	mov word [di+28], cx

	mov byte [di+30], 0		; File size
	mov byte [di+31], 0
	
	cmp byte [.is_dir], 0
	jne .directory
	

	mov si, [.first_cluster] 		; Load directory
	mov ax, [si]
	call update_directory

.finished:

	popa
	clc
	ret
	
.directory:

	mov byte [di+11], 00010000b 	; Turn on subdirectroy attribute flag
	
	mov si, [.first_cluster] 		; Load directory
	mov ax, [si]
	call update_directory
	
	jmp .finished
	
.file_exists:

	call file_already_exists 		; Inform user that the file already exists
	
.failure:
	popa
	stc				; Couldn't write!
	ret


	.is_dir 	db 0
	.filesize	dw 0
	.cluster	dw 0
	.count		dw 0
	.location	dw 0
	
	.first_cluster 			dw 0
	.clusters_needed	dw 0

	.filename	dw 0

	.free_clusters	times 128 dw 0
	
	
; load_with_first_cluster loads directory to disk buffer by using the first cluster of it. Only two cluster files allowed.
; Input: AX = first cluster
; Output: None
load_with_first_cluster:

	mov word [.two_clusters], ax
	mov word [.location], disk_buffer
	
	cmp ax, 0 			; If given cluster equals 0 we want to load the root directory
	je .load_root

	call read_fat

.calculate_next_cluster:
	
	mov ax, [.two_clusters]
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

	mov si, .two_clusters
	add si, 2 			; Move on to next cluster
	mov word [si], ax		; Store cluster


.load_file_sector:
	mov ax, word [.two_clusters]

	add ax, 31 			; Convert sector to logical

	call disk_convert_l2hts		; Make appropriate params for int 13h
	
	mov bx, [.location]


	mov ah, 2			; AH = read sectors, AL = just read 1
	mov al, 1

	stc
	int 13h
	jnc .load_next_cluster	; If there's no error...

	call disk_reset_floppy		; Otherwise, reset floppy and retry
	jnc .load_file_sector

	mov ax, .err_msg_floppy_reset	; Reset failed, bail out
	jmp os_fatal_error
	
.load_next_cluster:

	add word [.location], 512
	
	mov si, .two_clusters
	add si, 2
	
	mov ax, [si]

	add ax, 31 			; Convert sector to logical

	call disk_convert_l2hts		; Make appropriate params for int 13h
	
	mov bx, [.location]
	
	mov ah, 2			; AH = read sectors, AL = just read 1
	mov al, 1

	stc
	int 13h

	clc				; Carry clear = good load
	ret
	
	
.load_root:
	call read_rootdir
	clc
	ret
	
	.location 				dw 0
	.two_clusters times 4 dw 0 		; Two clusters of directory
	.err_msg_floppy_reset	db 'os_load_file: Floppy failed to reset', 0
	
	
	
; update_directory gets the first cluster of a directory and updates it with contents in the disk buffer
; Input: AX = first cluster, new directory in disk buffer
; Output: None
update_directory:

	pusha
	mov word [.cluster], ax 	; Storing first cluster
	
	cmp ax, 0 					; If directory is root
	je .write_root
	
	mov si, disk_buffer 			; Copy new directory from disk buffer to a two cluster variable
	mov di, .two_clusters
	mov cx, 1024
	
	rep movsb
	
	mov bx, .two_clusters
	mov [.location], bx
	
	
.try_write:

	add ax, 31 					; Converting first cluster to logical
	call disk_convert_l2hts		; Make appropriate params for int 13h
	
	mov ah, 3 					; Writing one sector to drive
	mov al, 1 
	
	mov bx, [.location]
	
	int 13h
	jc .reset_floppy
	
	call read_fat
	
.more_clusters:

	mov ax, [.cluster]		; Get cluster contents

	mov bx, 3			; Determine if cluster is odd or even number
	mul bx
	mov bx, 2
	div bx				; DX = [first_cluster] mod 2
	mov si, disk_buffer		; AX = word in FAT for the 12 bits
	add si, ax
	mov ax, word [ds:si]

	or dx, dx			; If DX = 0 [.cluster] = even, if DX = 1 then odd

	jz .even			; If [.cluster] = even, drop last 4 bits of word
					; with next cluster; if odd, drop first 4 bits
.odd:

	shr ax, 4			; Shift out first 4 bits (they belong to another entry)
	jmp .calculate_cluster_cont	; Onto next sector!

.even:

	and ax, 0FFFh			; Mask out top (last) 4 bits (they belong to another entry)

.calculate_cluster_cont:
	mov word [.cluster], ax		; Store cluster
	add word [.location], 512 	; Write next directory cluster

	cmp ax, 0FF8h			; Final cluster marker?
	jae .end

	jmp .try_write		; If not, grab more
	

.reset_floppy:

	call disk_reset_floppy
	jc .failure
	jmp .try_write
	
.write_root:

	call write_rootdir
	jmp .end
	
	
.failure:
	popa
	stc
	ret
	
	
.end:
	popa
	clc
	ret
	
	.cluster dw 0
	.location dw 0
	.two_clusters times 1024 dw 0
	

; get_root_entry searches RAM copy of root dir for file entry
; Input: AX = filename, Directory in disk buffer
; Output: DI = location in disk_buffer of file
; or carry set if file not found
get_root_entry:
	pusha

	call fatten_file
	call uppercase
	
	mov word [.filename], ax
	
	mov ax, 0			; Searching at offset 0

.to_next_root_entry:

	cmp byte [di], 0
	je .failure 	; If we didn't find the file finish function
	
	mov word si, [.filename]	; Start searching for filename
	mov cx, 11
	rep cmpsb
	je .found_file			; Pointer DI will be at offset 11, if file found

	add ax, 32			; Bump searched entries by 1 (32 bytes/entry)

	mov di, disk_buffer		; Point to next root dir entry
	add di, ax
	
	jmp .to_next_root_entry

.failure:
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

	
	
	
; create_file creates a new empty file on the floppy disk
; Input: AX = location of filename, BX = first cluster of parent directory, directory in disk buffer
; Output: Nothing
create_file:
	clc
	
	
	call uppercase
	call fatten_file	; Make FAT12-style filename
	pusha
	
	push bx 			; Save first cluster
	push ax				; Save filename for now

	mov di, disk_buffer			
	call get_root_entry  		; Check if filename exists
	jnc .exists_error 			


	mov di, disk_buffer 

	mov cx, 224			; Cycle through directory entries
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
	pop bx 				; Get first cluster back
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

	pop ax 				; Put first cluster in AX
	call update_directory
	
	
	popa
	clc				; Clear carry for success
	ret

	

; rename_file takes a filename and switches it with a new filename
; Input: AX = filename, BX = new filename, DX = first cluster of parent directory, 0 if root
; Output: Carry flag if failure happens
rename_file:
	pusha
	
	push ax 	; This is useless but we want to store the bx param
	push bx 	; Storing BX
	
	call fatten_file 	; Converting filename into a FAT12 style
	call uppercase
	
	mov di, disk_buffer
	call get_root_entry 	; Checking if filename exists and if it does return location in DI
	jc .failure 	; If filename doesn't exist, bail
	
	pop ax 	; Popping the new string to AX
	call fatten_file 	; Making the new filename string FAT12 style
	call uppercase
	
	mov si, ax
	
	mov cx, 11 		; 11 bytes to copy from SI to DI
	rep movsb
	
	mov ax, dx
	call update_directory
	
	
	pop si
	popa
	clc
	ret
	
.failure:
	pop ax
	pop bx
	popa
	stc
	ret




; delete_file deletes a file from the disk
; Input: AX = location of filename to remove, BX = first cluster of parent directory or 0 if it's root
; Output: None
delete_file:
	pusha
	push bx 	; Storing first cluster
	
	call fatten_file
	call uppercase
	
	push ax				; Save filename

	clc

	mov di, disk_buffer		; Point DI to root dir
	

	pop ax				; Get chosen filename back
	pop bx

	call get_root_entry		; Entry will be returned in DI
	jc .failure				; If entry can't be found

	mov ax, word [es:di+26]		; Get first cluster number from the dir entry
	mov word [.cluster], ax		; And save it

	mov byte [di], 0E5h		; Mark directory entry (first byte of filename) as empty
	

	inc di

	mov cx, 0			; Set rest of data in root dir entry to zeros
.clean_loop:
	mov byte [di], 0
	inc di
	inc cx
	cmp cx, 31			; 32-byte entries, minus E5h byte we marked before
	jl .clean_loop
	
	mov ax, bx  	; Move param to AX, first cluster of directory
	call update_directory
	
	

	call read_fat		; Now FAT is in disk_buffer
	mov di, disk_buffer		; And DI points to it


.more_clusters:
	mov word ax, [.cluster]		; Get cluster contents

	cmp ax, 0			; If it's zero, this was an empty file
	je .nothing_to_do

	mov bx, 3			; Determine if cluster is odd or even number
	mul bx
	mov bx, 2
	div bx				; DX = [first_cluster] mod 2
	mov si, disk_buffer		; AX = word in FAT for the 12 bits
	add si, ax
	mov ax, word [ds:si]

	or dx, dx			; If DX = 0 [.cluster] = even, if DX = 1 then odd

	jz .even			; If [.cluster] = even, drop last 4 bits of word
					; with next cluster; if odd, drop first 4 bits
.odd:
	push ax
	and ax, 000Fh			; Set cluster data to zero in FAT in RAM
	mov word [ds:si], ax
	pop ax

	shr ax, 4			; Shift out first 4 bits (they belong to another entry)
	jmp .calculate_cluster_cont	; Onto next sector!

.even:
	push ax
	and ax, 0F000h			; Set cluster data to zero in FAT in RAM
	mov word [ds:si], ax
	pop ax

	and ax, 0FFFh			; Mask out top (last) 4 bits (they belong to another entry)

.calculate_cluster_cont:
	mov word [.cluster], ax		; Store cluster

	cmp ax, 0FF8h			; Final cluster marker?
	jae .end

	jmp .more_clusters		; If not, grab more

.end:
	call write_fat
	jc .failure

.nothing_to_do:
	popa
	clc
	ret

.failure:
	popa
	stc
	ret

	.in_dir  db 0
	.cluster dw 0
	
	
; delete_file_from_dir deletes only the directory entry of the file, but doesn't delete the FAT contents. Used to move files from directory to directory
; Input: AX = location of filename to remove, BX = first cluster of parent directory or 0 if it's root
; Output: None
delete_file_from_dir:
	pusha
	push bx 	; Storing first cluster
	
	call fatten_file
	call uppercase
	
	push ax				; Save filename

	clc

	mov di, disk_buffer		; Point DI to root dir
	

	pop ax				; Get chosen filename back
	pop bx

	call get_root_entry	; Entry will be returned in DI
	jc .failure			; If entry can't be found


	mov ax, word [es:di+26]		; Get first cluster number from the dir entry
	mov word [.cluster], ax		; And save it

	mov byte [di], 0E5h		; Mark directory entry (first byte of filename) as empty
	

	inc di

	mov cx, 0			; Set rest of data in root dir entry to zeros
.clean_loop:
	mov byte [di], 0
	inc di
	inc cx
	cmp cx, 31			; 32-byte entries, minus E5h byte we marked before
	jl .clean_loop

	cmp bx, 0 		; If BX equals 0, we are in the root directory
	je .root_dir
	mov ax, bx  	; Move param to AX, first cluster of directory
	call update_directory
	jmp .nothing_to_do
	
.root_dir:

	call write_rootdir 	; If we are in the root directory we want to update it


.nothing_to_do:
	popa
	clc
	ret

.failure:
	popa
	stc
	ret

	.in_dir  db 0
	.cluster dw 0
	


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
	