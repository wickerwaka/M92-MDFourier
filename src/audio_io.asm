%ifndef AUDIO_IO_ASM
%define AUDIO_IO_ASM

%include "src/util.asm"
%include "src/constants.asm"

; al - addr
; ah - value
; preserves ax
write_audio:
	cli

	push bx
	push cx
    push ax

	mov bx, ax

	mov byte ss:[audio_value_ready], 0
	mov al, 1
	out 0x00, al

	mov cx, 0x1000
.wait_cmd:
	loop .wait_cmd

	mov al, bl
	out 0x00, al

	mov cx, 0x1000
.wait_addr:
	loop .wait_addr

	mov al, bh
	out 0x00, al

	sti
	
.wait_value:
	cmp byte ss:[audio_value_ready], 0
	je .wait_value

    pop ax
	pop cx
	pop bx
	ret

; al - addr
; response in al
read_audio:
	push bx
	push cx
	mov bx, ax

	mov byte ss:[audio_value_ready], 0
	
	mov al, 0
	out 0x00, al

	mov cx, 0x1000
.wait_cmd:
	loop .wait_cmd

	mov al, bl
	out 0x00, al

	mov cx, 0x1000
.wait_addr:
	loop .wait_addr

	mov al, 0
	out 0x00, al

.wait_value:
	cmp byte ss:[audio_value_ready], 0
	je .wait_value

	mov al, ss:[audio_value]

	pop cx
	pop bx
	ret


align 4
audio_io_handler:
	push ax
	in al, 0x08
	mov ss:[audio_value], al
	mov byte ss:[audio_value_ready], 1
	pop ax
	iret


section .bss
	audio_value: resb 1
	audio_value_ready: resb 1


%endif ; AUDIO_IO_ASM