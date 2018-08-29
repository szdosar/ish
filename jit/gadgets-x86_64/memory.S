#include "gadgets.h"
#include "emu/interrupt.h"

.gadget push
    sub $4, %_esp
    movl %_esp, %_addr
    write_prep 32
    movl %_tmp, (%_addrq)
    write_done 32
    gret 1
.gadget pop
    movl %_esp, %_addr
    read_prep 32
    movl (%_addrq), %_tmp
    add $4, %_esp
    gret 1

.macro x name, reg
    .gadget addr_\name
        movl %\reg, %_addr
        addl (%_ip), %_addr
        gret 1
.endm
.each_reg x
.purgem x
.gadget addr_none
    movl (%_ip), %_addr
    gret 1
.gadget_list addr, REG_LIST

.macro x name, reg
    .irp times, 1,2,4,8
        .gadget si_\name\()_\times
            .ifnc \reg,esp
                leal (%_addr,%\reg,\times), %_addr
            .else
                leal (%_addr,%_esp,\times), %_addr
            .endif
            gret
    .endr
.endm
.each_reg x
.purgem x

.section .rodata
.global si_gadgets
si_gadgets:
.irp reg, REG_LIST
    .irp times, 1,2,4,8
        .quad gadget_si_\reg\()_\times
    .endr
.endr
.previous

.gadget seg_gs
    addl CPU_tls_ptr(%_cpu), %_addr
    gret

.irp type, read,write
    .global handle_\type\()_miss
    handle_\type\()_miss:
        save_c
        # %tlb actually points to tlb->entries
        leaq -TLB_entries(%_tlb), %rdi
        movl %_addr, %esi
        .ifc \type,read
            movq $0, %rdx
        .else
            movq $1, %rdx
        .endif
        call tlb_handle_miss
        movq %rax, %r15
        restore_c
        testq %r15, %r15
        jz segfault
        movq %r15, %_addrq
        ret
.endr

segfault:
    movl (%_ip), %_eip
    movl $INT_GPF, %_tmp
    jmp jit_exit

.global crosspage_load
crosspage_load:
    save_c
    leaq -TLB_entries(%_tlb), %rdi
    movl %_addr, %esi
    leaq LOCAL_value(%_cpu), %rdx
    movq %r14, %rcx
    call __tlb_read_cross_page
    movq %rax, %r14
    restore_c
    testq %rax, %rax
    jz segfault
    movl %_addr, LOCAL_value_addr(%_cpu)
    leaq LOCAL_value(%_cpu), %_addrq
    ret

.global crosspage_store
crosspage_store:
    save_c
    leaq -TLB_entries(%_tlb), %rdi
    movl LOCAL_value_addr(%_cpu), %esi
    leaq LOCAL_value(%_cpu), %rdx
    movq %r14, %rcx
    call __tlb_write_cross_page
    movq %rax, %r14
    restore_c
    testq %rax, %rax
    jz segfault
    ret