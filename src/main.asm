CPU 186
BITS 16
ORG 0

;
; DEFINE SECTIONS
; Must come first in this file, no includes before it

; Code, 32KB max, accessed via CS or CODE_SEG. Near calls only
section .text start=0 vstart=0
; Read only data, 32KB max, accessed via CS: or DATA_SEG
section .data start=0x8000 vstart=0x8000
; RAM. Uninitialized. Accessed via RAM_SEG or SS:
section .bss start=0xe0000

; VECTOR TABLE MUST COME FIRST
section .text
	dd generic_handler
	dd generic_handler
	dd generic_handler
	dd generic_handler
	dd generic_handler
	dd generic_handler
	dd generic_handler
	dd generic_handler
	dd vblank_handler
	dd dma_done_handler
	dd hint_handler
	dd unknown_handler
	dd generic_handler
	dd generic_handler
	dd generic_handler
	dd generic_handler



;
; MODULES
;

%include "src/constants.asm"
%include "src/util.asm"

%include "src/text.asm"
%include "src/comms.asm"
%include "src/cmd.asm"

;
; MAIN ENTRYPOINT
;
section .text
entry:
	mov ax, DATA_SEG
	mov ds, ax

	mov ax, RAM_SEG
	mov ss, ax
	mov es, ax

	; clear ram
	xor ax, ax
	xor di, di
	mov cx, 0x8000
	rep stosw

	mov sp, 0x0000

	call configure_pic

	mov ax, pal_white
	mov cx, 0
	call load_palette

	mov ax, pal_red
	mov cx, 1
	call load_palette

	mov ax, pal_green
	mov cx, 2
	call load_palette

	mov ax, pal_blue
	mov cx, 3
	call load_palette

	mov ax, 0x2000
	call set_videocontrol

	mov ax, 0
	call enable_pf
	mov ax, 0
	mov cx, -80
	mov dx, -136
	call set_pf_xy
	mov ax, 1
	call disable_pf
	mov ax, 2
	call disable_pf

	mov ax, 0
	mov es:[text_base], ax

	; Enable interrupts
	sti

	jmp main_process


section .bss
prev_vblank: resw 1
state: resb 1

ST_WAITING equ 0

section .text

wait_vblank:
	mov ax, ss:[vblank_count]
	cmp ss:[prev_vblank], ax
	je wait_vblank
	mov ss:[prev_vblank], ax
	ret

main_process:
	mov byte ss:[state], 0
.main_loop:
	call wait_vblank

	cli
	call comms_next_cmd ; al contains cmd
	sti

	xor bx, bx
	mov bl, al
	shl bl, 1
	mov bx, cs:[cmd_table + bx]
	call bx

.frame_done:
	print_at 2, 2, `^3FRAME COUNT: ^0%x   ^3INPUT: ^0%x`, ss:[vblank_count], ss:[p3_p4]

	print_at 2, 26, `^3COMMS INDEX: ^0%x   ^3COMMS LEN: ^0%x`, ss:[comms_index], ss:[comms_len]

	jmp .main_loop

	jmp $

section .data
alignb 2
fake_comms:
	;dw 0x0100, fake_comms_1_begin, fake_comms_1_end
	;dw 0x0200, fake_comms_2_begin, fake_comms_2_end
fake_comms_end:

fake_comms_1_begin:
	db CMD_WRITE_BYTES
	dw 0x0008, RAM_SEG, 0x8000, 0xcbcb, 0xcbcb 
fake_comms_1_end:

fake_comms_2_begin:
	db CMD_CALL
	dw 0x0004, 0x8000, RAM_SEG
fake_comms_2_end:

section .text

do_fake_comms:
	PUSH_NV

	mov ax, DATA_SEG
	mov ds, ax
	mov ax, RAM_SEG
	mov es, ax
	mov si, fake_comms

	mov dx, es:[vblank_count]
	cmp si, fake_comms_end
	jge .return
	
.loop:
	lodsw
	cmp ax, dx
	je .load_fake
	add si, 4
	jmp .loop

.load_fake:
	push ds
	lodsw
	push ax
	lodsw
	push ax
	call comms_load_fake

.return:
	POP_NV
	ret

configure_pic:
	mov al, 0x13
	out 0x40, al
	mov al, 0x08
	out 0x42, al
	mov al, 0x0f
	out 0x42, al
	mov al, 0xf2
	out 0x42, al
	ret

; ds:ax - palette addr
; cx - palette index
load_palette:
	multipush es, si, di
	mov dx, VIDEO_SEG
	mov es, dx
	mov si, ax
	mov di, cx
	shl di, 5
	add di, 0x8800
	mov cx, 0x10
	repnz movsw
	multipop es, si, di

	ret

; ax - new videocontrol value
set_videocontrol:
	push ds
	mov cx, VIDEO_SEG
	mov ds, cx
	mov ds:[REG_VIDEOCONTROL], ax
	pop ds
	ret

; ax - return contents of videocontrol
get_videocontrol:
	push ds
	mov ax, VIDEO_SEG
	mov ds, ax
	mov ax, ds:[REG_VIDEOCONTROL]
	pop ds
	ret

disable_pf:
	and ax, 3
	shl ax, 1
	add ax, 0x98
	mov dx, ax
	mov ax, 0x10
	out dx, ax
	ret

enable_pf:
	and ax, 3
	shl ax, 1
	add ax, 0x98
	mov dx, ax
	mov ax, 0x00
	out dx, ax
	ret

; ax - pf
; cx - x offset
; dx - y offset
set_pf_xy:
	push bx
	mov bx, dx
	and ax, 3
	shl ax, 3
	add ax, 0x80
	mov dx, ax
	mov ax, bx
	out dx, ax
	add dx, 0x4
	mov ax, cx
	out dx, ax
	pop bx
	ret

align 4
vblank_handler:
	PUSH_ALL
	mov ax, RAM_SEG
	mov ds, ax
	inc word ds:[vblank_count]

	call comms_read

	;call do_fake_comms

	in ax, 0x00
	mov [p1_p2], ax
	in ax, 0x06
	mov [p3_p4], ax

	call copy_text_buffer

	mov ax, VIDEO_SEG
	mov es, ax
	mov di, 0x9008
	mov es:[di], word 0

	POP_ALL
	iret

align 4
hint_handler:
	iret

align 4
dma_done_handler:
	iret

align 4
unknown_handler:
	iret

align 4
generic_handler:
	iret

section .data
alignb 2
base_palette:
	dw 0x0000, 0x3d80, 0x3100, 0x2420
	dw 0x233c, 0x2b1c, 0x0e16, 0x5f59
	dw 0x0114, 0x322c, 0x2500, 0x2653
	dw 0x3e30, 0x01f1, 0x0000, 0x0000

pal_white: dw 0x0000, 14 dup ( 0x7fff ), 0x0000
pal_red: dw 0x0000, 14 dup ( 0x1f << 0 ), 0x0000
pal_green: dw 0x0000, 14 dup ( 0x1f << 5 ), 0x0000
pal_blue: dw 0x0000, 14 dup ( 0x1f << 10 ), 0x0000


;
; RAM accessed via DATA_SEG or ss:
;
section .bss
	alignb 2
	vblank_count: resw 1
	p1_p2: resw 1
	p3_p4: resw 1

;
; M92 STARTUP
;

section .text_start start=addr20(STARTUP_SEG, 0) vstart=0
startup:
	cli
	jmp CODE_SEG:entry
	db 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0




