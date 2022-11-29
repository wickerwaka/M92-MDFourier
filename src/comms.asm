%ifndef COMMS_ASM
%define COMMS_ASM

%include "src/util.asm"
%include "src/constants.asm"

COMMS_BUFFER_LEN equ 4096
STROBE equ 0x10
BLK_START equ 0x20
BLK_END equ 0x40

section .bss
comms_buffer: resb COMMS_BUFFER_LEN
comms_end_pos: resw 1
comms_len: resw 1
comms_index: resw 1
comms_read_pos: resw 1

active_cmd: resb 1
cmd_data_start: resw 1
cmd_data_end: resw 1

section .text
comms_read:
    in ax, 0x06
    test al, BLK_START
    jnz .no_data

    multipush es, di
    mov ax, RAM_SEG
    mov es, ax
    mov di, comms_buffer

.read_byte:
.strobe_nibble_a:
    in ax, 0x06
    test al, BLK_END
    jz .blk_end
    test al, STROBE
    jnz .strobe_nibble_a
    and al, 0x0f
    mov dl, al

.clean_nibble_a:
    in ax, 0x06
    test al, BLK_END
    jz .blk_end
    test al, STROBE
    jz .clean_nibble_a

.strobe_nibble_b:
    in ax, 0x06
    test al, BLK_END
    jz .blk_end
    test al, STROBE
    jnz .strobe_nibble_b
    shl al, 4
    or al, dl
    stosb

.clear_nibble_b:
    in ax, 0x06
    test al, BLK_END
    jz .blk_end
    test al, STROBE
    jz .clear_nibble_b

    jmp .read_byte

.blk_end:
    mov es:[comms_end_pos], di
    sub di, comms_buffer
    mov word es:[comms_len], di
    mov word es:[comms_read_pos], comms_buffer
    inc word es:[comms_index]

    multipop es, di

.no_data:
    ret

comms_load_fake:
    push bp
    mov bp, sp
    PUSH_NV

    mov ds, [bp + 8] ; segment
	mov si, [bp + 6] ; start
    mov dx, [bp + 4] ; end

    mov ax, RAM_SEG
    mov es, ax

    mov di, comms_buffer

.loop:
    cmp si, dx
    je .done
    movsb
    jmp .loop

.done:
    mov es:[comms_end_pos], di
    sub di, comms_buffer
    mov word es:[comms_len], di
    mov word es:[comms_read_pos], comms_buffer
    inc word es:[comms_index]

    POP_NV
    pop bp
    ret 6



comms_next_cmd:
    PUSH_NV

    mov ax, RAM_SEG
    mov ds, ax
    
    mov si, [comms_read_pos]
    cmp si, [comms_end_pos]
    je .no_cmd

    lodsb
    mov byte [active_cmd], al
    lodsw
    mov [cmd_data_start], si
    add si, ax
    cmp si, [comms_end_pos]
    jg .no_cmd ; underflow
    mov [cmd_data_end], si
    mov [comms_read_pos], si
    xor ax, ax
    mov al, [active_cmd]
    jmp .return

.no_cmd:
    mov byte [active_cmd], 0
    mov word [cmd_data_end], 0
    mov word [cmd_data_start], 0
    mov ax, 0

.return:
    POP_NV

    ret

%endif ; COMMS_ASM