org 0

CODE_SEG equ 0x0
DATA_SEG equ 0x0

entry:
	mov ax, DATA_SEG
	mov es, ax
	mov ds, ax

	jmp $


times 0x7fff0-($-$$) db 0
startup:
	jmp CODE_SEG:entry

times 0xc0000-($-$$) db 0
