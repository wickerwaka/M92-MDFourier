%ifndef UTILS_ASM
%define UTILS_ASM

%macro  multipush 1-*
        %rep  %0
              push    %1
        %rotate 1
        %endrep
%endmacro

%macro  multipop 1-*
        %rep %0
        %rotate -1
              pop     %1
        %endrep
%endmacro

%define PUSH_ALL multipush ax, bx, cx, dx, ds, es, si, di
%define POP_ALL multipop ax, bx, cx, dx, ds, es, si, di

%define PUSH_NV multipush bx, ds, es, si, di
%define POP_NV multipop bx, ds, es, si, di

%define addr32(seg,offset) (((seg) << 16) + (offset))
%define addr20(seg,offset) (((seg) << 4) + (offset))

%endif ; UTILS_ASM