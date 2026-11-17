//LAB4 function3 2413633
.text
.globl switch_to
switch_to:
    # void switch_to(struct context *from, struct context *to)
    # a0 = from (old process's context), a1 = to (new process's context)

    # save the 14 callee-saved registers of the old process:
    # ra, sp, s0-s11 (struct context layout: ra, sp, s0, ..., s11)
    sd ra, 0*8(a0)
    sd sp, 1*8(a0)
    sd s0, 2*8(a0)
    sd s1, 3*8(a0)
    sd s2, 4*8(a0)
    sd s3, 5*8(a0)
    sd s4, 6*8(a0)
    sd s5, 7*8(a0)
    sd s6, 8*8(a0)
    sd s7, 9*8(a0)
    sd s8, 10*8(a0)
    sd s9, 11*8(a0)
    sd s10, 12*8(a0)
    sd s11, 13*8(a0)

    # restore the 14 callee-saved registers of the new process
    ld ra, 0*8(a1)
    ld sp, 1*8(a1)
    ld s0, 2*8(a1)
    ld s1, 3*8(a1)
    ld s2, 4*8(a1)
    ld s3, 5*8(a1)
    ld s4, 6*8(a1)
    ld s5, 7*8(a1)
    ld s6, 8*8(a1)
    ld s7, 9*8(a1)
    ld s8, 10*8(a1)
    ld s9, 11*8(a1)
    ld s10, 12*8(a1)
    ld s11, 13*8(a1)

    # return to the new process's context.ra (forkret for a new thread)
    ret
