CPU 186
BITS 16
ORG 0

CODE_SEG equ 0x0000
DATA_SEG equ 0x0000

IDB equ 0xfff
PRC equ 0xfeb
PMC1 equ 0xf0a
EXIC0 equ 0xf4c
EXIC1 equ 0xf4d
EXIC2 equ 0xf4e
RFM equ 0xfe1
WTC equ 0xfe8

;
; DEFINE SECTIONS
; Must come first in this file, no includes before it


; Code, 32KB max, accessed via CS or CODE_SEG. Near calls only
section .text start=0 vstart=0
; Read only data, 32KB max, accessed via CS: or DATA_SEG
section .data start=0x8000 vstart=0x8000
; RAM. Uninitialized. Accessed via RAM_SEG or SS:
section .bss start=0xa0000

; VECTOR TABLE MUST COME FIRST
section .text
	dd 24 dup (generic_handler)
	dd p0_handler
	dd p1_handler
	dd (256 - 26) dup (generic_handler)

;
; MODULES
;

%include "src/util.asm"

;
; MAIN ENTRYPOINT
;
section .text
entry:
	mov ax, 0xa000
	mov ss, ax
	mov ds, ax
	mov sp, stack_start

	call config_system
	mov byte [cmd_write_pos], 0
	sti
	
	;mov al, 1
	;call execute_sequence

.cmd_wait:
	cmp byte [cmd_write_pos], 3
	jl .cmd_wait

	cli

	mov al, [cmd_buf] ; cmd

	mov bh, 0x80
	mov bl, [cmd_buf + 1] ; addr
	
	mov dl, [cmd_buf + 2] ; value
	
	cmp al, 0
	je .read

	cmp bl, 0xff
	jne .write

	; do ym2151
	mov [0x8046], dl ; write response
	mov byte [cmd_write_pos], 0
	sti

	mov al, dl
	call execute_sequence
	jmp .cmd_wait


.write:
	mov [bx], dl
	jmp .finish

.read:
	mov dl, [bx]

.finish:
	mov [0x8046], dl ; write response

	mov byte [cmd_write_pos], 0
	sti
	
	jmp .cmd_wait


execute_sequence:
	call ym_init

	call wait_vblank
	call wait_vblank
	call wait_vblank

	call execute_start_tone

	call wait_vblank
	call wait_vblank

	call execute_pulse_train
	call execute_silence
	test al, 0x2
	jz .skip_fm
	call execute_fm
.skip_fm:
	test al, 0x1
	jz .skip_pcm
	call pcm_play
.skip_pcm:
	call execute_silence
	call execute_pulse_train

	call ym_keyoff
	ret


config_system:
	push ds
	mov ax, 0xff00 ; default IDB
	mov ds, ax
	mov ax, 0x9f00
	mov [IDB], ah
	mov ds, ax ; new IDB

	mov byte [PRC], 0x4c
	mov byte [PMC1], 0x80

	mov byte [EXIC0], 0x47
	mov byte [EXIC1], 0x07
	mov byte [EXIC2], 0x47

	mov byte [RFM], 0x00
	mov word [WTC], 0x5555

	mov byte [PRC], 0x0c

	pop ds
	ret

wait_vblank:
	push ax
	mov al, ss:[vblank_count]
.loop:
	cmp al, ss:[vblank_count]
	je .loop
	
	pop ax
	ret

%macro  ym_write_channel 3
	mov dl, %3
	mov dh, %2
	or dh, %1
	call ym_write
%endmacro

; dh - reg address, dl - reg value
ym_write:
	push ds
	push ax
	mov ax, 0xa800
	mov ds, ax

.wait_1:
	mov al, [0x42]
	test al, 0x80
	jnz .wait_1

	mov [0x40], dh

.wait_2:
	mov al, [0x42]
	test al, 0x80
	jnz .wait_2

	mov [0x42], dl

	pop ax
	pop ds

	ret

pcm_play:
	PUSH_ALL
	mov ax, 0xa800
	mov ds, ax
	mov byte [0x00], 1
	mov byte [0x02], 0
	mov byte [0x04], 0xff
	mov byte [0x06], 0xff
	mov byte [0x08], 0xc7
	mov byte [0x0a], 0x3f

	call wait_vblank

	mov byte [0x0c], 0x02

	mov cx, 1075
.delay:
	call wait_vblank
	loop .delay

	mov byte [0x0c], 0x00

	POP_ALL
	ret

