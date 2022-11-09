org 0

CODE_SEG equ 0x0
DATA_SEG equ 0x0

entry:
	mov ax, DATA_SEG
	mov ds, ax

	mov ax, 0xf880
	mov es, ax
	mov ax, 0

fill:
	inc ax
	mov cx, 0x400
	xor di, di
	repnz stosw
	jmp fill

	jmp $


times 0x7fff0-($-$$) db 0
startup:
	jmp CODE_SEG:entry

times 0xc0000-($-$$) db 0
