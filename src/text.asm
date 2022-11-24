%ifndef TEXT_ASM
%define TEXT_ASM

%include "src/util.asm"
%include "src/constants.asm"

%macro  print 1-4
    [section .data]
    %%string: db %1, 0

    __?SECT?__

    push cs
    push %%string
    %if %0 > 3
    mov dx, %4
    %endif
    %if %0 > 2
    mov cx, %3
    %endif
    %if %0 > 1
    mov ax, %2
    %endif
    call print_string
%endmacro

%macro  print_at 3+
    mov ax, (%1 << 8) | %2
    call set_text_pos

    print %3
%endmacro

section .text
; Set text cursor position
; ah = x, al = y
set_text_pos:
	push es
	mov cx, RAM_SEG
	mov es, cx
	mov es:[text_x], ah
	mov es:[text_y], al
	pop es
	ret

; null terminated string in ax
print_string:
	push bp
	mov bp, sp
	
	sub sp, 10

.local_x equ -8

	mov [bp - 2], ax ; optional integer args
	mov [bp - 4], cx
	mov [bp - 6], dx

	multipush di, si, ds, es, bx

	mov ds, [bp + 6] ; 1st argument
	mov si, [bp + 4] ; 2nd argument
.newline:
	mov ax, RAM_SEG
	mov es, ax
	xor cx, cx
	xor ax, ax
	
	; x40
	mov al, es:[text_y]
	shl ax, 3
	mov di, ax
	shl ax, 2
	add di, ax

	xor dx, dx
	mov dl, es:[text_x]
	mov [bp + .local_x], dx
	add di, dx
	shl di, 1
	add di, text_buffer

	xor ax, ax
	mov ah, es:[text_color]
	
.copy_loop:
	lodsb
	cmp al, 0
	je .done

	cmp al, `\n` ; \n
	jne .color_check
	inc byte es:[text_y]
	jmp .newline

.color_check:
	cmp al, `^`
	jne .format_check
	lodsb
	cmp al, `^`
	je .char_output
	sub al, `0`
	and al, 0x0f
	mov es:[text_color], al
	mov ah, al
	jmp .copy_loop

.format_check:
	cmp al, `%`
	jne .char_output
	lodsb
	cmp al, `x`
	je .hex_word_output
	cmp al, `l`
	je .hex_low_output
	cmp al, `h`
	je .hex_high_output
	jmp .char_output

.hex_word_output:
    mov cx, 4
	mov dx, [bp - 2]
    jmp .shift_args

.hex_low_output:
    mov cx, 2
    mov dx, [bp - 2]
    mov dh, dl
    jmp .shift_args

.hex_high_output:
    mov cx, 2
    mov dx, [bp - 2]

.shift_args:
	mov bx, [bp - 4] ; shift args
	mov [bp - 2], bx
	mov bx, [bp - 6]
	mov [bp - 4], bx

	add word [bp + .local_x], cx

.digit_loop:
	mov bx, dx
	shr bx, 12
	and bx, 0xf
	mov al, cs:[.st_hex_digits + bx]
	stosw
	shl dx, 4
	loop .digit_loop
	jmp .copy_loop

.char_output:
	stosw
	inc word [bp + .local_x]
	jmp .copy_loop

.done:
	mov ax, RAM_SEG
	mov es, ax
	mov dx, [bp - 8]
	mov es:[text_x], dl

	multipop di, si, ds, es, bx

	add sp, 10

	pop bp
	ret 4

.st_hex_digits: db `0123456789ABCDEF`, 0

copy_text_buffer:
	PUSH_NV

	mov ax, RAM_SEG
	mov ds, ax
	mov ax, VRAM_SEG
	mov es, ax
	mov si, text_buffer
	mov di, [text_base]

	mov dx, 30
	xor bx, bx
.outer:
	mov cx, 40
.inner:
	lodsw
	mov bl, ah
	xor ah, ah
	stosw
	mov ax, bx
	stosw
	loop .inner

	add di, ( 64 - 40 ) * 4
	dec dx
	jnz .outer

	POP_NV

	ret

clear_text:
    PUSH_NV

	mov ax, RAM_SEG
	mov es, ax
	mov di, text_buffer

    mov cx, 1200
    mov ax, 0
    rep stosw

    POP_NV
    ret

; seg, offset, count
draw_memory_word:
    mov ax, 1
    jmp draw_memory

; seg, offset, count
draw_memory_byte:
    mov ax, 0
    jmp draw_memory

draw_memory:
	push bp
	mov bp, sp
	
	sub sp, 10

.pos equ -2
.count equ 4

    PUSH_NV

    mov word [bp + .pos], (6 << 8) | 4
    mov di, ax ; di, 1 is word size, 0 is byte

	mov ds, [bp + 8] ; 1st argument
	mov si, [bp + 6] ; 2nd argument

    mov ax, [bp + .pos]
    call set_text_pos

    add word [bp + .pos], 2

    print `^0MEMORY %x:%x`, ds, si

.line_loop:
    mov ax, [bp + .pos]
    call set_text_pos

    mov ax, si
    push cs
    push .addr_str
    call print_string

    cmp di, 0
    jne .word_line

.byte_line:
    mov bx, 8
.byte_loop:
    lodsb
    push cs
    push .hex_byte_str
    call print_string
    dec word [bp + .count]
    jz .early_out
    dec bx
    jnz .byte_loop
    jmp .end_line

.word_line:
    mov bx, 4
.word_loop:
    lodsw
    push cs
    push .hex_word_str
    call print_string
    dec word [bp + .count]
    jz .early_out
    dec bx
    jnz .word_loop

.end_line:
    inc word [bp + .pos]
    jmp .line_loop 

.early_out:
    POP_NV

    add sp, 10

    pop bp
    ret 6

.addr_str: db "%l:", 0
.hex_word_str: db " %x", 0
.hex_byte_str: db " %l", 0



section .bss
    alignb 2
	text_buffer: resw 1200 ; 40 x 30
	text_base: resw 1
	text_x: resb 1
	text_y: resb 1
	text_color: resb 1


%endif ; TEST_ASM
