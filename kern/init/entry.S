#include <mmu.h>
#include <memlayout.h>

    .section .text,"ax",%progbits
    .globl kern_entry
kern_entry:
    # a0: hartid 硬件线程编号
    # a1: dtb physical address 设备树二进制文件的物理地址
    # save hartid and dtb address
    # t0 = $boot_hartid
    la t0, boot_hartid
    # sd:store 
    # *boot_hartid = a0(hardid)
    sd a0, 0(t0)
    la t0, boot_dtb
    # *boot_dtb = a1(dtb paddr)
    sd a1, 0(t0)

    # boot_page_table_sv39：整张页表起始位置的地址
    # t0 := 三级页表的虚拟地址

    # lui -> LA 的 lu12 i20<<12  lui 强制要求用 31 位把 63:32 填充！！
    # 为了减少指令方便理解，本次实验中似乎都是用的 lui 去复制，所以呢也就只能拼接出 0000/FFFF 两种地址
    # 而我们内核的地址设计的很巧妙 0xFFFFFFFFC0200000
    # 内核里所有符号的 [63:31] 位天然全是 1，一条 lui 就能让硬件自动补齐高 32 位。
    # 工业里也常这样使用，也就是说现在只有 30:0 可以自由配置，内核放置在 虚拟地址空间 的最高 2GB 范围

    # %hi: 取[31:12],再根据第 11 位决定是否加一（==1 就加）
    lui     t0, %hi(boot_page_table_sv39)
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    # imm存入reg
    # OpenSBI 固件的Vaddr-Paddr 做了简化，线性映射了
    li      t1, 0xffffffffc0000000 - 0x80000000
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
    # t0 >>= 12，变为三级页表的物理页号
    # srli rd, rs1, shamt 
    # rd -> rs1>>shamt 高位补 0
    srli    t0, t0, 12

    # t0 现在存储的是boot_page_table_sv39物理页号

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39 1000
    li      t1, 8 << 60
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中

    # satp 寄存器的唯一作用：告诉 CPU 硬件，页表放在物理内存的哪一页。
    # 63      60 59          44 43                        0
    # +---------+--------------+---------------------------+
    # |  MODE   |     ASID     |            PPN            |
    # | (高4位)  |  (中间16位)   |          (低44位)         |
    # +---------+--------------+---------------------------+
    
    or      t0, t0, t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
    addi t0, t0, %lo(kern_init)
    jr t0

# 1. 声明是.data这个数据段
.section .data
    # .align 2^12
    # 单次对齐2^12(只作用一次)
    .align PGSHIFT

# 标记 1 可以全局访问
    .global bootstack
# 对应标记1（相当于当前对应的 addr 叫做 bootstack 完成名-地址对应）
bootstack:
    # 2 * PGSHIFT = 8KB
    # 两个标记的中间部分留下的8KB作为栈
    .space KSTACKSIZE

# 标记 2 可以全局访问
    .global bootstacktop
# 这里叫做标记 2 对应上 addr
bootstacktop:

.section .data
    # 由于我们要把这个页表放到一个页里面，因此必须 12 位对齐
    .align PGSHIFT

    .global boot_page_table_sv39
# 分配 4KiB 内存给预设的三级页表
boot_page_table_sv39:
    # 0xffffffff_c0000000 map to 0x80000000 (1G)
    # 前 511 个页表项均设置为 0 ，因此 V=0 ，意味着是空的(unmapped)
    .zero 8 * 511
    # 设置最后一个页表项，PPN=0x80000，标志位 VRWXAD 均为 1
    .quad (0x80000 << 10) | 0xcf # VRWXAD

    .global boot_hartid
boot_hartid:
    .quad 0
    .global boot_dtb
boot_dtb:
    .quad 0