; channel in al
ym_loadchannel:
	push dx ;
	ym_write_channel al, 0x38, 0x00
	ym_write_channel al, 0x40, 0x04
	ym_write_channel al, 0x48, 0x04
	ym_write_channel al, 0x50, 0x04
	ym_write_channel al, 0x58, 0x04
	ym_write_channel al, 0x60, 0x00
	ym_write_channel al, 0x68, 0x00
	ym_write_channel al, 0x70, 0x00
	ym_write_channel al, 0x78, 0x00
	ym_write_channel al, 0x80, 0x5f
	ym_write_channel al, 0x88, 0x1f
	ym_write_channel al, 0x90, 0x1f
	ym_write_channel al, 0x98, 0x1f
	ym_write_channel al, 0xa0, 0x1f
	ym_write_channel al, 0xa8, 0x1f
	ym_write_channel al, 0xb0, 0x1f
	ym_write_channel al, 0xb8, 0x1f
	ym_write_channel al, 0xc0, 0x00
	ym_write_channel al, 0xc8, 0x00
	ym_write_channel al, 0xd0, 0x00
	ym_write_channel al, 0xd8, 0x00
	ym_write_channel al, 0xe0, 0x0f
	ym_write_channel al, 0xe8, 0x0f
	ym_write_channel al, 0xf0, 0x0f
	ym_write_channel al, 0xf8, 0x0f
	ym_write_channel al, 0x20, 0xc7
	ym_write_channel al, 0x28, 0x6c

	pop dx
	ret

ym_init:
	push dx
	push ax

	mov dx, 0x0102
	call ym_write

	mov dx, 0x0f00
	call ym_write

	mov dx, 0x1400
	call ym_write

	mov dx, 0x1800
	call ym_write

	mov dx, 0x1900
	call ym_write

	mov dx, 0x1b01
	call ym_write

	mov al, 0
	call ym_loadchannel
	mov al, 1
	call ym_loadchannel
	mov al, 2
	call ym_loadchannel
	mov al, 3
	call ym_loadchannel
	mov al, 4
	call ym_loadchannel
	mov al, 5
	call ym_loadchannel
	mov al, 6
	call ym_loadchannel
	mov al, 7
	call ym_loadchannel

	pop ax
	pop dx
	ret

; channel in al
ym_keyoff:
	push dx
	mov dl, al
	and dl, 0x07
	mov dh, 0x08
	call ym_write
	pop dx
	ret

ym_keyoff_all:
	PUSH_ALL
	mov cx, 8
	mov al, 0

.loop:
	call ym_keyoff
	inc al
	loop .loop

	POP_ALL
	ret

; al - channel
; ah - octave | note
ym_play:
	push dx
	call ym_keyoff
	mov dh, al
	or dh, 0x20
	mov dl, 0xc7

	call ym_write

	mov dh, al
	or dh, 0x28
	mov dl, ah
	call ym_write

	mov dx, 0x0878
	or dl, al
	call ym_write

	pop dx
	ret


execute_start_tone:
	PUSH_ALL
	mov cx, 20

	mov ax, 0x2800
	call ym_play

.loop:
	call wait_vblank
	loop .loop

	mov ax, 0x0000	
	call ym_keyoff

	POP_ALL
	ret

execute_pulse_train:
	PUSH_ALL
	mov cx, 10

	; reset freqs
	mov dx, 0x20c7
	call ym_write
	mov dx, 0x286c
	call ym_write

.loop:
	mov dx, 0x0878
	call ym_write
	call wait_vblank
	
	mov dx, 0x0800
	call ym_write
	call wait_vblank

	loop .loop

	POP_ALL
	ret

execute_silence:
	PUSH_ALL
	mov cx, 20
.loop:
	call wait_vblank
	loop .loop

	POP_ALL
	ret


execute_fm:
	PUSH_ALL

	xor ax, ax ; ah is note, al is channel
.note_loop:
	mov al, ah
	and al, 0x07
	call ym_play

	mov cx, 20
.wait_loop:
	cmp cx, 4
	jne .keep_playing
	call ym_keyoff

.keep_playing:
	call wait_vblank
	loop .wait_loop

	inc ah
	cmp ah, 128
	jne .note_loop

	call ym_keyoff_all

	POP_ALL
	ret


align 4
p0_handler:
	nop
	nop
	nop
	nop
	db 0x0f, 0x92 ; FINI
	iret

align 4
p1_handler:
	push ax
	push bx
	xor bh, bh
	mov bl, ss:[cmd_write_pos]
	mov al, ss:[0x8044]
	cmp al, 0xff
	jne .not_vblank
	cmp bl, 0x00
	jne .not_vblank
	inc byte ss:[vblank_count]
	jmp .not_cmd

.not_vblank:
	mov ss:[cmd_buf + bx], al
	inc bl
	mov ss:[cmd_write_pos], bl

.not_cmd:
	mov ss:[0x8044], al
	pop bx
	pop ax
	db 0x0f, 0x92 ; FINI
	iret

align 4
generic_handler:
	nop
	iret

;
; RAM accessed via DATA_SEG or ss:
;
section .bss
alignb 2
cmd_buf: resb 256
cmd_write_pos: resb 1
vblank_count: resb 1


stack: resb 256
stack_start:


;
; V35 STARTUP
;

section .text_start start=0x1fff0 vstart=0
startup:
	cli
	jmp CODE_SEG:entry
	db 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0




