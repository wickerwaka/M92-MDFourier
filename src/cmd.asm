%ifndef CMD_ASM
%define CMD_ASM

%include "src/util.asm"
%include "src/constants.asm"
%include "src/text.asm"
%include "src/comms.asm"
%include "src/audio_io.asm"

CMD_NONE equ 0
CMD_SHOW_MEMORY_BYTE equ 1
CMD_SHOW_MEMORY_WORD equ 2
CMD_WRITE_BYTES equ 3
CMD_WRITE_WORDS equ 4
CMD_OUT_BYTE equ 5
CMD_OUT_WORD equ 6
CMD_IN_BYTE equ 7
CMD_IN_WORD equ 8
CMD_CALL equ 9
CMD_MEMSET equ 10
CMD_PRINT_AT equ 11
CMD_READ_BYTES equ 12
CMD_READ_WORDS equ 13
CMD_MEMSET_WORDS equ 14
CMD_WRITE_AUDIO equ 15
CMD_READ_AUDIO equ 16

section .data
cmd_table:
	dw cmd_none
	dw cmd_show_memory_byte
	dw cmd_show_memory_word
    dw cmd_write_bytes
    dw cmd_write_words
    dw cmd_out_byte
    dw cmd_out_word
    dw cmd_in_byte
    dw cmd_in_word
    dw cmd_call
    dw cmd_memset
    dw cmd_print_at
    dw cmd_read_bytes
    dw cmd_read_words
    dw cmd_memsetw
	dw cmd_write_audio
	dw cmd_read_audio

section .text
cmd_none:
	ret

cmd_show_memory_byte:
	PUSH_NV

	call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]

	lodsw
	push ax ; segment
	lodsw
	push ax ; offset
	lodsw
	push ax ; count
	call draw_memory_byte

	POP_NV
	ret

cmd_show_memory_word:
	PUSH_NV

	call clear_text
	
	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]

	lodsw
	push ax ; segment
	lodsw
	push ax ; offset
	lodsw
	push ax ; count
	call draw_memory_word

	POP_NV
	ret

cmd_write_bytes:
	PUSH_NV

	call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]
    mov bx, ds:[cmd_data_end]
    sub bx, si
    sub bx, 4

	print_at 4, 8, "WRITE %x BYTES TO %x:%x", bx, [si + 0], [si + 2]

	mov es, [si + 0]
	mov di, [si + 2]
	add si, 4
	mov cx, bx
	rep movsb

	POP_NV
	ret

cmd_write_words:
	PUSH_NV

	call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]
    mov bx, ds:[cmd_data_end]
    sub bx, si
    sub bx, 4
    shr bx, 1

	print_at 4, 8, "WRITE %x WORDS TO %x:%x", bx, [si + 0], [si + 2]

	mov es, [si + 0]
	mov di, [si + 2]
	add si, 4
	mov cx, bx
	rep movsw

	POP_NV
	ret

cmd_out_byte:
	PUSH_NV

    call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]

	print_at 4, 8, "OUTPUT %l TO PORT %x", [si + 2], [si + 0]

	mov dx, [si + 0]
	mov al, [si + 2]

	out dx, al

	POP_NV
	ret

cmd_out_word:
	PUSH_NV

    call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]

	print_at 4, 8, "OUTPUT %x TO PORT %x", [si + 2], [si + 0]

	mov dx, [si + 0]
	mov ax, [si + 2]

	out dx, ax

	POP_NV
	ret

cmd_in_byte:
    PUSH_NV

	call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]

	mov dx, [si + 0]

	in al, dx
	xor ah, ah
	mov di, ax

	print_at 4, 8, "READ %l FROM PORT %x", di, [si + 0]

	POP_NV
	ret

cmd_in_word:
    PUSH_NV

	call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]

	mov dx, [si + 0]

	in ax, dx
	mov di, ax

	print_at 4, 8, "READ %x FROM PORT %x", di, [si + 0]

	POP_NV
	ret

