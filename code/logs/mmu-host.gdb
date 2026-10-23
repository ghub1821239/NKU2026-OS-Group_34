set pagination off
set confirm off
set debuginfod enabled off
set print thread-events off
set startup-with-shell off
handle SIGPIPE nostop noprint pass
set trace-commands on
break get_physical_address if addr == 0x80200000 && mmu_idx == 1 && access_type == 2 && env->satp == 0
run
printf "\nPHASE: Bare-mode instruction fetch\n"
bt 5
p/x addr
p/x env->satp
until /home/huang/OS/tools/qemu-4.1.1/target/riscv/cpu_helper.c:197
next
p/x *physical
finish
break tlb_set_page if vaddr == 0x80200000 && mmu_idx == 1
continue
printf "\nPHASE: Software TLB fill also happens in Bare mode\n"
p/x vaddr
p/x paddr
p mmu_idx
delete breakpoints
break load_helper if addr == 0xffffffffc2200000
continue
printf "\nPHASE: DTB load and software TLB miss\n"
bt 6
p/x addr
until /home/huang/OS/tools/qemu-4.1.1/accel/tcg/cputlb.c:1271
p/x tlb_addr
p/x entry->addr_read
p/x addr & ~0xfffUL
delete breakpoints
break get_physical_address if addr == 0xffffffffc2200000 && access_type == 0
continue
printf "\nPHASE: Sv39 page-table walk\n"
bt 6
p/x env->satp
p/x addr
p access_type
p mmu_idx
until /home/huang/OS/tools/qemu-4.1.1/target/riscv/cpu_helper.c:237
p levels
p ptidxbits
p ptesize
p/x base
p ptshift
until /home/huang/OS/tools/qemu-4.1.1/target/riscv/cpu_helper.c:254
p i
p/x idx
p/x pte_addr
p/x pte
next
p/x ppn
until /home/huang/OS/tools/qemu-4.1.1/target/riscv/cpu_helper.c:334
p ptshift
next
p/x *physical
finish
p/x pa
delete breakpoints
break tlb_set_page if vaddr == 0xffffffffc2200000
continue
printf "\nPHASE: Fill virtual/physical mapping and host addend\n"
p/x vaddr
p/x paddr
p prot
p mmu_idx
step
until /home/huang/OS/tools/qemu-4.1.1/accel/tcg/cputlb.c:804
p/x addend
p/x vaddr_page
next
p/x tn.addend
until /home/huang/OS/tools/qemu-4.1.1/accel/tcg/cputlb.c:836
p/x tn.addr_read
p/x tn.addr_code
p/x tn.addend
next
p/x te->addr_read
p/x te->addend
delete breakpoints
break /home/huang/OS/tools/qemu-4.1.1/accel/tcg/cputlb.c:1030 if addr >= 0xffffffffc0200000 && addr < 0xffffffffc0201000 && env->priv == 1
continue
printf "\nPHASE: Direct-mapped TLB collision and victim-cache recovery\n"
p/x addr
p/x entry->addr_code
p/x entry->addend
printf "TLB_DIRECT_HIT=%d\n", entry->addr_code == (addr & ~0xfffUL)
next
next
p/x entry->addr_code
until /home/huang/OS/tools/qemu-4.1.1/accel/tcg/cputlb.c:1051
next
p/x p
delete breakpoints
break /home/huang/OS/tools/qemu-4.1.1/accel/tcg/cputlb.c:1030 if addr >= 0xffffffffc0200000 && addr < 0xffffffffc0201000 && env->priv == 1 && entry->addr_code == (addr & ~0xfffUL)
continue
printf "\nPHASE: Real instruction TLB hit\n"
p/x addr
p/x entry->addr_code
printf "TLB_DIRECT_HIT=%d\n", entry->addr_code == (addr & ~0xfffUL)
next
until /home/huang/OS/tools/qemu-4.1.1/accel/tcg/cputlb.c:1051
next
p/x p
printf "\nPHASE: Trace complete; return control to guest GDB\n"
detach
quit
