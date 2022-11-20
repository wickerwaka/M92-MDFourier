CPU 186
BITS 16
ORG 0

%include "src/constants.asm"
%include "src/util.asm"

;
; DEFINE SECTIONS
;

; Code, 32KB max, accessed via CS or CODE_SEG. Near calls only
section .text start=addr20(CODE_SEG,0) vstart=0
; Read only data, 32KB max, accessed via CS: or DATA_SEG
section .data start=addr20(CODE_SEG,0x8000) vstart=0x8000
; RAM. Uninitialized. Accessed via RAM_SEG or SS:
section .bss start=0xe0000

; VECTOR TABLE MUST COME FIRST
section .text
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, vblank_handler)
	dd addr32(CODE_SEG, dma_done_handler)
	dd addr32(CODE_SEG, hint_handler)
	dd addr32(CODE_SEG, unknown_handler)
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, generic_handler)
	dd addr32(CODE_SEG, generic_handler)


;
; MODULES
;

%include "src/text.asm"

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


.frame_loop:
	mov ax, 0
	call set_text_pos

	push DATA_SEG
	push st_status_line
	mov ax, ss:[vblank_count]
	mov cx, ss:[p1_p2]
	call print_string

	mov ax, 10 << 8 | 10
	call set_text_pos

	push DATA_SEG
	push st_hello_world
	call print_string

	jmp .frame_loop


	jmp $




configure_pic:
	mov al, 0x13
	out 0x40, al
	mov al, 0x08
	out 0x42, al
	mov al, 0x0f
	out 0x42, al
	mov al, 0xf2
	out 0x42, al

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

; ax - return contents of videocontrol
get_videocontrol:
	push ds
	mov ax, VIDEO_SEG
	mov ds, ax
	mov ax, ds:[REG_VIDEOCONTROL]
	pop ds

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

	in ax, 0x00
	mov [p1_p2], ax

	call copy_text_buffer
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

st_hello_world: db `^1HELLO WORLD^0!\n`, 0
st_status_line: db `^3FRAME COUNT: ^0%x   ^3INPUT: ^0%x\n`, 0

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

;
; M92 STARTUP
;

section .text_start start=addr20(STARTUP_SEG, 0) vstart=0
startup:
	cli
	jmp CODE_SEG:entry
	db 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0