section .bss
    alignb 2
    far_addr: resw 2

section .text
cmd_call:
    PUSH_NV

	call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]

	print_at 4, 8, "FAR CALL %x:%x", [si + 2], [si + 0]

    PUSH_ALL

    call far [si]

    POP_ALL

	POP_NV
	ret

cmd_memset:
	PUSH_NV

	call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]

	print_at 4, 8, "MEMSET %x BYTES AT %x:%x", [si + 4], [si + 0], [si + 2]

	mov es, [si + 0]
	mov di, [si + 2]
	mov cx, [si + 4]
    mov al, [si + 6]
	rep stosb

	POP_NV
	ret

cmd_memsetw:
	PUSH_NV

	call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]

	print_at 4, 8, "MEMSET %x WORDS AT %x:%x", [si + 4], [si + 0], [si + 2]

	mov es, [si + 0]
	mov di, [si + 2]
	mov cx, [si + 4]
    mov ax, [si + 6]
	rep stosw

	POP_NV
	ret

cmd_print_at:
	PUSH_NV

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]

    mov al, [si]
    cmp al, 0
    jz .noclear

    call clear_text

.noclear:
    mov ax, [si + 1]
    call set_text_pos

    add si, 2
    push ds
    push si
    call print_string

	POP_NV
	ret

section .bss
send_buffer: resb 256

section .text
cmd_read_bytes:
	PUSH_NV

	call clear_text
	mov ax, RAM_SEG
	mov es, ax
	mov di, es:[cmd_data_start]

    print_at 4, 8, "READ %x BYTES AT %x:%x", es:[di + 4], es:[di + 0], es:[di + 2]
 
	mov ax, es:[di]
    mov ds, ax
	mov si, es:[di + 2]
    mov ax, es:[di + 4]
    
    mov cx, ax
    mov di, send_buffer
    rep movsb

    push es
    push send_buffer
    push ax
    call comms_send

	POP_NV
	ret

cmd_read_words:
	PUSH_NV

	call clear_text
	mov ax, RAM_SEG
	mov es, ax
	mov di, es:[cmd_data_start]

    print_at 4, 8, "READ %x WORDS AT %x:%x", es:[di + 4], es:[di + 0], es:[di + 2]
 
	mov ax, es:[di]
    mov ds, ax
	mov si, es:[di + 2]
    mov ax, es:[di + 4]
    
    mov cx, ax
    mov di, send_buffer
    rep movsw

    push es
    push send_buffer
    shl ax, 1
    push ax
    call comms_send

	POP_NV
	ret

cmd_write_audio:
	PUSH_NV

	call clear_text

	mov ax, RAM_SEG
	mov ds, ax
	mov si, ds:[cmd_data_start]
    mov bx, ds:[cmd_data_end]
    sub bx, si
    sub bx, 2

	print_at 4, 8, "WRITE %x AUDIO BYTES TO A80%l", bx, [si + 0]

	mov al, [si + 0]
	add si, 2
	mov cx, bx

.copy_loop:
	mov ah, [si]
	inc si
	push ax
	call write_audio
	pop ax
	add al, 2
	loop .copy_loop

	POP_NV
	ret


cmd_read_audio:
	PUSH_NV

	call clear_text
	mov ax, RAM_SEG
	mov es, ax
	mov di, es:[cmd_data_start]

    print_at 4, 8, "READ %x AUDIO BYTES AT A80%l", es:[di + 2], es:[di + 0]
 
	mov bx, es:[di + 0]
	mov dx, es:[di + 2]
    
    mov cx, dx
    mov di, send_buffer
	xor ah, ah

.read_loop:
	mov al, bl
	add bl, 2
	call read_audio
	stosb
	loop .read_loop
    
    push es
    push send_buffer
    push dx
    call comms_send

	POP_NV
	ret

%endif ; CMD_ASM