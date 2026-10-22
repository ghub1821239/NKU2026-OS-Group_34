
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
kern_entry:
    # a0: hartid 硬件线程编号
    # a1: dtb physical address 设备树二进制文件的物理地址
    # save hartid and dtb address
    # t0 = $boot_hartid
    la t0, boot_hartid
ffffffffc0200000:	00008297          	auipc	t0,0x8
ffffffffc0200004:	00028293          	mv	t0,t0
    # sd:store 
    # *boot_hartid = a0(hardid)
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0208000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00008297          	auipc	t0,0x8
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0208008 <boot_dtb>
    # *boot_dtb = a1(dtb paddr)
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)
    # 而我们内核的地址设计的很巧妙 0xFFFFFFFFC0200000
    # 内核里所有符号的 [63:31] 位天然全是 1，一条 lui 就能让硬件自动补齐高 32 位。
    # 工业里也常这样使用，也就是说现在只有 30:0 可以自由配置，内核放置在 虚拟地址空间 的最高 2GB 范围

    # %hi: 取[31:12],再根据第 11 位决定是否加一（==1 就加）
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02072b7          	lui	t0,0xc0207
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    # imm存入reg
    # OpenSBI 固件的Vaddr-Paddr 做了简化，线性映射了
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    # srli rd, rs1, shamt 
    # rd -> rs1>>shamt 高位补 0
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t0 现在存储的是boot_page_table_sv39物理页号

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39 1000
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # +---------+--------------+---------------------------+
    # |  MODE   |     ASID     |            PPN            |
    # | (高4位)  |  (中间16位)   |          (低44位)         |
    # +---------+--------------+---------------------------+
    
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0207137          	lui	sp,0xc0207

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
ffffffffc0200040:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc0200044:	0d828293          	addi	t0,t0,216 # ffffffffc02000d8 <kern_init>
    jr t0
ffffffffc0200048:	8282                	jr	t0

ffffffffc020004a <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004a:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc020004c:	00003517          	auipc	a0,0x3
ffffffffc0200050:	d3c50513          	addi	a0,a0,-708 # ffffffffc0202d88 <etext+0x4>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0fe000ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00003517          	auipc	a0,0x3
ffffffffc0200066:	d4650513          	addi	a0,a0,-698 # ffffffffc0202da8 <etext+0x24>
ffffffffc020006a:	0ea000ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00003597          	auipc	a1,0x3
ffffffffc0200072:	d1658593          	addi	a1,a1,-746 # ffffffffc0202d84 <etext>
ffffffffc0200076:	00003517          	auipc	a0,0x3
ffffffffc020007a:	d5250513          	addi	a0,a0,-686 # ffffffffc0202dc8 <etext+0x44>
ffffffffc020007e:	0d6000ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00008597          	auipc	a1,0x8
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0208018 <free_area>
ffffffffc020008a:	00003517          	auipc	a0,0x3
ffffffffc020008e:	d5e50513          	addi	a0,a0,-674 # ffffffffc0202de8 <etext+0x64>
ffffffffc0200092:	0c2000ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00008597          	auipc	a1,0x8
ffffffffc020009a:	3ea58593          	addi	a1,a1,1002 # ffffffffc0208480 <end>
ffffffffc020009e:	00003517          	auipc	a0,0x3
ffffffffc02000a2:	d6a50513          	addi	a0,a0,-662 # ffffffffc0202e08 <etext+0x84>
ffffffffc02000a6:	0ae000ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00008597          	auipc	a1,0x8
ffffffffc02000ae:	7d558593          	addi	a1,a1,2005 # ffffffffc020887f <end+0x3ff>
ffffffffc02000b2:	00000797          	auipc	a5,0x0
ffffffffc02000b6:	02678793          	addi	a5,a5,38 # ffffffffc02000d8 <kern_init>
ffffffffc02000ba:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000be:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c2:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c4:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000c8:	95be                	add	a1,a1,a5
ffffffffc02000ca:	85a9                	srai	a1,a1,0xa
ffffffffc02000cc:	00003517          	auipc	a0,0x3
ffffffffc02000d0:	d5c50513          	addi	a0,a0,-676 # ffffffffc0202e28 <etext+0xa4>
}
ffffffffc02000d4:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d6:	a8bd                	j	ffffffffc0200154 <cprintf>

ffffffffc02000d8 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d8:	00008517          	auipc	a0,0x8
ffffffffc02000dc:	f4050513          	addi	a0,a0,-192 # ffffffffc0208018 <free_area>
ffffffffc02000e0:	00008617          	auipc	a2,0x8
ffffffffc02000e4:	3a060613          	addi	a2,a2,928 # ffffffffc0208480 <end>
int kern_init(void) {
ffffffffc02000e8:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ea:	8e09                	sub	a2,a2,a0
ffffffffc02000ec:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ee:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f0:	07b020ef          	jal	ra,ffffffffc020296a <memset>
    // 检查 boot_dtb 是否非空且正确
    // 把物理内存的起点和大小取出来，存进全局变量 memory_base 和 memory_size 里
    // 方便通过 get_memory_base & get_memory_size 访问
    dtb_init();
ffffffffc02000f4:	188000ef          	jal	ra,ffffffffc020027c <dtb_init>
    // OpenSBI 在跳转到我们的 entry.S 之前，早就把串口控制台（Console / UART）的硬件初始化好了。
    // 原因是因为在 x86 中没有 openSBI 这种固件，就需要自己在 cons_init() 里写一堆初始化显卡和串口的代码。
    cons_init();  // init the console
ffffffffc02000f8:	47a000ef          	jal	ra,ffffffffc0200572 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00003517          	auipc	a0,0x3
ffffffffc0200100:	d5c50513          	addi	a0,a0,-676 # ffffffffc0202e58 <etext+0xd4>
ffffffffc0200104:	086000ef          	jal	ra,ffffffffc020018a <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	4fa000ef          	jal	ra,ffffffffc0200606 <pmm_init>

    #ifdef ucore_test
        test_buddy_system();
ffffffffc0200110:	67e010ef          	jal	ra,ffffffffc020178e <test_buddy_system>
        slub_check();
ffffffffc0200114:	46c020ef          	jal	ra,ffffffffc0202580 <slub_check>
    #endif

    /* do nothing */
    while (1)
ffffffffc0200118:	a001                	j	ffffffffc0200118 <kern_init+0x40>

ffffffffc020011a <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc020011a:	1141                	addi	sp,sp,-16
ffffffffc020011c:	e022                	sd	s0,0(sp)
ffffffffc020011e:	e406                	sd	ra,8(sp)
ffffffffc0200120:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc0200122:	452000ef          	jal	ra,ffffffffc0200574 <cons_putc>
    (*cnt) ++;
ffffffffc0200126:	401c                	lw	a5,0(s0)
}
ffffffffc0200128:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc020012a:	2785                	addiw	a5,a5,1
ffffffffc020012c:	c01c                	sw	a5,0(s0)
}
ffffffffc020012e:	6402                	ld	s0,0(sp)
ffffffffc0200130:	0141                	addi	sp,sp,16
ffffffffc0200132:	8082                	ret

ffffffffc0200134 <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc0200134:	1101                	addi	sp,sp,-32
ffffffffc0200136:	862a                	mv	a2,a0
ffffffffc0200138:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020013a:	00000517          	auipc	a0,0x0
ffffffffc020013e:	fe050513          	addi	a0,a0,-32 # ffffffffc020011a <cputch>
ffffffffc0200142:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc0200144:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc0200146:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200148:	0a1020ef          	jal	ra,ffffffffc02029e8 <vprintfmt>
    return cnt;
}
ffffffffc020014c:	60e2                	ld	ra,24(sp)
ffffffffc020014e:	4532                	lw	a0,12(sp)
ffffffffc0200150:	6105                	addi	sp,sp,32
ffffffffc0200152:	8082                	ret

ffffffffc0200154 <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc0200154:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc0200156:	02810313          	addi	t1,sp,40 # ffffffffc0207028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc020015a:	8e2a                	mv	t3,a0
ffffffffc020015c:	f42e                	sd	a1,40(sp)
ffffffffc020015e:	f832                	sd	a2,48(sp)
ffffffffc0200160:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200162:	00000517          	auipc	a0,0x0
ffffffffc0200166:	fb850513          	addi	a0,a0,-72 # ffffffffc020011a <cputch>
ffffffffc020016a:	004c                	addi	a1,sp,4
ffffffffc020016c:	869a                	mv	a3,t1
ffffffffc020016e:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc0200170:	ec06                	sd	ra,24(sp)
ffffffffc0200172:	e0ba                	sd	a4,64(sp)
ffffffffc0200174:	e4be                	sd	a5,72(sp)
ffffffffc0200176:	e8c2                	sd	a6,80(sp)
ffffffffc0200178:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc020017a:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc020017c:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020017e:	06b020ef          	jal	ra,ffffffffc02029e8 <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc0200182:	60e2                	ld	ra,24(sp)
ffffffffc0200184:	4512                	lw	a0,4(sp)
ffffffffc0200186:	6125                	addi	sp,sp,96
ffffffffc0200188:	8082                	ret

ffffffffc020018a <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc020018a:	1101                	addi	sp,sp,-32
ffffffffc020018c:	e822                	sd	s0,16(sp)
ffffffffc020018e:	ec06                	sd	ra,24(sp)
ffffffffc0200190:	e426                	sd	s1,8(sp)
ffffffffc0200192:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc0200194:	00054503          	lbu	a0,0(a0)
ffffffffc0200198:	c51d                	beqz	a0,ffffffffc02001c6 <cputs+0x3c>
ffffffffc020019a:	0405                	addi	s0,s0,1
ffffffffc020019c:	4485                	li	s1,1
ffffffffc020019e:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc02001a0:	3d4000ef          	jal	ra,ffffffffc0200574 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc02001a4:	00044503          	lbu	a0,0(s0)
ffffffffc02001a8:	008487bb          	addw	a5,s1,s0
ffffffffc02001ac:	0405                	addi	s0,s0,1
ffffffffc02001ae:	f96d                	bnez	a0,ffffffffc02001a0 <cputs+0x16>
ffffffffc02001b0:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001b4:	4529                	li	a0,10
ffffffffc02001b6:	3be000ef          	jal	ra,ffffffffc0200574 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001ba:	60e2                	ld	ra,24(sp)
ffffffffc02001bc:	8522                	mv	a0,s0
ffffffffc02001be:	6442                	ld	s0,16(sp)
ffffffffc02001c0:	64a2                	ld	s1,8(sp)
ffffffffc02001c2:	6105                	addi	sp,sp,32
ffffffffc02001c4:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc02001c6:	4405                	li	s0,1
ffffffffc02001c8:	b7f5                	j	ffffffffc02001b4 <cputs+0x2a>

ffffffffc02001ca <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001ca:	00008317          	auipc	t1,0x8
ffffffffc02001ce:	26e30313          	addi	t1,t1,622 # ffffffffc0208438 <is_panic>
ffffffffc02001d2:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001d6:	715d                	addi	sp,sp,-80
ffffffffc02001d8:	ec06                	sd	ra,24(sp)
ffffffffc02001da:	e822                	sd	s0,16(sp)
ffffffffc02001dc:	f436                	sd	a3,40(sp)
ffffffffc02001de:	f83a                	sd	a4,48(sp)
ffffffffc02001e0:	fc3e                	sd	a5,56(sp)
ffffffffc02001e2:	e0c2                	sd	a6,64(sp)
ffffffffc02001e4:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001e6:	000e0363          	beqz	t3,ffffffffc02001ec <__panic+0x22>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001ea:	a001                	j	ffffffffc02001ea <__panic+0x20>
    is_panic = 1;
ffffffffc02001ec:	4785                	li	a5,1
ffffffffc02001ee:	00f32023          	sw	a5,0(t1)
    va_start(ap, fmt);
ffffffffc02001f2:	8432                	mv	s0,a2
ffffffffc02001f4:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001f6:	862e                	mv	a2,a1
ffffffffc02001f8:	85aa                	mv	a1,a0
ffffffffc02001fa:	00003517          	auipc	a0,0x3
ffffffffc02001fe:	c7e50513          	addi	a0,a0,-898 # ffffffffc0202e78 <etext+0xf4>
    va_start(ap, fmt);
ffffffffc0200202:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc0200204:	f51ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200208:	65a2                	ld	a1,8(sp)
ffffffffc020020a:	8522                	mv	a0,s0
ffffffffc020020c:	f29ff0ef          	jal	ra,ffffffffc0200134 <vcprintf>
    cprintf("\n");
ffffffffc0200210:	00003517          	auipc	a0,0x3
ffffffffc0200214:	c4050513          	addi	a0,a0,-960 # ffffffffc0202e50 <etext+0xcc>
ffffffffc0200218:	f3dff0ef          	jal	ra,ffffffffc0200154 <cprintf>
ffffffffc020021c:	b7f9                	j	ffffffffc02001ea <__panic+0x20>

ffffffffc020021e <fdt64_to_cpu>:
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
}

static uint64_t fdt64_to_cpu(uint64_t x) {
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
           fdt32_to_cpu(x >> 32);
ffffffffc020021e:	42055693          	srai	a3,a0,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200222:	0085571b          	srliw	a4,a0,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200226:	01855e1b          	srliw	t3,a0,0x18
ffffffffc020022a:	0186d31b          	srliw	t1,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020022e:	00ff07b7          	lui	a5,0xff0
ffffffffc0200232:	0185189b          	slliw	a7,a0,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200236:	0105561b          	srliw	a2,a0,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020023a:	0186981b          	slliw	a6,a3,0x18
ffffffffc020023e:	8161                	srli	a0,a0,0x18
ffffffffc0200240:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200244:	0106d69b          	srliw	a3,a3,0x10
ffffffffc0200248:	65c1                	lui	a1,0x10
ffffffffc020024a:	15fd                	addi	a1,a1,-1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020024c:	8f7d                	and	a4,a4,a5
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020024e:	00686833          	or	a6,a6,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200252:	8fe9                	and	a5,a5,a0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200254:	0086969b          	slliw	a3,a3,0x8
ffffffffc0200258:	01c8e8b3          	or	a7,a7,t3
ffffffffc020025c:	0086161b          	slliw	a2,a2,0x8
ffffffffc0200260:	0107e7b3          	or	a5,a5,a6
ffffffffc0200264:	8eed                	and	a3,a3,a1
ffffffffc0200266:	01176533          	or	a0,a4,a7
ffffffffc020026a:	8fd5                	or	a5,a5,a3
ffffffffc020026c:	00b67733          	and	a4,a2,a1
ffffffffc0200270:	8d59                	or	a0,a0,a4
           fdt32_to_cpu(x >> 32);
ffffffffc0200272:	1782                	slli	a5,a5,0x20
ffffffffc0200274:	9381                	srli	a5,a5,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200276:	1502                	slli	a0,a0,0x20
}
ffffffffc0200278:	8d5d                	or	a0,a0,a5
ffffffffc020027a:	8082                	ret

ffffffffc020027c <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc020027c:	7159                	addi	sp,sp,-112
    cprintf("DTB Init\n");
ffffffffc020027e:	00003517          	auipc	a0,0x3
ffffffffc0200282:	c1a50513          	addi	a0,a0,-998 # ffffffffc0202e98 <etext+0x114>
void dtb_init(void) {
ffffffffc0200286:	f486                	sd	ra,104(sp)
ffffffffc0200288:	f0a2                	sd	s0,96(sp)
ffffffffc020028a:	e0d2                	sd	s4,64(sp)
ffffffffc020028c:	eca6                	sd	s1,88(sp)
ffffffffc020028e:	e8ca                	sd	s2,80(sp)
ffffffffc0200290:	e4ce                	sd	s3,72(sp)
ffffffffc0200292:	fc56                	sd	s5,56(sp)
ffffffffc0200294:	f85a                	sd	s6,48(sp)
ffffffffc0200296:	f45e                	sd	s7,40(sp)
ffffffffc0200298:	f062                	sd	s8,32(sp)
ffffffffc020029a:	ec66                	sd	s9,24(sp)
ffffffffc020029c:	e86a                	sd	s10,16(sp)
ffffffffc020029e:	e46e                	sd	s11,8(sp)
    cprintf("DTB Init\n");
ffffffffc02002a0:	eb5ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc02002a4:	00008597          	auipc	a1,0x8
ffffffffc02002a8:	d5c5b583          	ld	a1,-676(a1) # ffffffffc0208000 <boot_hartid>
ffffffffc02002ac:	00003517          	auipc	a0,0x3
ffffffffc02002b0:	bfc50513          	addi	a0,a0,-1028 # ffffffffc0202ea8 <etext+0x124>
ffffffffc02002b4:	ea1ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc02002b8:	00008417          	auipc	s0,0x8
ffffffffc02002bc:	d5040413          	addi	s0,s0,-688 # ffffffffc0208008 <boot_dtb>
ffffffffc02002c0:	600c                	ld	a1,0(s0)
ffffffffc02002c2:	00003517          	auipc	a0,0x3
ffffffffc02002c6:	bf650513          	addi	a0,a0,-1034 # ffffffffc0202eb8 <etext+0x134>
ffffffffc02002ca:	e8bff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc02002ce:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc02002d2:	00003517          	auipc	a0,0x3
ffffffffc02002d6:	bfe50513          	addi	a0,a0,-1026 # ffffffffc0202ed0 <etext+0x14c>
    if (boot_dtb == 0) {
ffffffffc02002da:	120a0363          	beqz	s4,ffffffffc0200400 <dtb_init+0x184>
        return;
    }
    
    // 转换为虚拟地址
    // 变成虚地址，因为已经开了分页了
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc02002de:	57f5                	li	a5,-3
ffffffffc02002e0:	07fa                	slli	a5,a5,0x1e
ffffffffc02002e2:	00fa0633          	add	a2,s4,a5
     * 固定防伪暗号：设备树（DTB）标准死规定——任何合法的 DTB 数据，
     *     最开头的第 1 个 32 位整数（header->magic），必须固定写入 0xd00dfeed 这串数字（就像人民币上的防伪水印）。
     * 字节序转换（fdt32_to_cpu）：因为 DTB 标准规定数据按“大端序（高字节在前）”存放，而 RISC-V CPU 是“小端序（低字节在前）”，
     *     所以先调 fdt32_to_cpu() 把这 4 个字节翻转成 CPU 能正常比较的顺序。
    */
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc02002e6:	421c                	lw	a5,0(a2)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e8:	00ff0537          	lui	a0,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002ec:	0187d69b          	srliw	a3,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f0:	0087d71b          	srliw	a4,a5,0x8
ffffffffc02002f4:	0187959b          	slliw	a1,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f8:	8dd5                	or	a1,a1,a3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002fa:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002fe:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200302:	66c1                	lui	a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200304:	8f69                	and	a4,a4,a0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200306:	0087979b          	slliw	a5,a5,0x8
ffffffffc020030a:	16fd                	addi	a3,a3,-1
ffffffffc020030c:	8dd9                	or	a1,a1,a4
ffffffffc020030e:	8ff5                	and	a5,a5,a3
ffffffffc0200310:	8fcd                	or	a5,a5,a1
ffffffffc0200312:	0007859b          	sext.w	a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc0200316:	d00e07b7          	lui	a5,0xd00e0
ffffffffc020031a:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed7a6d>
ffffffffc020031e:	10f59063          	bne	a1,a5,ffffffffc020041e <dtb_init+0x1a2>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc0200322:	461c                	lw	a5,8(a2)
ffffffffc0200324:	4658                	lw	a4,12(a2)
    int in_memory_node = 0;
ffffffffc0200326:	4b81                	li	s7,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200328:	0087d59b          	srliw	a1,a5,0x8
ffffffffc020032c:	0087541b          	srliw	s0,a4,0x8
ffffffffc0200330:	0187181b          	slliw	a6,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200334:	0187531b          	srliw	t1,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200338:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020033c:	0187d89b          	srliw	a7,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200340:	0104141b          	slliw	s0,s0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200344:	0107571b          	srliw	a4,a4,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200348:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020034c:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200350:	8c69                	and	s0,s0,a0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200352:	00686833          	or	a6,a6,t1
ffffffffc0200356:	0087171b          	slliw	a4,a4,0x8
ffffffffc020035a:	011a6a33          	or	s4,s4,a7
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020035e:	8d6d                	and	a0,a0,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200360:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200364:	01046433          	or	s0,s0,a6
ffffffffc0200368:	8f75                	and	a4,a4,a3
ffffffffc020036a:	00aa6a33          	or	s4,s4,a0
ffffffffc020036e:	8ff5                	and	a5,a5,a3
ffffffffc0200370:	8c59                	or	s0,s0,a4
ffffffffc0200372:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200376:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200378:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020037a:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020037c:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200380:	9432                	add	s0,s0,a2
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200382:	9a32                	add	s4,s4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200384:	00ff0d37          	lui	s10,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200388:	8c36                	mv	s8,a3
        switch (token) {
ffffffffc020038a:	4c8d                	li	s9,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020038c:	00003917          	auipc	s2,0x3
ffffffffc0200390:	b9490913          	addi	s2,s2,-1132 # ffffffffc0202f20 <etext+0x19c>
        switch (token) {
ffffffffc0200394:	4991                	li	s3,4
ffffffffc0200396:	4d85                	li	s11,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200398:	00003497          	auipc	s1,0x3
ffffffffc020039c:	b8048493          	addi	s1,s1,-1152 # ffffffffc0202f18 <etext+0x194>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc02003a0:	000a2703          	lw	a4,0(s4)
ffffffffc02003a4:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02003a8:	0087579b          	srliw	a5,a4,0x8
ffffffffc02003ac:	0187161b          	slliw	a2,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02003b0:	0187559b          	srliw	a1,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02003b4:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02003b8:	0107571b          	srliw	a4,a4,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02003bc:	01a7f7b3          	and	a5,a5,s10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02003c0:	8e4d                	or	a2,a2,a1
ffffffffc02003c2:	0087171b          	slliw	a4,a4,0x8
ffffffffc02003c6:	8fd1                	or	a5,a5,a2
ffffffffc02003c8:	01877733          	and	a4,a4,s8
ffffffffc02003cc:	8fd9                	or	a5,a5,a4
ffffffffc02003ce:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc02003d0:	09978c63          	beq	a5,s9,ffffffffc0200468 <dtb_init+0x1ec>
ffffffffc02003d4:	00fcea63          	bltu	s9,a5,ffffffffc02003e8 <dtb_init+0x16c>
ffffffffc02003d8:	07b78663          	beq	a5,s11,ffffffffc0200444 <dtb_init+0x1c8>
ffffffffc02003dc:	4709                	li	a4,2
ffffffffc02003de:	00e79763          	bne	a5,a4,ffffffffc02003ec <dtb_init+0x170>
ffffffffc02003e2:	4b81                	li	s7,0
ffffffffc02003e4:	8a56                	mv	s4,s5
ffffffffc02003e6:	bf6d                	j	ffffffffc02003a0 <dtb_init+0x124>
ffffffffc02003e8:	ff378ee3          	beq	a5,s3,ffffffffc02003e4 <dtb_init+0x168>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;// DRAM 起点
        memory_size = mem_size;// DRAM 大小
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc02003ec:	00003517          	auipc	a0,0x3
ffffffffc02003f0:	bac50513          	addi	a0,a0,-1108 # ffffffffc0202f98 <etext+0x214>
ffffffffc02003f4:	d61ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc02003f8:	00003517          	auipc	a0,0x3
ffffffffc02003fc:	bd850513          	addi	a0,a0,-1064 # ffffffffc0202fd0 <etext+0x24c>
}
ffffffffc0200400:	7406                	ld	s0,96(sp)
ffffffffc0200402:	70a6                	ld	ra,104(sp)
ffffffffc0200404:	64e6                	ld	s1,88(sp)
ffffffffc0200406:	6946                	ld	s2,80(sp)
ffffffffc0200408:	69a6                	ld	s3,72(sp)
ffffffffc020040a:	6a06                	ld	s4,64(sp)
ffffffffc020040c:	7ae2                	ld	s5,56(sp)
ffffffffc020040e:	7b42                	ld	s6,48(sp)
ffffffffc0200410:	7ba2                	ld	s7,40(sp)
ffffffffc0200412:	7c02                	ld	s8,32(sp)
ffffffffc0200414:	6ce2                	ld	s9,24(sp)
ffffffffc0200416:	6d42                	ld	s10,16(sp)
ffffffffc0200418:	6da2                	ld	s11,8(sp)
ffffffffc020041a:	6165                	addi	sp,sp,112
    cprintf("DTB init completed\n");
ffffffffc020041c:	bb25                	j	ffffffffc0200154 <cprintf>
}
ffffffffc020041e:	7406                	ld	s0,96(sp)
ffffffffc0200420:	70a6                	ld	ra,104(sp)
ffffffffc0200422:	64e6                	ld	s1,88(sp)
ffffffffc0200424:	6946                	ld	s2,80(sp)
ffffffffc0200426:	69a6                	ld	s3,72(sp)
ffffffffc0200428:	6a06                	ld	s4,64(sp)
ffffffffc020042a:	7ae2                	ld	s5,56(sp)
ffffffffc020042c:	7b42                	ld	s6,48(sp)
ffffffffc020042e:	7ba2                	ld	s7,40(sp)
ffffffffc0200430:	7c02                	ld	s8,32(sp)
ffffffffc0200432:	6ce2                	ld	s9,24(sp)
ffffffffc0200434:	6d42                	ld	s10,16(sp)
ffffffffc0200436:	6da2                	ld	s11,8(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc0200438:	00003517          	auipc	a0,0x3
ffffffffc020043c:	ab850513          	addi	a0,a0,-1352 # ffffffffc0202ef0 <etext+0x16c>
}
ffffffffc0200440:	6165                	addi	sp,sp,112
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc0200442:	bb09                	j	ffffffffc0200154 <cprintf>
                int name_len = strlen(name);
ffffffffc0200444:	8556                	mv	a0,s5
ffffffffc0200446:	4aa020ef          	jal	ra,ffffffffc02028f0 <strlen>
ffffffffc020044a:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020044c:	4619                	li	a2,6
ffffffffc020044e:	85a6                	mv	a1,s1
ffffffffc0200450:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc0200452:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200454:	4f0020ef          	jal	ra,ffffffffc0202944 <strncmp>
ffffffffc0200458:	e111                	bnez	a0,ffffffffc020045c <dtb_init+0x1e0>
                    in_memory_node = 1;
ffffffffc020045a:	4b85                	li	s7,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc020045c:	0a91                	addi	s5,s5,4
ffffffffc020045e:	9ad2                	add	s5,s5,s4
ffffffffc0200460:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200464:	8a56                	mv	s4,s5
ffffffffc0200466:	bf2d                	j	ffffffffc02003a0 <dtb_init+0x124>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200468:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020046c:	00ca0a93          	addi	s5,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200470:	0087db1b          	srliw	s6,a5,0x8
ffffffffc0200474:	0187971b          	slliw	a4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200478:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020047c:	010b1b1b          	slliw	s6,s6,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200480:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200484:	01ab7b33          	and	s6,s6,s10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200488:	8f51                	or	a4,a4,a2
ffffffffc020048a:	0087979b          	slliw	a5,a5,0x8
ffffffffc020048e:	00eb6b33          	or	s6,s6,a4
ffffffffc0200492:	0187f7b3          	and	a5,a5,s8
ffffffffc0200496:	00fb6b33          	or	s6,s6,a5
ffffffffc020049a:	2b01                	sext.w	s6,s6
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020049c:	000b9b63          	bnez	s7,ffffffffc02004b2 <dtb_init+0x236>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc02004a0:	1b02                	slli	s6,s6,0x20
ffffffffc02004a2:	0a8d                	addi	s5,s5,3
ffffffffc02004a4:	020b5b13          	srli	s6,s6,0x20
ffffffffc02004a8:	9ada                	add	s5,s5,s6
ffffffffc02004aa:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc02004ae:	8a56                	mv	s4,s5
ffffffffc02004b0:	bdc5                	j	ffffffffc02003a0 <dtb_init+0x124>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc02004b2:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02004b6:	85ca                	mv	a1,s2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b8:	0087d71b          	srliw	a4,a5,0x8
ffffffffc02004bc:	0187951b          	slliw	a0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c0:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c4:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c8:	0107d79b          	srliw	a5,a5,0x10
ffffffffc02004cc:	8d51                	or	a0,a0,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004ce:	01a77733          	and	a4,a4,s10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004d2:	0087979b          	slliw	a5,a5,0x8
ffffffffc02004d6:	8d59                	or	a0,a0,a4
ffffffffc02004d8:	0187f7b3          	and	a5,a5,s8
ffffffffc02004dc:	8fc9                	or	a5,a5,a0
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc02004de:	02079513          	slli	a0,a5,0x20
ffffffffc02004e2:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02004e4:	9522                	add	a0,a0,s0
ffffffffc02004e6:	440020ef          	jal	ra,ffffffffc0202926 <strcmp>
ffffffffc02004ea:	f95d                	bnez	a0,ffffffffc02004a0 <dtb_init+0x224>
ffffffffc02004ec:	47bd                	li	a5,15
ffffffffc02004ee:	fb67f9e3          	bgeu	a5,s6,ffffffffc02004a0 <dtb_init+0x224>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc02004f2:	00ca3503          	ld	a0,12(s4)
ffffffffc02004f6:	d29ff0ef          	jal	ra,ffffffffc020021e <fdt64_to_cpu>
ffffffffc02004fa:	84aa                	mv	s1,a0
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004fc:	014a3503          	ld	a0,20(s4)
ffffffffc0200500:	d1fff0ef          	jal	ra,ffffffffc020021e <fdt64_to_cpu>
ffffffffc0200504:	842a                	mv	s0,a0
        cprintf("Physical Memory from DTB:\n");
ffffffffc0200506:	00003517          	auipc	a0,0x3
ffffffffc020050a:	a2250513          	addi	a0,a0,-1502 # ffffffffc0202f28 <etext+0x1a4>
ffffffffc020050e:	c47ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200512:	85a6                	mv	a1,s1
ffffffffc0200514:	00003517          	auipc	a0,0x3
ffffffffc0200518:	a3450513          	addi	a0,a0,-1484 # ffffffffc0202f48 <etext+0x1c4>
ffffffffc020051c:	c39ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc0200520:	01445613          	srli	a2,s0,0x14
ffffffffc0200524:	85a2                	mv	a1,s0
ffffffffc0200526:	00003517          	auipc	a0,0x3
ffffffffc020052a:	a3a50513          	addi	a0,a0,-1478 # ffffffffc0202f60 <etext+0x1dc>
ffffffffc020052e:	c27ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200532:	008485b3          	add	a1,s1,s0
ffffffffc0200536:	15fd                	addi	a1,a1,-1
ffffffffc0200538:	00003517          	auipc	a0,0x3
ffffffffc020053c:	a4850513          	addi	a0,a0,-1464 # ffffffffc0202f80 <etext+0x1fc>
ffffffffc0200540:	c15ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("DTB init completed\n");
ffffffffc0200544:	00003517          	auipc	a0,0x3
ffffffffc0200548:	a8c50513          	addi	a0,a0,-1396 # ffffffffc0202fd0 <etext+0x24c>
        memory_base = mem_base;// DRAM 起点
ffffffffc020054c:	00008797          	auipc	a5,0x8
ffffffffc0200550:	ee97ba23          	sd	s1,-268(a5) # ffffffffc0208440 <memory_base>
        memory_size = mem_size;// DRAM 大小
ffffffffc0200554:	00008797          	auipc	a5,0x8
ffffffffc0200558:	ee87ba23          	sd	s0,-268(a5) # ffffffffc0208448 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc020055c:	b555                	j	ffffffffc0200400 <dtb_init+0x184>

ffffffffc020055e <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc020055e:	00008517          	auipc	a0,0x8
ffffffffc0200562:	ee253503          	ld	a0,-286(a0) # ffffffffc0208440 <memory_base>
ffffffffc0200566:	8082                	ret

ffffffffc0200568 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc0200568:	00008517          	auipc	a0,0x8
ffffffffc020056c:	ee053503          	ld	a0,-288(a0) # ffffffffc0208448 <memory_size>
ffffffffc0200570:	8082                	ret

ffffffffc0200572 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc0200572:	8082                	ret

ffffffffc0200574 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200574:	0ff57513          	andi	a0,a0,255
ffffffffc0200578:	7f20206f          	j	ffffffffc0202d6a <sbi_console_putchar>

ffffffffc020057c <alloc_pages>:
// Page allocation goes through SLUB first: requests larger than 2048 bytes
// (every whole-page request, since PGSIZE is 4096) are forwarded by SLUB to
// the current pmm manager unchanged; smaller byte-sized requests can be
// served by slub_alloc() directly.
struct Page *alloc_pages(size_t n) {
    if (n > (size_t)-1 / PGSIZE) {
ffffffffc020057c:	57fd                	li	a5,-1
ffffffffc020057e:	83b1                	srli	a5,a5,0xc
ffffffffc0200580:	04a7e763          	bltu	a5,a0,ffffffffc02005ce <alloc_pages+0x52>
struct Page *alloc_pages(size_t n) {
ffffffffc0200584:	1141                	addi	sp,sp,-16
        return NULL;
    }

    void *ptr = slub_alloc(n * PGSIZE);
ffffffffc0200586:	0532                	slli	a0,a0,0xc
struct Page *alloc_pages(size_t n) {
ffffffffc0200588:	e406                	sd	ra,8(sp)
    void *ptr = slub_alloc(n * PGSIZE);
ffffffffc020058a:	521000ef          	jal	ra,ffffffffc02012aa <slub_alloc>
    if (ptr == NULL) {
ffffffffc020058e:	cd05                	beqz	a0,ffffffffc02005c6 <alloc_pages+0x4a>
        return NULL;
    }
    return pa2page((uintptr_t)ptr - va_pa_offset);
ffffffffc0200590:	00008797          	auipc	a5,0x8
ffffffffc0200594:	ee07b783          	ld	a5,-288(a5) # ffffffffc0208470 <va_pa_offset>
ffffffffc0200598:	8d1d                	sub	a0,a0,a5
    page->ref -= 1;
    return page->ref;
}
// 物理地址->page
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc020059a:	8131                	srli	a0,a0,0xc
ffffffffc020059c:	00008797          	auipc	a5,0x8
ffffffffc02005a0:	eb47b783          	ld	a5,-332(a5) # ffffffffc0208450 <npage>
ffffffffc02005a4:	02f57763          	bgeu	a0,a5,ffffffffc02005d2 <alloc_pages+0x56>
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc02005a8:	fff807b7          	lui	a5,0xfff80
ffffffffc02005ac:	953e                	add	a0,a0,a5
}
ffffffffc02005ae:	60a2                	ld	ra,8(sp)
ffffffffc02005b0:	00251793          	slli	a5,a0,0x2
ffffffffc02005b4:	953e                	add	a0,a0,a5
ffffffffc02005b6:	050e                	slli	a0,a0,0x3
ffffffffc02005b8:	00008797          	auipc	a5,0x8
ffffffffc02005bc:	ec07b783          	ld	a5,-320(a5) # ffffffffc0208478 <pages>
ffffffffc02005c0:	953e                	add	a0,a0,a5
ffffffffc02005c2:	0141                	addi	sp,sp,16
ffffffffc02005c4:	8082                	ret
ffffffffc02005c6:	60a2                	ld	ra,8(sp)
        return NULL;
ffffffffc02005c8:	4501                	li	a0,0
}
ffffffffc02005ca:	0141                	addi	sp,sp,16
ffffffffc02005cc:	8082                	ret
        return NULL;
ffffffffc02005ce:	4501                	li	a0,0
}
ffffffffc02005d0:	8082                	ret
        panic("pa2page called with invalid pa");
ffffffffc02005d2:	00003617          	auipc	a2,0x3
ffffffffc02005d6:	a1660613          	addi	a2,a2,-1514 # ffffffffc0202fe8 <etext+0x264>
ffffffffc02005da:	06c00593          	li	a1,108
ffffffffc02005de:	00003517          	auipc	a0,0x3
ffffffffc02005e2:	a2a50513          	addi	a0,a0,-1494 # ffffffffc0203008 <etext+0x284>
ffffffffc02005e6:	be5ff0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc02005ea <free_pages>:

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
ffffffffc02005ea:	00008797          	auipc	a5,0x8
ffffffffc02005ee:	e7e7b783          	ld	a5,-386(a5) # ffffffffc0208468 <pmm_manager>
ffffffffc02005f2:	0207b303          	ld	t1,32(a5)
ffffffffc02005f6:	8302                	jr	t1

ffffffffc02005f8 <nr_free_pages>:
}

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void) {
    return pmm_manager->nr_free_pages();
ffffffffc02005f8:	00008797          	auipc	a5,0x8
ffffffffc02005fc:	e707b783          	ld	a5,-400(a5) # ffffffffc0208468 <pmm_manager>
ffffffffc0200600:	0287b303          	ld	t1,40(a5)
ffffffffc0200604:	8302                	jr	t1

ffffffffc0200606 <pmm_init>:
    pmm_manager = &bs_pmm_manager;
ffffffffc0200606:	00003797          	auipc	a5,0x3
ffffffffc020060a:	e9278793          	addi	a5,a5,-366 # ffffffffc0203498 <bs_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc020060e:	638c                	ld	a1,0(a5)
    // 把完整空闲页交给当前物理内存管理器
    init_memmap(pa2page(free_start_pa), (free_end_pa - free_start_pa) / PGSIZE);
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc0200610:	7139                	addi	sp,sp,-64
ffffffffc0200612:	f426                	sd	s1,40(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200614:	00003517          	auipc	a0,0x3
ffffffffc0200618:	a0450513          	addi	a0,a0,-1532 # ffffffffc0203018 <etext+0x294>
    pmm_manager = &bs_pmm_manager;
ffffffffc020061c:	00008497          	auipc	s1,0x8
ffffffffc0200620:	e4c48493          	addi	s1,s1,-436 # ffffffffc0208468 <pmm_manager>
void pmm_init(void) {
ffffffffc0200624:	fc06                	sd	ra,56(sp)
ffffffffc0200626:	ec4e                	sd	s3,24(sp)
ffffffffc0200628:	f822                	sd	s0,48(sp)
ffffffffc020062a:	f04a                	sd	s2,32(sp)
ffffffffc020062c:	e852                	sd	s4,16(sp)
ffffffffc020062e:	e456                	sd	s5,8(sp)
ffffffffc0200630:	e05a                	sd	s6,0(sp)
    pmm_manager = &bs_pmm_manager;
ffffffffc0200632:	e09c                	sd	a5,0(s1)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200634:	b21ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    pmm_manager->init();
ffffffffc0200638:	609c                	ld	a5,0(s1)
ffffffffc020063a:	679c                	ld	a5,8(a5)
ffffffffc020063c:	9782                	jalr	a5
    // Now the first_fit/best_fit/worst_fit/buddy_system pmm are available.
    init_pmm_manager();

    // Initialize the SLUB object caches; page allocation is dispatched
    // through SLUB from now on.
    slub_init();
ffffffffc020063e:	43f000ef          	jal	ra,ffffffffc020127c <slub_init>
    uint64_t mem_base = get_memory_base();
ffffffffc0200642:	f1dff0ef          	jal	ra,ffffffffc020055e <get_memory_base>
ffffffffc0200646:	89aa                	mv	s3,a0
    uint64_t mem_size = get_memory_size();
ffffffffc0200648:	f21ff0ef          	jal	ra,ffffffffc0200568 <get_memory_size>
    if (mem_base == 0 || mem_size == 0) {
ffffffffc020064c:	14098563          	beqz	s3,ffffffffc0200796 <pmm_init+0x190>
ffffffffc0200650:	14050363          	beqz	a0,ffffffffc0200796 <pmm_init+0x190>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200654:	57f5                	li	a5,-3
ffffffffc0200656:	07fa                	slli	a5,a5,0x1e
ffffffffc0200658:	00008917          	auipc	s2,0x8
ffffffffc020065c:	e1890913          	addi	s2,s2,-488 # ffffffffc0208470 <va_pa_offset>
ffffffffc0200660:	00f93023          	sd	a5,0(s2)
    uint64_t mem_end = mem_base + mem_size;
ffffffffc0200664:	47c5                	li	a5,17
ffffffffc0200666:	00a98433          	add	s0,s3,a0
    if (mem_end > PHYSICAL_MEMORY_END) {
ffffffffc020066a:	07ee                	slli	a5,a5,0x1b
ffffffffc020066c:	1087ec63          	bltu	a5,s0,ffffffffc0200784 <pmm_init+0x17e>
    if (PPN(mem_end) <= nbase) {
ffffffffc0200670:	00c45693          	srli	a3,s0,0xc
ffffffffc0200674:	000805b7          	lui	a1,0x80
ffffffffc0200678:	16d5f763          	bgeu	a1,a3,ffffffffc02007e6 <pmm_init+0x1e0>
    npage = PPN(mem_end);
ffffffffc020067c:	767d                	lui	a2,0xfffff
ffffffffc020067e:	00269713          	slli	a4,a3,0x2
ffffffffc0200682:	00009797          	auipc	a5,0x9
ffffffffc0200686:	dfd78793          	addi	a5,a5,-515 # ffffffffc020947f <end+0xfff>
ffffffffc020068a:	8ff1                	and	a5,a5,a2
ffffffffc020068c:	9736                	add	a4,a4,a3
ffffffffc020068e:	fec00637          	lui	a2,0xfec00
ffffffffc0200692:	963e                	add	a2,a2,a5
ffffffffc0200694:	00008a97          	auipc	s5,0x8
ffffffffc0200698:	dbca8a93          	addi	s5,s5,-580 # ffffffffc0208450 <npage>
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc020069c:	00008b17          	auipc	s6,0x8
ffffffffc02006a0:	ddcb0b13          	addi	s6,s6,-548 # ffffffffc0208478 <pages>
ffffffffc02006a4:	070e                	slli	a4,a4,0x3
ffffffffc02006a6:	9732                	add	a4,a4,a2
    npage = PPN(mem_end);
ffffffffc02006a8:	00dab023          	sd	a3,0(s5)
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc02006ac:	00fb3023          	sd	a5,0(s6)
    size_t nr_pages = npage - nbase;
ffffffffc02006b0:	40b68a33          	sub	s4,a3,a1
        SetPageReserved(&pages[i]);
ffffffffc02006b4:	4605                	li	a2,1
        pages[i].ref = 0;
ffffffffc02006b6:	0007a023          	sw	zero,0(a5)
        pages[i].property = 0;
ffffffffc02006ba:	0007a823          	sw	zero,16(a5)
        SetPageReserved(&pages[i]);
ffffffffc02006be:	e790                	sd	a2,8(a5)
    for (size_t i = 0; i < nr_pages; i++) {
ffffffffc02006c0:	02878793          	addi	a5,a5,40
ffffffffc02006c4:	fef719e3          	bne	a4,a5,ffffffffc02006b6 <pmm_init+0xb0>
    cprintf("Physical memory: [0x%016lx, 0x%016lx), npage = 0x%lx\n",
ffffffffc02006c8:	8622                	mv	a2,s0
ffffffffc02006ca:	85ce                	mv	a1,s3
ffffffffc02006cc:	00003517          	auipc	a0,0x3
ffffffffc02006d0:	9e450513          	addi	a0,a0,-1564 # ffffffffc02030b0 <etext+0x32c>
ffffffffc02006d4:	a81ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
        PADDR(ROUNDUP((uintptr_t)(pages + nr_pages), PGSIZE));
ffffffffc02006d8:	000b3503          	ld	a0,0(s6)
ffffffffc02006dc:	002a1593          	slli	a1,s4,0x2
ffffffffc02006e0:	95d2                	add	a1,a1,s4
ffffffffc02006e2:	058e                	slli	a1,a1,0x3
ffffffffc02006e4:	6685                	lui	a3,0x1
ffffffffc02006e6:	95aa                	add	a1,a1,a0
ffffffffc02006e8:	16fd                	addi	a3,a3,-1
ffffffffc02006ea:	95b6                	add	a1,a1,a3
ffffffffc02006ec:	767d                	lui	a2,0xfffff
ffffffffc02006ee:	8df1                	and	a1,a1,a2
ffffffffc02006f0:	c02007b7          	lui	a5,0xc0200
ffffffffc02006f4:	0cf5ec63          	bltu	a1,a5,ffffffffc02007cc <pmm_init+0x1c6>
ffffffffc02006f8:	00093683          	ld	a3,0(s2)
    uintptr_t free_end_pa = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc02006fc:	8c71                	and	s0,s0,a2
        PADDR(ROUNDUP((uintptr_t)(pages + nr_pages), PGSIZE));
ffffffffc02006fe:	40d587b3          	sub	a5,a1,a3
    if (free_start_pa >= free_end_pa) {
ffffffffc0200702:	0887f363          	bgeu	a5,s0,ffffffffc0200788 <pmm_init+0x182>
    if (PPN(pa) >= npage) {
ffffffffc0200706:	000ab703          	ld	a4,0(s5)
ffffffffc020070a:	83b1                	srli	a5,a5,0xc
ffffffffc020070c:	0ee7fa63          	bgeu	a5,a4,ffffffffc0200800 <pmm_init+0x1fa>
    return &pages[PPN(pa) - nbase];
ffffffffc0200710:	fff80737          	lui	a4,0xfff80
    pmm_manager->init_memmap(base, n);
ffffffffc0200714:	6090                	ld	a2,0(s1)
ffffffffc0200716:	97ba                	add	a5,a5,a4
ffffffffc0200718:	00279713          	slli	a4,a5,0x2
ffffffffc020071c:	97ba                	add	a5,a5,a4
    init_memmap(pa2page(free_start_pa), (free_end_pa - free_start_pa) / PGSIZE);
ffffffffc020071e:	9436                	add	s0,s0,a3
    pmm_manager->init_memmap(base, n);
ffffffffc0200720:	6a18                	ld	a4,16(a2)
    init_memmap(pa2page(free_start_pa), (free_end_pa - free_start_pa) / PGSIZE);
ffffffffc0200722:	40b405b3          	sub	a1,s0,a1
ffffffffc0200726:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc0200728:	81b1                	srli	a1,a1,0xc
ffffffffc020072a:	953e                	add	a0,a0,a5
ffffffffc020072c:	9702                	jalr	a4
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc020072e:	609c                	ld	a5,0(s1)
ffffffffc0200730:	7b9c                	ld	a5,48(a5)
ffffffffc0200732:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc0200734:	00003517          	auipc	a0,0x3
ffffffffc0200738:	a0c50513          	addi	a0,a0,-1524 # ffffffffc0203140 <etext+0x3bc>
ffffffffc020073c:	a19ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc0200740:	00007597          	auipc	a1,0x7
ffffffffc0200744:	8c058593          	addi	a1,a1,-1856 # ffffffffc0207000 <boot_page_table_sv39>
ffffffffc0200748:	00008797          	auipc	a5,0x8
ffffffffc020074c:	d0b7b823          	sd	a1,-752(a5) # ffffffffc0208458 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc0200750:	c02007b7          	lui	a5,0xc0200
ffffffffc0200754:	04f5ef63          	bltu	a1,a5,ffffffffc02007b2 <pmm_init+0x1ac>
ffffffffc0200758:	00093603          	ld	a2,0(s2)
}
ffffffffc020075c:	7442                	ld	s0,48(sp)
ffffffffc020075e:	70e2                	ld	ra,56(sp)
ffffffffc0200760:	74a2                	ld	s1,40(sp)
ffffffffc0200762:	7902                	ld	s2,32(sp)
ffffffffc0200764:	69e2                	ld	s3,24(sp)
ffffffffc0200766:	6a42                	ld	s4,16(sp)
ffffffffc0200768:	6aa2                	ld	s5,8(sp)
ffffffffc020076a:	6b02                	ld	s6,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc020076c:	40c58633          	sub	a2,a1,a2
ffffffffc0200770:	00008797          	auipc	a5,0x8
ffffffffc0200774:	cec7b823          	sd	a2,-784(a5) # ffffffffc0208460 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200778:	00003517          	auipc	a0,0x3
ffffffffc020077c:	9e850513          	addi	a0,a0,-1560 # ffffffffc0203160 <etext+0x3dc>
}
ffffffffc0200780:	6121                	addi	sp,sp,64
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200782:	bac9                	j	ffffffffc0200154 <cprintf>
ffffffffc0200784:	843e                	mv	s0,a5
ffffffffc0200786:	b5ed                	j	ffffffffc0200670 <pmm_init+0x6a>
        cprintf("page_init: no complete free page available\n");
ffffffffc0200788:	00003517          	auipc	a0,0x3
ffffffffc020078c:	98850513          	addi	a0,a0,-1656 # ffffffffc0203110 <etext+0x38c>
ffffffffc0200790:	9c5ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
        return;
ffffffffc0200794:	bf69                	j	ffffffffc020072e <pmm_init+0x128>
        panic("page_init: invalid memory info from DTB (base=0x%lx, size=0x%lx)",
ffffffffc0200796:	872a                	mv	a4,a0
ffffffffc0200798:	86ce                	mv	a3,s3
ffffffffc020079a:	00003617          	auipc	a2,0x3
ffffffffc020079e:	89660613          	addi	a2,a2,-1898 # ffffffffc0203030 <etext+0x2ac>
ffffffffc02007a2:	05b00593          	li	a1,91
ffffffffc02007a6:	00003517          	auipc	a0,0x3
ffffffffc02007aa:	8d250513          	addi	a0,a0,-1838 # ffffffffc0203078 <etext+0x2f4>
ffffffffc02007ae:	a1dff0ef          	jal	ra,ffffffffc02001ca <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc02007b2:	86ae                	mv	a3,a1
ffffffffc02007b4:	00003617          	auipc	a2,0x3
ffffffffc02007b8:	93460613          	addi	a2,a2,-1740 # ffffffffc02030e8 <etext+0x364>
ffffffffc02007bc:	0a400593          	li	a1,164
ffffffffc02007c0:	00003517          	auipc	a0,0x3
ffffffffc02007c4:	8b850513          	addi	a0,a0,-1864 # ffffffffc0203078 <etext+0x2f4>
ffffffffc02007c8:	a03ff0ef          	jal	ra,ffffffffc02001ca <__panic>
        PADDR(ROUNDUP((uintptr_t)(pages + nr_pages), PGSIZE));
ffffffffc02007cc:	86ae                	mv	a3,a1
ffffffffc02007ce:	00003617          	auipc	a2,0x3
ffffffffc02007d2:	91a60613          	addi	a2,a2,-1766 # ffffffffc02030e8 <etext+0x364>
ffffffffc02007d6:	08000593          	li	a1,128
ffffffffc02007da:	00003517          	auipc	a0,0x3
ffffffffc02007de:	89e50513          	addi	a0,a0,-1890 # ffffffffc0203078 <etext+0x2f4>
ffffffffc02007e2:	9e9ff0ef          	jal	ra,ffffffffc02001ca <__panic>
        panic("page_init: invalid memory end 0x%lx", mem_end);
ffffffffc02007e6:	86a2                	mv	a3,s0
ffffffffc02007e8:	00003617          	auipc	a2,0x3
ffffffffc02007ec:	8a060613          	addi	a2,a2,-1888 # ffffffffc0203088 <etext+0x304>
ffffffffc02007f0:	06800593          	li	a1,104
ffffffffc02007f4:	00003517          	auipc	a0,0x3
ffffffffc02007f8:	88450513          	addi	a0,a0,-1916 # ffffffffc0203078 <etext+0x2f4>
ffffffffc02007fc:	9cfff0ef          	jal	ra,ffffffffc02001ca <__panic>
        panic("pa2page called with invalid pa");
ffffffffc0200800:	00002617          	auipc	a2,0x2
ffffffffc0200804:	7e860613          	addi	a2,a2,2024 # ffffffffc0202fe8 <etext+0x264>
ffffffffc0200808:	06c00593          	li	a1,108
ffffffffc020080c:	00002517          	auipc	a0,0x2
ffffffffc0200810:	7fc50513          	addi	a0,a0,2044 # ffffffffc0203008 <etext+0x284>
ffffffffc0200814:	9b7ff0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0200818 <bs_init>:
    return order;
}

static void
bs_init(void) {
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc0200818:	00008797          	auipc	a5,0x8
ffffffffc020081c:	80078793          	addi	a5,a5,-2048 # ffffffffc0208018 <free_area>
ffffffffc0200820:	00008717          	auipc	a4,0x8
ffffffffc0200824:	af870713          	addi	a4,a4,-1288 # ffffffffc0208318 <slub_caches>
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    // 省的考虑 NULL 的事情
    elm->prev = elm->next = elm;
ffffffffc0200828:	e79c                	sd	a5,8(a5)
ffffffffc020082a:	e39c                	sd	a5,0(a5)
        list_init(&(free_area[k].free_list));
        free_area[k].nr_free = 0;
ffffffffc020082c:	0007a823          	sw	zero,16(a5)
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc0200830:	07e1                	addi	a5,a5,24
ffffffffc0200832:	fee79be3          	bne	a5,a4,ffffffffc0200828 <bs_init+0x10>
    }
}
ffffffffc0200836:	8082                	ret

ffffffffc0200838 <bs_nr_free_pages>:
}

static size_t
bs_nr_free_pages(void) {
    size_t total = 0;
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc0200838:	00007797          	auipc	a5,0x7
ffffffffc020083c:	7f078793          	addi	a5,a5,2032 # ffffffffc0208028 <free_area+0x10>
ffffffffc0200840:	00008697          	auipc	a3,0x8
ffffffffc0200844:	ae868693          	addi	a3,a3,-1304 # ffffffffc0208328 <slub_caches+0x10>
    size_t total = 0;
ffffffffc0200848:	4501                	li	a0,0
        total += free_area[k].nr_free;
ffffffffc020084a:	0007e703          	lwu	a4,0(a5)
ffffffffc020084e:	07e1                	addi	a5,a5,24
ffffffffc0200850:	953a                	add	a0,a0,a4
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc0200852:	fed79ce3          	bne	a5,a3,ffffffffc020084a <bs_nr_free_pages+0x12>
    }
    return total;
}
ffffffffc0200856:	8082                	ret

ffffffffc0200858 <bs_check>:

static void
bs_check(void) {
ffffffffc0200858:	7165                	addi	sp,sp,-400
ffffffffc020085a:	eada                	sd	s6,336(sp)
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc020085c:	00008b17          	auipc	s6,0x8
ffffffffc0200860:	c1cb0b13          	addi	s6,s6,-996 # ffffffffc0208478 <pages>
ffffffffc0200864:	000b3e03          	ld	t3,0(s6)
ffffffffc0200868:	e322                	sd	s0,384(sp)
ffffffffc020086a:	faca                	sd	s2,368(sp)
ffffffffc020086c:	1000                	addi	s0,sp,32
ffffffffc020086e:	00007917          	auipc	s2,0x7
ffffffffc0200872:	7aa90913          	addi	s2,s2,1962 # ffffffffc0208018 <free_area>
ffffffffc0200876:	fea6                	sd	s1,376(sp)
ffffffffc0200878:	f6ce                	sd	s3,360(sp)
ffffffffc020087a:	f2d2                	sd	s4,352(sp)
ffffffffc020087c:	eed6                	sd	s5,344(sp)
ffffffffc020087e:	e706                	sd	ra,392(sp)
ffffffffc0200880:	e6de                	sd	s7,328(sp)
ffffffffc0200882:	e2e2                	sd	s8,320(sp)
ffffffffc0200884:	fe66                	sd	s9,312(sp)
ffffffffc0200886:	fa6a                	sd	s10,304(sp)
ffffffffc0200888:	f66e                	sd	s11,296(sp)
ffffffffc020088a:	00004497          	auipc	s1,0x4
ffffffffc020088e:	a464b483          	ld	s1,-1466(s1) # ffffffffc02042d0 <nbase>
ffffffffc0200892:	8aa2                	mv	s5,s0
ffffffffc0200894:	00008a17          	auipc	s4,0x8
ffffffffc0200898:	a84a0a13          	addi	s4,s4,-1404 # ffffffffc0208318 <slub_caches>
ffffffffc020089c:	8f22                	mv	t5,s0
ffffffffc020089e:	884a                	mv	a6,s2
    size_t total = 0;
    size_t block_count[BS_MAX_ORDER];

    // 检查每级链表：块首页带有 PG_property，大小为 2^k 且按大小对齐
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc02008a0:	4e81                	li	t4,0
    size_t total = 0;
ffffffffc02008a2:	4981                	li	s3,0
        list_entry_t *le = head;
        size_t cnt = 0, pages = 0;
        while ((le = list_next(le)) != head) {
            struct Page *block = le2page(le, page_link);
            assert(PageProperty(block));
            assert(block->property == (1UL << k));
ffffffffc02008a4:	4285                	li	t0,1
ffffffffc02008a6:	5ffd                	li	t6,-1
ffffffffc02008a8:	00004317          	auipc	t1,0x4
ffffffffc02008ac:	a3033303          	ld	t1,-1488(t1) # ffffffffc02042d8 <nbase+0x8>
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc02008b0:	00883703          	ld	a4,8(a6)
        while ((le = list_next(le)) != head) {
ffffffffc02008b4:	25070c63          	beq	a4,a6,ffffffffc0200b0c <bs_check+0x2b4>
ffffffffc02008b8:	01df98b3          	sll	a7,t6,t4
            assert(block->property == (1UL << k));
ffffffffc02008bc:	01d29533          	sll	a0,t0,t4
ffffffffc02008c0:	fff8c893          	not	a7,a7
        size_t cnt = 0, pages = 0;
ffffffffc02008c4:	4601                	li	a2,0
ffffffffc02008c6:	4581                	li	a1,0
            assert(PageProperty(block));
ffffffffc02008c8:	ff073683          	ld	a3,-16(a4)
            struct Page *block = le2page(le, page_link);
ffffffffc02008cc:	fe870793          	addi	a5,a4,-24
            assert(PageProperty(block));
ffffffffc02008d0:	8a89                	andi	a3,a3,2
ffffffffc02008d2:	28068063          	beqz	a3,ffffffffc0200b52 <bs_check+0x2fa>
            assert(block->property == (1UL << k));
ffffffffc02008d6:	ff876683          	lwu	a3,-8(a4)
ffffffffc02008da:	22a69c63          	bne	a3,a0,ffffffffc0200b12 <bs_check+0x2ba>
ffffffffc02008de:	41c787b3          	sub	a5,a5,t3
ffffffffc02008e2:	878d                	srai	a5,a5,0x3
ffffffffc02008e4:	026787b3          	mul	a5,a5,t1
ffffffffc02008e8:	97a6                	add	a5,a5,s1
            assert((page2ppn(block) & ((1UL << k) - 1)) == 0);
ffffffffc02008ea:	0117f7b3          	and	a5,a5,a7
ffffffffc02008ee:	24079263          	bnez	a5,ffffffffc0200b32 <bs_check+0x2da>
ffffffffc02008f2:	6718                	ld	a4,8(a4)
            cnt ++;
ffffffffc02008f4:	0585                	addi	a1,a1,1
            pages += (1UL << k);
ffffffffc02008f6:	962a                	add	a2,a2,a0
        while ((le = list_next(le)) != head) {
ffffffffc02008f8:	fd0718e3          	bne	a4,a6,ffffffffc02008c8 <bs_check+0x70>
        }
        assert(pages == free_area[k].nr_free);
ffffffffc02008fc:	01086783          	lwu	a5,16(a6)
ffffffffc0200900:	46c79b63          	bne	a5,a2,ffffffffc0200d76 <bs_check+0x51e>
        block_count[k] = cnt;
ffffffffc0200904:	00bf3023          	sd	a1,0(t5)
        total += pages;
ffffffffc0200908:	0861                	addi	a6,a6,24
ffffffffc020090a:	99b2                	add	s3,s3,a2
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc020090c:	0e85                	addi	t4,t4,1
ffffffffc020090e:	0f21                	addi	t5,t5,8
ffffffffc0200910:	fb4810e3          	bne	a6,s4,ffffffffc02008b0 <bs_check+0x58>
    }
    assert(total > 0);
ffffffffc0200914:	2e098163          	beqz	s3,ffffffffc0200bf6 <bs_check+0x39e>
ffffffffc0200918:	00007c17          	auipc	s8,0x7
ffffffffc020091c:	710c0c13          	addi	s8,s8,1808 # ffffffffc0208028 <free_area+0x10>
ffffffffc0200920:	00008b97          	auipc	s7,0x8
ffffffffc0200924:	a08b8b93          	addi	s7,s7,-1528 # ffffffffc0208328 <slub_caches+0x10>
ffffffffc0200928:	87e2                	mv	a5,s8
    size_t total = 0;
ffffffffc020092a:	4701                	li	a4,0
        total += free_area[k].nr_free;
ffffffffc020092c:	0007e683          	lwu	a3,0(a5)
ffffffffc0200930:	07e1                	addi	a5,a5,24
ffffffffc0200932:	9736                	add	a4,a4,a3
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc0200934:	ff779ce3          	bne	a5,s7,ffffffffc020092c <bs_check+0xd4>
    assert(total == bs_nr_free_pages());
ffffffffc0200938:	2ce99f63          	bne	s3,a4,ffffffffc0200c16 <bs_check+0x3be>

    // 分配 8、4、1 页并释放，检查页数统计与伙伴合并
    struct Page *p0 = alloc_pages(5);
ffffffffc020093c:	4515                	li	a0,5
ffffffffc020093e:	c3fff0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc0200942:	8d2a                	mv	s10,a0
    assert(p0 != NULL);
ffffffffc0200944:	2e050963          	beqz	a0,ffffffffc0200c36 <bs_check+0x3de>
    assert(!PageProperty(p0));
ffffffffc0200948:	651c                	ld	a5,8(a0)
ffffffffc020094a:	8b89                	andi	a5,a5,2
ffffffffc020094c:	30079563          	bnez	a5,ffffffffc0200c56 <bs_check+0x3fe>
ffffffffc0200950:	000b3683          	ld	a3,0(s6)
ffffffffc0200954:	00004c97          	auipc	s9,0x4
ffffffffc0200958:	984cbc83          	ld	s9,-1660(s9) # ffffffffc02042d8 <nbase+0x8>
ffffffffc020095c:	00007797          	auipc	a5,0x7
ffffffffc0200960:	6cc78793          	addi	a5,a5,1740 # ffffffffc0208028 <free_area+0x10>
ffffffffc0200964:	40d506b3          	sub	a3,a0,a3
ffffffffc0200968:	868d                	srai	a3,a3,0x3
ffffffffc020096a:	039686b3          	mul	a3,a3,s9
    size_t total = 0;
ffffffffc020096e:	4701                	li	a4,0
ffffffffc0200970:	96a6                	add	a3,a3,s1
    assert((page2ppn(p0) & 7) == 0);
ffffffffc0200972:	8a9d                	andi	a3,a3,7
ffffffffc0200974:	38069163          	bnez	a3,ffffffffc0200cf6 <bs_check+0x49e>
        total += free_area[k].nr_free;
ffffffffc0200978:	0007e683          	lwu	a3,0(a5)
ffffffffc020097c:	07e1                	addi	a5,a5,24
ffffffffc020097e:	9736                	add	a4,a4,a3
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc0200980:	ff779ce3          	bne	a5,s7,ffffffffc0200978 <bs_check+0x120>
    assert(bs_nr_free_pages() + 8 == total);
ffffffffc0200984:	0721                	addi	a4,a4,8
ffffffffc0200986:	39371863          	bne	a4,s3,ffffffffc0200d16 <bs_check+0x4be>

    struct Page *p1 = alloc_pages(3);
ffffffffc020098a:	450d                	li	a0,3
ffffffffc020098c:	bf1ff0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc0200990:	8daa                	mv	s11,a0
    struct Page *p2 = alloc_page();
ffffffffc0200992:	4505                	li	a0,1
ffffffffc0200994:	be9ff0ef          	jal	ra,ffffffffc020057c <alloc_pages>
    assert(p1 != NULL && p2 != NULL);
ffffffffc0200998:	380d8f63          	beqz	s11,ffffffffc0200d36 <bs_check+0x4de>
ffffffffc020099c:	38050d63          	beqz	a0,ffffffffc0200d36 <bs_check+0x4de>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc02009a0:	3bbd0b63          	beq	s10,s11,ffffffffc0200d56 <bs_check+0x4fe>
ffffffffc02009a4:	3aad0963          	beq	s10,a0,ffffffffc0200d56 <bs_check+0x4fe>
ffffffffc02009a8:	00007797          	auipc	a5,0x7
ffffffffc02009ac:	68078793          	addi	a5,a5,1664 # ffffffffc0208028 <free_area+0x10>
    size_t total = 0;
ffffffffc02009b0:	4701                	li	a4,0
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc02009b2:	3aad8263          	beq	s11,a0,ffffffffc0200d56 <bs_check+0x4fe>
        total += free_area[k].nr_free;
ffffffffc02009b6:	0007e683          	lwu	a3,0(a5)
ffffffffc02009ba:	07e1                	addi	a5,a5,24
ffffffffc02009bc:	9736                	add	a4,a4,a3
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc02009be:	ff779ce3          	bne	a5,s7,ffffffffc02009b6 <bs_check+0x15e>
    assert(bs_nr_free_pages() + 13 == total);
ffffffffc02009c2:	0735                	addi	a4,a4,13
ffffffffc02009c4:	2f371963          	bne	a4,s3,ffffffffc0200cb6 <bs_check+0x45e>

    free_page(p2);
ffffffffc02009c8:	4585                	li	a1,1
ffffffffc02009ca:	c21ff0ef          	jal	ra,ffffffffc02005ea <free_pages>
    free_pages(p1, 3);
ffffffffc02009ce:	458d                	li	a1,3
ffffffffc02009d0:	856e                	mv	a0,s11
ffffffffc02009d2:	c19ff0ef          	jal	ra,ffffffffc02005ea <free_pages>
    free_pages(p0, 5);
ffffffffc02009d6:	4595                	li	a1,5
ffffffffc02009d8:	856a                	mv	a0,s10
ffffffffc02009da:	c11ff0ef          	jal	ra,ffffffffc02005ea <free_pages>
ffffffffc02009de:	00007797          	auipc	a5,0x7
ffffffffc02009e2:	64a78793          	addi	a5,a5,1610 # ffffffffc0208028 <free_area+0x10>
    size_t total = 0;
ffffffffc02009e6:	4701                	li	a4,0
        total += free_area[k].nr_free;
ffffffffc02009e8:	0007e683          	lwu	a3,0(a5)
ffffffffc02009ec:	07e1                	addi	a5,a5,24
ffffffffc02009ee:	9736                	add	a4,a4,a3
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc02009f0:	ff779ce3          	bne	a5,s7,ffffffffc02009e8 <bs_check+0x190>
    assert(bs_nr_free_pages() == total);
ffffffffc02009f4:	2ee99163          	bne	s3,a4,ffffffffc0200cd6 <bs_check+0x47e>
ffffffffc02009f8:	000b3503          	ld	a0,0(s6)

    // 释放后应与分配前的分级块结构完全一致，说明伙伴块已正确合并
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc02009fc:	4801                	li	a6,0
        list_entry_t *le = head;
        size_t cnt = 0;
        while ((le = list_next(le)) != head) {
            struct Page *block = le2page(le, page_link);
            assert(PageProperty(block));
            assert(block->property == (1UL << k));
ffffffffc02009fe:	4305                	li	t1,1
ffffffffc0200a00:	58fd                	li	a7,-1
ffffffffc0200a02:	00893703          	ld	a4,8(s2)
        while ((le = list_next(le)) != head) {
ffffffffc0200a06:	16e90663          	beq	s2,a4,ffffffffc0200b72 <bs_check+0x31a>
ffffffffc0200a0a:	010895b3          	sll	a1,a7,a6
            assert(block->property == (1UL << k));
ffffffffc0200a0e:	01031e33          	sll	t3,t1,a6
ffffffffc0200a12:	fff5c593          	not	a1,a1
        size_t cnt = 0;
ffffffffc0200a16:	4601                	li	a2,0
            assert(PageProperty(block));
ffffffffc0200a18:	ff073683          	ld	a3,-16(a4)
            struct Page *block = le2page(le, page_link);
ffffffffc0200a1c:	fe870793          	addi	a5,a4,-24
            assert(PageProperty(block));
ffffffffc0200a20:	8a89                	andi	a3,a3,2
ffffffffc0200a22:	14068a63          	beqz	a3,ffffffffc0200b76 <bs_check+0x31e>
            assert(block->property == (1UL << k));
ffffffffc0200a26:	ff876683          	lwu	a3,-8(a4)
ffffffffc0200a2a:	19c69663          	bne	a3,t3,ffffffffc0200bb6 <bs_check+0x35e>
ffffffffc0200a2e:	8f89                	sub	a5,a5,a0
ffffffffc0200a30:	878d                	srai	a5,a5,0x3
ffffffffc0200a32:	039787b3          	mul	a5,a5,s9
ffffffffc0200a36:	97a6                	add	a5,a5,s1
            assert((page2ppn(block) & ((1UL << k) - 1)) == 0);
ffffffffc0200a38:	8fed                	and	a5,a5,a1
ffffffffc0200a3a:	14079e63          	bnez	a5,ffffffffc0200b96 <bs_check+0x33e>
ffffffffc0200a3e:	6718                	ld	a4,8(a4)
            cnt ++;
ffffffffc0200a40:	0605                	addi	a2,a2,1
        while ((le = list_next(le)) != head) {
ffffffffc0200a42:	fd271be3          	bne	a4,s2,ffffffffc0200a18 <bs_check+0x1c0>
        }
        assert(cnt == block_count[k]);
ffffffffc0200a46:	000ab783          	ld	a5,0(s5)
ffffffffc0200a4a:	22c79663          	bne	a5,a2,ffffffffc0200c76 <bs_check+0x41e>
        assert(free_area[k].nr_free == (cnt << k));
ffffffffc0200a4e:	01096783          	lwu	a5,16(s2)
ffffffffc0200a52:	01061633          	sll	a2,a2,a6
ffffffffc0200a56:	24c79063          	bne	a5,a2,ffffffffc0200c96 <bs_check+0x43e>
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc0200a5a:	0961                	addi	s2,s2,24
ffffffffc0200a5c:	0805                	addi	a6,a6,1
ffffffffc0200a5e:	0aa1                	addi	s5,s5,8
ffffffffc0200a60:	fb4911e3          	bne	s2,s4,ffffffffc0200a02 <bs_check+0x1aa>
    }

    // 不同大小请求的往返分配/释放
    for (size_t n = 1; n <= 16; n ++) {
ffffffffc0200a64:	4905                	li	s2,1
ffffffffc0200a66:	4a45                	li	s4,17
        struct Page *q = alloc_pages(n);
ffffffffc0200a68:	854a                	mv	a0,s2
ffffffffc0200a6a:	b13ff0ef          	jal	ra,ffffffffc020057c <alloc_pages>
        assert(q != NULL);
ffffffffc0200a6e:	16050463          	beqz	a0,ffffffffc0200bd6 <bs_check+0x37e>
        assert(!PageProperty(q));
ffffffffc0200a72:	6504                	ld	s1,8(a0)
ffffffffc0200a74:	8889                	andi	s1,s1,2
ffffffffc0200a76:	3a049063          	bnez	s1,ffffffffc0200e16 <bs_check+0x5be>
        free_pages(q, n);
ffffffffc0200a7a:	85ca                	mv	a1,s2
ffffffffc0200a7c:	b6fff0ef          	jal	ra,ffffffffc02005ea <free_pages>
ffffffffc0200a80:	87e2                	mv	a5,s8
    size_t total = 0;
ffffffffc0200a82:	4701                	li	a4,0
        total += free_area[k].nr_free;
ffffffffc0200a84:	0007e683          	lwu	a3,0(a5)
ffffffffc0200a88:	07e1                	addi	a5,a5,24
ffffffffc0200a8a:	9736                	add	a4,a4,a3
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc0200a8c:	ff779ce3          	bne	a5,s7,ffffffffc0200a84 <bs_check+0x22c>
        assert(bs_nr_free_pages() == total);
ffffffffc0200a90:	36e99363          	bne	s3,a4,ffffffffc0200df6 <bs_check+0x59e>
    for (size_t n = 1; n <= 16; n ++) {
ffffffffc0200a94:	0905                	addi	s2,s2,1
ffffffffc0200a96:	fd4919e3          	bne	s2,s4,ffffffffc0200a68 <bs_check+0x210>
ffffffffc0200a9a:	890a                	mv	s2,sp
ffffffffc0200a9c:	8a4a                	mv	s4,s2
    }

    // 多个单页块同时分配后再释放，检查相邻块回收
    struct Page *q[4];
    for (int i = 0; i < 4; i ++) {
        assert((q[i] = alloc_page()) != NULL);
ffffffffc0200a9e:	4505                	li	a0,1
ffffffffc0200aa0:	addff0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc0200aa4:	00aa3023          	sd	a0,0(s4)
ffffffffc0200aa8:	32050763          	beqz	a0,ffffffffc0200dd6 <bs_check+0x57e>
    for (int i = 0; i < 4; i ++) {
ffffffffc0200aac:	0a21                	addi	s4,s4,8
ffffffffc0200aae:	ff4418e3          	bne	s0,s4,ffffffffc0200a9e <bs_check+0x246>
ffffffffc0200ab2:	00007797          	auipc	a5,0x7
ffffffffc0200ab6:	57678793          	addi	a5,a5,1398 # ffffffffc0208028 <free_area+0x10>
    size_t total = 0;
ffffffffc0200aba:	4701                	li	a4,0
        total += free_area[k].nr_free;
ffffffffc0200abc:	0007e683          	lwu	a3,0(a5)
ffffffffc0200ac0:	07e1                	addi	a5,a5,24
ffffffffc0200ac2:	9736                	add	a4,a4,a3
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc0200ac4:	ff779ce3          	bne	a5,s7,ffffffffc0200abc <bs_check+0x264>
    }
    assert(bs_nr_free_pages() + 4 == total);
ffffffffc0200ac8:	0711                	addi	a4,a4,4
ffffffffc0200aca:	2f371663          	bne	a4,s3,ffffffffc0200db6 <bs_check+0x55e>
    for (int i = 0; i < 4; i ++) {
        free_page(q[i]);
ffffffffc0200ace:	00093503          	ld	a0,0(s2)
ffffffffc0200ad2:	4585                	li	a1,1
ffffffffc0200ad4:	0921                	addi	s2,s2,8
ffffffffc0200ad6:	b15ff0ef          	jal	ra,ffffffffc02005ea <free_pages>
    for (int i = 0; i < 4; i ++) {
ffffffffc0200ada:	ff241ae3          	bne	s0,s2,ffffffffc0200ace <bs_check+0x276>
        total += free_area[k].nr_free;
ffffffffc0200ade:	000c6783          	lwu	a5,0(s8)
ffffffffc0200ae2:	0c61                	addi	s8,s8,24
ffffffffc0200ae4:	94be                	add	s1,s1,a5
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
ffffffffc0200ae6:	ff7c1ce3          	bne	s8,s7,ffffffffc0200ade <bs_check+0x286>
    }
    assert(bs_nr_free_pages() == total);
ffffffffc0200aea:	2a999663          	bne	s3,s1,ffffffffc0200d96 <bs_check+0x53e>
}
ffffffffc0200aee:	60ba                	ld	ra,392(sp)
ffffffffc0200af0:	641a                	ld	s0,384(sp)
ffffffffc0200af2:	74f6                	ld	s1,376(sp)
ffffffffc0200af4:	7956                	ld	s2,368(sp)
ffffffffc0200af6:	79b6                	ld	s3,360(sp)
ffffffffc0200af8:	7a16                	ld	s4,352(sp)
ffffffffc0200afa:	6af6                	ld	s5,344(sp)
ffffffffc0200afc:	6b56                	ld	s6,336(sp)
ffffffffc0200afe:	6bb6                	ld	s7,328(sp)
ffffffffc0200b00:	6c16                	ld	s8,320(sp)
ffffffffc0200b02:	7cf2                	ld	s9,312(sp)
ffffffffc0200b04:	7d52                	ld	s10,304(sp)
ffffffffc0200b06:	7db2                	ld	s11,296(sp)
ffffffffc0200b08:	6159                	addi	sp,sp,400
ffffffffc0200b0a:	8082                	ret
        size_t cnt = 0, pages = 0;
ffffffffc0200b0c:	4601                	li	a2,0
ffffffffc0200b0e:	4581                	li	a1,0
ffffffffc0200b10:	b3f5                	j	ffffffffc02008fc <bs_check+0xa4>
            assert(block->property == (1UL << k));
ffffffffc0200b12:	00002697          	auipc	a3,0x2
ffffffffc0200b16:	6d668693          	addi	a3,a3,1750 # ffffffffc02031e8 <etext+0x464>
ffffffffc0200b1a:	00002617          	auipc	a2,0x2
ffffffffc0200b1e:	69e60613          	addi	a2,a2,1694 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200b22:	0ac00593          	li	a1,172
ffffffffc0200b26:	00002517          	auipc	a0,0x2
ffffffffc0200b2a:	6aa50513          	addi	a0,a0,1706 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200b2e:	e9cff0ef          	jal	ra,ffffffffc02001ca <__panic>
            assert((page2ppn(block) & ((1UL << k) - 1)) == 0);
ffffffffc0200b32:	00002697          	auipc	a3,0x2
ffffffffc0200b36:	6d668693          	addi	a3,a3,1750 # ffffffffc0203208 <etext+0x484>
ffffffffc0200b3a:	00002617          	auipc	a2,0x2
ffffffffc0200b3e:	67e60613          	addi	a2,a2,1662 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200b42:	0ad00593          	li	a1,173
ffffffffc0200b46:	00002517          	auipc	a0,0x2
ffffffffc0200b4a:	68a50513          	addi	a0,a0,1674 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200b4e:	e7cff0ef          	jal	ra,ffffffffc02001ca <__panic>
            assert(PageProperty(block));
ffffffffc0200b52:	00002697          	auipc	a3,0x2
ffffffffc0200b56:	64e68693          	addi	a3,a3,1614 # ffffffffc02031a0 <etext+0x41c>
ffffffffc0200b5a:	00002617          	auipc	a2,0x2
ffffffffc0200b5e:	65e60613          	addi	a2,a2,1630 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200b62:	0ab00593          	li	a1,171
ffffffffc0200b66:	00002517          	auipc	a0,0x2
ffffffffc0200b6a:	66a50513          	addi	a0,a0,1642 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200b6e:	e5cff0ef          	jal	ra,ffffffffc02001ca <__panic>
        size_t cnt = 0;
ffffffffc0200b72:	4601                	li	a2,0
ffffffffc0200b74:	bdc9                	j	ffffffffc0200a46 <bs_check+0x1ee>
            assert(PageProperty(block));
ffffffffc0200b76:	00002697          	auipc	a3,0x2
ffffffffc0200b7a:	62a68693          	addi	a3,a3,1578 # ffffffffc02031a0 <etext+0x41c>
ffffffffc0200b7e:	00002617          	auipc	a2,0x2
ffffffffc0200b82:	63a60613          	addi	a2,a2,1594 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200b86:	0d100593          	li	a1,209
ffffffffc0200b8a:	00002517          	auipc	a0,0x2
ffffffffc0200b8e:	64650513          	addi	a0,a0,1606 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200b92:	e38ff0ef          	jal	ra,ffffffffc02001ca <__panic>
            assert((page2ppn(block) & ((1UL << k) - 1)) == 0);
ffffffffc0200b96:	00002697          	auipc	a3,0x2
ffffffffc0200b9a:	67268693          	addi	a3,a3,1650 # ffffffffc0203208 <etext+0x484>
ffffffffc0200b9e:	00002617          	auipc	a2,0x2
ffffffffc0200ba2:	61a60613          	addi	a2,a2,1562 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200ba6:	0d300593          	li	a1,211
ffffffffc0200baa:	00002517          	auipc	a0,0x2
ffffffffc0200bae:	62650513          	addi	a0,a0,1574 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200bb2:	e18ff0ef          	jal	ra,ffffffffc02001ca <__panic>
            assert(block->property == (1UL << k));
ffffffffc0200bb6:	00002697          	auipc	a3,0x2
ffffffffc0200bba:	63268693          	addi	a3,a3,1586 # ffffffffc02031e8 <etext+0x464>
ffffffffc0200bbe:	00002617          	auipc	a2,0x2
ffffffffc0200bc2:	5fa60613          	addi	a2,a2,1530 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200bc6:	0d200593          	li	a1,210
ffffffffc0200bca:	00002517          	auipc	a0,0x2
ffffffffc0200bce:	60650513          	addi	a0,a0,1542 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200bd2:	df8ff0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(q != NULL);
ffffffffc0200bd6:	00002697          	auipc	a3,0x2
ffffffffc0200bda:	7e268693          	addi	a3,a3,2018 # ffffffffc02033b8 <etext+0x634>
ffffffffc0200bde:	00002617          	auipc	a2,0x2
ffffffffc0200be2:	5da60613          	addi	a2,a2,1498 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200be6:	0dd00593          	li	a1,221
ffffffffc0200bea:	00002517          	auipc	a0,0x2
ffffffffc0200bee:	5e650513          	addi	a0,a0,1510 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200bf2:	dd8ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(total > 0);
ffffffffc0200bf6:	00002697          	auipc	a3,0x2
ffffffffc0200bfa:	66268693          	addi	a3,a3,1634 # ffffffffc0203258 <etext+0x4d4>
ffffffffc0200bfe:	00002617          	auipc	a2,0x2
ffffffffc0200c02:	5ba60613          	addi	a2,a2,1466 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200c06:	0b500593          	li	a1,181
ffffffffc0200c0a:	00002517          	auipc	a0,0x2
ffffffffc0200c0e:	5c650513          	addi	a0,a0,1478 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200c12:	db8ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(total == bs_nr_free_pages());
ffffffffc0200c16:	00002697          	auipc	a3,0x2
ffffffffc0200c1a:	65268693          	addi	a3,a3,1618 # ffffffffc0203268 <etext+0x4e4>
ffffffffc0200c1e:	00002617          	auipc	a2,0x2
ffffffffc0200c22:	59a60613          	addi	a2,a2,1434 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200c26:	0b600593          	li	a1,182
ffffffffc0200c2a:	00002517          	auipc	a0,0x2
ffffffffc0200c2e:	5a650513          	addi	a0,a0,1446 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200c32:	d98ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(p0 != NULL);
ffffffffc0200c36:	00002697          	auipc	a3,0x2
ffffffffc0200c3a:	65268693          	addi	a3,a3,1618 # ffffffffc0203288 <etext+0x504>
ffffffffc0200c3e:	00002617          	auipc	a2,0x2
ffffffffc0200c42:	57a60613          	addi	a2,a2,1402 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200c46:	0ba00593          	li	a1,186
ffffffffc0200c4a:	00002517          	auipc	a0,0x2
ffffffffc0200c4e:	58650513          	addi	a0,a0,1414 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200c52:	d78ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(!PageProperty(p0));
ffffffffc0200c56:	00002697          	auipc	a3,0x2
ffffffffc0200c5a:	64268693          	addi	a3,a3,1602 # ffffffffc0203298 <etext+0x514>
ffffffffc0200c5e:	00002617          	auipc	a2,0x2
ffffffffc0200c62:	55a60613          	addi	a2,a2,1370 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200c66:	0bb00593          	li	a1,187
ffffffffc0200c6a:	00002517          	auipc	a0,0x2
ffffffffc0200c6e:	56650513          	addi	a0,a0,1382 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200c72:	d58ff0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(cnt == block_count[k]);
ffffffffc0200c76:	00002697          	auipc	a3,0x2
ffffffffc0200c7a:	70268693          	addi	a3,a3,1794 # ffffffffc0203378 <etext+0x5f4>
ffffffffc0200c7e:	00002617          	auipc	a2,0x2
ffffffffc0200c82:	53a60613          	addi	a2,a2,1338 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200c86:	0d600593          	li	a1,214
ffffffffc0200c8a:	00002517          	auipc	a0,0x2
ffffffffc0200c8e:	54650513          	addi	a0,a0,1350 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200c92:	d38ff0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(free_area[k].nr_free == (cnt << k));
ffffffffc0200c96:	00002697          	auipc	a3,0x2
ffffffffc0200c9a:	6fa68693          	addi	a3,a3,1786 # ffffffffc0203390 <etext+0x60c>
ffffffffc0200c9e:	00002617          	auipc	a2,0x2
ffffffffc0200ca2:	51a60613          	addi	a2,a2,1306 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200ca6:	0d700593          	li	a1,215
ffffffffc0200caa:	00002517          	auipc	a0,0x2
ffffffffc0200cae:	52650513          	addi	a0,a0,1318 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200cb2:	d18ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(bs_nr_free_pages() + 13 == total);
ffffffffc0200cb6:	00002697          	auipc	a3,0x2
ffffffffc0200cba:	67a68693          	addi	a3,a3,1658 # ffffffffc0203330 <etext+0x5ac>
ffffffffc0200cbe:	00002617          	auipc	a2,0x2
ffffffffc0200cc2:	4fa60613          	addi	a2,a2,1274 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200cc6:	0c300593          	li	a1,195
ffffffffc0200cca:	00002517          	auipc	a0,0x2
ffffffffc0200cce:	50650513          	addi	a0,a0,1286 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200cd2:	cf8ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(bs_nr_free_pages() == total);
ffffffffc0200cd6:	00002697          	auipc	a3,0x2
ffffffffc0200cda:	68268693          	addi	a3,a3,1666 # ffffffffc0203358 <etext+0x5d4>
ffffffffc0200cde:	00002617          	auipc	a2,0x2
ffffffffc0200ce2:	4da60613          	addi	a2,a2,1242 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200ce6:	0c800593          	li	a1,200
ffffffffc0200cea:	00002517          	auipc	a0,0x2
ffffffffc0200cee:	4e650513          	addi	a0,a0,1254 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200cf2:	cd8ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((page2ppn(p0) & 7) == 0);
ffffffffc0200cf6:	00002697          	auipc	a3,0x2
ffffffffc0200cfa:	5ba68693          	addi	a3,a3,1466 # ffffffffc02032b0 <etext+0x52c>
ffffffffc0200cfe:	00002617          	auipc	a2,0x2
ffffffffc0200d02:	4ba60613          	addi	a2,a2,1210 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200d06:	0bc00593          	li	a1,188
ffffffffc0200d0a:	00002517          	auipc	a0,0x2
ffffffffc0200d0e:	4c650513          	addi	a0,a0,1222 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200d12:	cb8ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(bs_nr_free_pages() + 8 == total);
ffffffffc0200d16:	00002697          	auipc	a3,0x2
ffffffffc0200d1a:	5b268693          	addi	a3,a3,1458 # ffffffffc02032c8 <etext+0x544>
ffffffffc0200d1e:	00002617          	auipc	a2,0x2
ffffffffc0200d22:	49a60613          	addi	a2,a2,1178 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200d26:	0bd00593          	li	a1,189
ffffffffc0200d2a:	00002517          	auipc	a0,0x2
ffffffffc0200d2e:	4a650513          	addi	a0,a0,1190 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200d32:	c98ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(p1 != NULL && p2 != NULL);
ffffffffc0200d36:	00002697          	auipc	a3,0x2
ffffffffc0200d3a:	5b268693          	addi	a3,a3,1458 # ffffffffc02032e8 <etext+0x564>
ffffffffc0200d3e:	00002617          	auipc	a2,0x2
ffffffffc0200d42:	47a60613          	addi	a2,a2,1146 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200d46:	0c100593          	li	a1,193
ffffffffc0200d4a:	00002517          	auipc	a0,0x2
ffffffffc0200d4e:	48650513          	addi	a0,a0,1158 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200d52:	c78ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200d56:	00002697          	auipc	a3,0x2
ffffffffc0200d5a:	5b268693          	addi	a3,a3,1458 # ffffffffc0203308 <etext+0x584>
ffffffffc0200d5e:	00002617          	auipc	a2,0x2
ffffffffc0200d62:	45a60613          	addi	a2,a2,1114 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200d66:	0c200593          	li	a1,194
ffffffffc0200d6a:	00002517          	auipc	a0,0x2
ffffffffc0200d6e:	46650513          	addi	a0,a0,1126 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200d72:	c58ff0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(pages == free_area[k].nr_free);
ffffffffc0200d76:	00002697          	auipc	a3,0x2
ffffffffc0200d7a:	4c268693          	addi	a3,a3,1218 # ffffffffc0203238 <etext+0x4b4>
ffffffffc0200d7e:	00002617          	auipc	a2,0x2
ffffffffc0200d82:	43a60613          	addi	a2,a2,1082 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200d86:	0b100593          	li	a1,177
ffffffffc0200d8a:	00002517          	auipc	a0,0x2
ffffffffc0200d8e:	44650513          	addi	a0,a0,1094 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200d92:	c38ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(bs_nr_free_pages() == total);
ffffffffc0200d96:	00002697          	auipc	a3,0x2
ffffffffc0200d9a:	5c268693          	addi	a3,a3,1474 # ffffffffc0203358 <etext+0x5d4>
ffffffffc0200d9e:	00002617          	auipc	a2,0x2
ffffffffc0200da2:	41a60613          	addi	a2,a2,1050 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200da6:	0ec00593          	li	a1,236
ffffffffc0200daa:	00002517          	auipc	a0,0x2
ffffffffc0200dae:	42650513          	addi	a0,a0,1062 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200db2:	c18ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(bs_nr_free_pages() + 4 == total);
ffffffffc0200db6:	00002697          	auipc	a3,0x2
ffffffffc0200dba:	64a68693          	addi	a3,a3,1610 # ffffffffc0203400 <etext+0x67c>
ffffffffc0200dbe:	00002617          	auipc	a2,0x2
ffffffffc0200dc2:	3fa60613          	addi	a2,a2,1018 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200dc6:	0e800593          	li	a1,232
ffffffffc0200dca:	00002517          	auipc	a0,0x2
ffffffffc0200dce:	40650513          	addi	a0,a0,1030 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200dd2:	bf8ff0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert((q[i] = alloc_page()) != NULL);
ffffffffc0200dd6:	00002697          	auipc	a3,0x2
ffffffffc0200dda:	60a68693          	addi	a3,a3,1546 # ffffffffc02033e0 <etext+0x65c>
ffffffffc0200dde:	00002617          	auipc	a2,0x2
ffffffffc0200de2:	3da60613          	addi	a2,a2,986 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200de6:	0e600593          	li	a1,230
ffffffffc0200dea:	00002517          	auipc	a0,0x2
ffffffffc0200dee:	3e650513          	addi	a0,a0,998 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200df2:	bd8ff0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(bs_nr_free_pages() == total);
ffffffffc0200df6:	00002697          	auipc	a3,0x2
ffffffffc0200dfa:	56268693          	addi	a3,a3,1378 # ffffffffc0203358 <etext+0x5d4>
ffffffffc0200dfe:	00002617          	auipc	a2,0x2
ffffffffc0200e02:	3ba60613          	addi	a2,a2,954 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200e06:	0e000593          	li	a1,224
ffffffffc0200e0a:	00002517          	auipc	a0,0x2
ffffffffc0200e0e:	3c650513          	addi	a0,a0,966 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200e12:	bb8ff0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(!PageProperty(q));
ffffffffc0200e16:	00002697          	auipc	a3,0x2
ffffffffc0200e1a:	5b268693          	addi	a3,a3,1458 # ffffffffc02033c8 <etext+0x644>
ffffffffc0200e1e:	00002617          	auipc	a2,0x2
ffffffffc0200e22:	39a60613          	addi	a2,a2,922 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200e26:	0de00593          	li	a1,222
ffffffffc0200e2a:	00002517          	auipc	a0,0x2
ffffffffc0200e2e:	3a650513          	addi	a0,a0,934 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200e32:	b98ff0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0200e36 <bs_free_pages>:
bs_free_pages(struct Page *base, size_t n) {
ffffffffc0200e36:	1141                	addi	sp,sp,-16
ffffffffc0200e38:	e406                	sd	ra,8(sp)
ffffffffc0200e3a:	e022                	sd	s0,0(sp)
    assert(n > 0);
ffffffffc0200e3c:	1a058c63          	beqz	a1,ffffffffc0200ff4 <bs_free_pages+0x1be>
ffffffffc0200e40:	4601                	li	a2,0
ffffffffc0200e42:	4705                	li	a4,1
ffffffffc0200e44:	487d                	li	a6,31
ffffffffc0200e46:	a021                	j	ffffffffc0200e4e <bs_free_pages+0x18>
    while (order + 1 < BS_MAX_ORDER && (1UL << order) < n) {
ffffffffc0200e48:	0605                	addi	a2,a2,1
ffffffffc0200e4a:	17060463          	beq	a2,a6,ffffffffc0200fb2 <bs_free_pages+0x17c>
ffffffffc0200e4e:	0006079b          	sext.w	a5,a2
ffffffffc0200e52:	00f716b3          	sll	a3,a4,a5
ffffffffc0200e56:	feb6e9e3          	bltu	a3,a1,ffffffffc0200e48 <bs_free_pages+0x12>
ffffffffc0200e5a:	02800593          	li	a1,40
ffffffffc0200e5e:	00f597b3          	sll	a5,a1,a5
    for (; p != base + size; p ++) {
ffffffffc0200e62:	00f505b3          	add	a1,a0,a5
ffffffffc0200e66:	87aa                	mv	a5,a0
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200e68:	6798                	ld	a4,8(a5)
ffffffffc0200e6a:	8b0d                	andi	a4,a4,3
ffffffffc0200e6c:	16071463          	bnez	a4,ffffffffc0200fd4 <bs_free_pages+0x19e>
        p->flags = p->property = 0;
ffffffffc0200e70:	0007a823          	sw	zero,16(a5)
ffffffffc0200e74:	0007b423          	sd	zero,8(a5)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200e78:	0007a023          	sw	zero,0(a5)
    for (; p != base + size; p ++) {
ffffffffc0200e7c:	02878793          	addi	a5,a5,40
ffffffffc0200e80:	feb794e3          	bne	a5,a1,ffffffffc0200e68 <bs_free_pages+0x32>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200e84:	00007e17          	auipc	t3,0x7
ffffffffc0200e88:	5f4e3e03          	ld	t3,1524(t3) # ffffffffc0208478 <pages>
ffffffffc0200e8c:	41c507b3          	sub	a5,a0,t3
ffffffffc0200e90:	878d                	srai	a5,a5,0x3
ffffffffc0200e92:	00003e97          	auipc	t4,0x3
ffffffffc0200e96:	446ebe83          	ld	t4,1094(t4) # ffffffffc02042d8 <nbase+0x8>
ffffffffc0200e9a:	03d787b3          	mul	a5,a5,t4
ffffffffc0200e9e:	00003897          	auipc	a7,0x3
ffffffffc0200ea2:	4328b883          	ld	a7,1074(a7) # ffffffffc02042d0 <nbase>
    assert((page2ppn(base) & (size - 1)) == 0);
ffffffffc0200ea6:	fff68713          	addi	a4,a3,-1
ffffffffc0200eaa:	97c6                	add	a5,a5,a7
ffffffffc0200eac:	8f7d                	and	a4,a4,a5
ffffffffc0200eae:	16071363          	bnez	a4,ffffffffc0201014 <bs_free_pages+0x1de>
    SetPageProperty(base);
ffffffffc0200eb2:	6518                	ld	a4,8(a0)
    base->property = size;
ffffffffc0200eb4:	0006859b          	sext.w	a1,a3
ffffffffc0200eb8:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0200eba:	00276713          	ori	a4,a4,2
ffffffffc0200ebe:	e518                	sd	a4,8(a0)
    while (order + 1 < BS_MAX_ORDER) {
ffffffffc0200ec0:	00160313          	addi	t1,a2,1
ffffffffc0200ec4:	02000713          	li	a4,32
ffffffffc0200ec8:	10e30063          	beq	t1,a4,ffffffffc0200fc8 <bs_free_pages+0x192>
        size_t buddy_ppn = page2ppn(base) ^ size;
ffffffffc0200ecc:	8fb5                	xor	a5,a5,a3
        if (buddy_ppn < nbase || buddy_ppn >= npage) {
ffffffffc0200ece:	0f17ee63          	bltu	a5,a7,ffffffffc0200fca <bs_free_pages+0x194>
ffffffffc0200ed2:	00161813          	slli	a6,a2,0x1
ffffffffc0200ed6:	9832                	add	a6,a6,a2
ffffffffc0200ed8:	080e                	slli	a6,a6,0x3
ffffffffc0200eda:	00007297          	auipc	t0,0x7
ffffffffc0200ede:	13e28293          	addi	t0,t0,318 # ffffffffc0208018 <free_area>
ffffffffc0200ee2:	0841                	addi	a6,a6,16
ffffffffc0200ee4:	00007f17          	auipc	t5,0x7
ffffffffc0200ee8:	56cf3f03          	ld	t5,1388(t5) # ffffffffc0208450 <npage>
ffffffffc0200eec:	9816                	add	a6,a6,t0
    while (order + 1 < BS_MAX_ORDER) {
ffffffffc0200eee:	02000f93          	li	t6,32
ffffffffc0200ef2:	fff30613          	addi	a2,t1,-1
        if (buddy_ppn < nbase || buddy_ppn >= npage) {
ffffffffc0200ef6:	09e7f663          	bgeu	a5,t5,ffffffffc0200f82 <bs_free_pages+0x14c>
        struct Page *buddy = pages + (buddy_ppn - nbase);
ffffffffc0200efa:	41178733          	sub	a4,a5,a7
ffffffffc0200efe:	00271793          	slli	a5,a4,0x2
ffffffffc0200f02:	97ba                	add	a5,a5,a4
ffffffffc0200f04:	078e                	slli	a5,a5,0x3
ffffffffc0200f06:	97f2                	add	a5,a5,t3
        if (!PageProperty(buddy) || buddy->property != size) {
ffffffffc0200f08:	6798                	ld	a4,8(a5)
ffffffffc0200f0a:	8b09                	andi	a4,a4,2
ffffffffc0200f0c:	cb3d                	beqz	a4,ffffffffc0200f82 <bs_free_pages+0x14c>
ffffffffc0200f0e:	0107e703          	lwu	a4,16(a5)
ffffffffc0200f12:	06e69863          	bne	a3,a4,ffffffffc0200f82 <bs_free_pages+0x14c>
    __list_del(listelm->prev, listelm->next);
ffffffffc0200f16:	6f80                	ld	s0,24(a5)
ffffffffc0200f18:	0207b383          	ld	t2,32(a5)
        free_area[order].nr_free -= size;
ffffffffc0200f1c:	00082603          	lw	a2,0(a6)
        struct Page *lo = base < buddy ? base : buddy;
ffffffffc0200f20:	873e                	mv	a4,a5
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200f22:	00743423          	sd	t2,8(s0)
    next->prev = prev;
ffffffffc0200f26:	0083b023          	sd	s0,0(t2)
        free_area[order].nr_free -= size;
ffffffffc0200f2a:	9e0d                	subw	a2,a2,a1
ffffffffc0200f2c:	00c82023          	sw	a2,0(a6)
        struct Page *lo = base < buddy ? base : buddy;
ffffffffc0200f30:	00f57363          	bgeu	a0,a5,ffffffffc0200f36 <bs_free_pages+0x100>
ffffffffc0200f34:	872a                	mv	a4,a0
        struct Page *hi = base < buddy ? buddy : base;
ffffffffc0200f36:	00a7f363          	bgeu	a5,a0,ffffffffc0200f3c <bs_free_pages+0x106>
ffffffffc0200f3a:	87aa                	mv	a5,a0
        ClearPageProperty(hi);
ffffffffc0200f3c:	6790                	ld	a2,8(a5)
        hi->property = 0;
ffffffffc0200f3e:	0007a823          	sw	zero,16(a5)
        lo->property = size << 1;
ffffffffc0200f42:	0015959b          	slliw	a1,a1,0x1
        ClearPageProperty(hi);
ffffffffc0200f46:	9a75                	andi	a2,a2,-3
ffffffffc0200f48:	e790                	sd	a2,8(a5)
        SetPageProperty(lo);
ffffffffc0200f4a:	671c                	ld	a5,8(a4)
        size <<= 1;
ffffffffc0200f4c:	0686                	slli	a3,a3,0x1
        lo->property = size << 1;
ffffffffc0200f4e:	cb0c                	sw	a1,16(a4)
        SetPageProperty(lo);
ffffffffc0200f50:	0027e793          	ori	a5,a5,2
ffffffffc0200f54:	e71c                	sd	a5,8(a4)
    while (order + 1 < BS_MAX_ORDER) {
ffffffffc0200f56:	00130613          	addi	a2,t1,1
ffffffffc0200f5a:	0006859b          	sext.w	a1,a3
ffffffffc0200f5e:	05f60f63          	beq	a2,t6,ffffffffc0200fbc <bs_free_pages+0x186>
ffffffffc0200f62:	41c707b3          	sub	a5,a4,t3
ffffffffc0200f66:	878d                	srai	a5,a5,0x3
ffffffffc0200f68:	03d787b3          	mul	a5,a5,t4
ffffffffc0200f6c:	0861                	addi	a6,a6,24
ffffffffc0200f6e:	97c6                	add	a5,a5,a7
        size_t buddy_ppn = page2ppn(base) ^ size;
ffffffffc0200f70:	8fb5                	xor	a5,a5,a3
        if (buddy_ppn < nbase || buddy_ppn >= npage) {
ffffffffc0200f72:	0517e863          	bltu	a5,a7,ffffffffc0200fc2 <bs_free_pages+0x18c>
ffffffffc0200f76:	8332                	mv	t1,a2
ffffffffc0200f78:	853a                	mv	a0,a4
ffffffffc0200f7a:	fff30613          	addi	a2,t1,-1
ffffffffc0200f7e:	f7e7eee3          	bltu	a5,t5,ffffffffc0200efa <bs_free_pages+0xc4>
    __list_add(elm, listelm, listelm->next);
ffffffffc0200f82:	00161793          	slli	a5,a2,0x1
ffffffffc0200f86:	963e                	add	a2,a2,a5
ffffffffc0200f88:	060e                	slli	a2,a2,0x3
ffffffffc0200f8a:	92b2                	add	t0,t0,a2
ffffffffc0200f8c:	0082b703          	ld	a4,8(t0)
    free_area[order].nr_free += size;
ffffffffc0200f90:	0102a783          	lw	a5,16(t0)
    list_add(&(free_area[order].free_list), &(base->page_link));
ffffffffc0200f94:	01850693          	addi	a3,a0,24
    prev->next = next->prev = elm;
ffffffffc0200f98:	e314                	sd	a3,0(a4)
ffffffffc0200f9a:	00d2b423          	sd	a3,8(t0)
}
ffffffffc0200f9e:	60a2                	ld	ra,8(sp)
ffffffffc0200fa0:	6402                	ld	s0,0(sp)
    elm->next = next;
ffffffffc0200fa2:	f118                	sd	a4,32(a0)
    elm->prev = prev;
ffffffffc0200fa4:	00553c23          	sd	t0,24(a0)
    free_area[order].nr_free += size;
ffffffffc0200fa8:	9dbd                	addw	a1,a1,a5
ffffffffc0200faa:	00b2a823          	sw	a1,16(t0)
}
ffffffffc0200fae:	0141                	addi	sp,sp,16
ffffffffc0200fb0:	8082                	ret
ffffffffc0200fb2:	4795                	li	a5,5
ffffffffc0200fb4:	178a                	slli	a5,a5,0x22
ffffffffc0200fb6:	01f71693          	slli	a3,a4,0x1f
ffffffffc0200fba:	b565                	j	ffffffffc0200e62 <bs_free_pages+0x2c>
ffffffffc0200fbc:	853a                	mv	a0,a4
ffffffffc0200fbe:	467d                	li	a2,31
ffffffffc0200fc0:	b7c9                	j	ffffffffc0200f82 <bs_free_pages+0x14c>
ffffffffc0200fc2:	861a                	mv	a2,t1
ffffffffc0200fc4:	853a                	mv	a0,a4
ffffffffc0200fc6:	bf75                	j	ffffffffc0200f82 <bs_free_pages+0x14c>
    while (order + 1 < BS_MAX_ORDER) {
ffffffffc0200fc8:	467d                	li	a2,31
ffffffffc0200fca:	00007297          	auipc	t0,0x7
ffffffffc0200fce:	04e28293          	addi	t0,t0,78 # ffffffffc0208018 <free_area>
ffffffffc0200fd2:	bf45                	j	ffffffffc0200f82 <bs_free_pages+0x14c>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200fd4:	00002697          	auipc	a3,0x2
ffffffffc0200fd8:	45468693          	addi	a3,a3,1108 # ffffffffc0203428 <etext+0x6a4>
ffffffffc0200fdc:	00002617          	auipc	a2,0x2
ffffffffc0200fe0:	1dc60613          	addi	a2,a2,476 # ffffffffc02031b8 <etext+0x434>
ffffffffc0200fe4:	06c00593          	li	a1,108
ffffffffc0200fe8:	00002517          	auipc	a0,0x2
ffffffffc0200fec:	1e850513          	addi	a0,a0,488 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0200ff0:	9daff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(n > 0);
ffffffffc0200ff4:	00002697          	auipc	a3,0x2
ffffffffc0200ff8:	42c68693          	addi	a3,a3,1068 # ffffffffc0203420 <etext+0x69c>
ffffffffc0200ffc:	00002617          	auipc	a2,0x2
ffffffffc0201000:	1bc60613          	addi	a2,a2,444 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201004:	06500593          	li	a1,101
ffffffffc0201008:	00002517          	auipc	a0,0x2
ffffffffc020100c:	1c850513          	addi	a0,a0,456 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0201010:	9baff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((page2ppn(base) & (size - 1)) == 0);
ffffffffc0201014:	00002697          	auipc	a3,0x2
ffffffffc0201018:	43c68693          	addi	a3,a3,1084 # ffffffffc0203450 <etext+0x6cc>
ffffffffc020101c:	00002617          	auipc	a2,0x2
ffffffffc0201020:	19c60613          	addi	a2,a2,412 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201024:	07200593          	li	a1,114
ffffffffc0201028:	00002517          	auipc	a0,0x2
ffffffffc020102c:	1a850513          	addi	a0,a0,424 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0201030:	99aff0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0201034 <bs_alloc_pages>:
    assert(n > 0);
ffffffffc0201034:	cd71                	beqz	a0,ffffffffc0201110 <bs_alloc_pages+0xdc>
ffffffffc0201036:	4681                	li	a3,0
ffffffffc0201038:	4705                	li	a4,1
ffffffffc020103a:	467d                	li	a2,31
ffffffffc020103c:	a021                	j	ffffffffc0201044 <bs_alloc_pages+0x10>
    while (order + 1 < BS_MAX_ORDER && (1UL << order) < n) {
ffffffffc020103e:	0685                	addi	a3,a3,1
ffffffffc0201040:	00c68663          	beq	a3,a2,ffffffffc020104c <bs_alloc_pages+0x18>
ffffffffc0201044:	00d717b3          	sll	a5,a4,a3
ffffffffc0201048:	fea7ebe3          	bltu	a5,a0,ffffffffc020103e <bs_alloc_pages+0xa>
    while (k < BS_MAX_ORDER && list_empty(&(free_area[k].free_list))) {
ffffffffc020104c:	00169713          	slli	a4,a3,0x1
ffffffffc0201050:	9736                	add	a4,a4,a3
ffffffffc0201052:	00007617          	auipc	a2,0x7
ffffffffc0201056:	fc660613          	addi	a2,a2,-58 # ffffffffc0208018 <free_area>
ffffffffc020105a:	070e                	slli	a4,a4,0x3
ffffffffc020105c:	9732                	add	a4,a4,a2
ffffffffc020105e:	87b6                	mv	a5,a3
ffffffffc0201060:	02000593          	li	a1,32
    return list->next == list;
ffffffffc0201064:	00873303          	ld	t1,8(a4)
ffffffffc0201068:	00e31863          	bne	t1,a4,ffffffffc0201078 <bs_alloc_pages+0x44>
        k ++;
ffffffffc020106c:	0785                	addi	a5,a5,1
    while (k < BS_MAX_ORDER && list_empty(&(free_area[k].free_list))) {
ffffffffc020106e:	0761                	addi	a4,a4,24
ffffffffc0201070:	feb79ae3          	bne	a5,a1,ffffffffc0201064 <bs_alloc_pages+0x30>
        return NULL;
ffffffffc0201074:	4501                	li	a0,0
}
ffffffffc0201076:	8082                	ret
    free_area[k].nr_free -= (1UL << k);
ffffffffc0201078:	00179713          	slli	a4,a5,0x1
ffffffffc020107c:	973e                	add	a4,a4,a5
ffffffffc020107e:	070e                	slli	a4,a4,0x3
    __list_del(listelm->prev, listelm->next);
ffffffffc0201080:	00033e83          	ld	t4,0(t1)
ffffffffc0201084:	00833e03          	ld	t3,8(t1)
ffffffffc0201088:	00e608b3          	add	a7,a2,a4
ffffffffc020108c:	0108a503          	lw	a0,16(a7)
    ClearPageProperty(page);
ffffffffc0201090:	ff033583          	ld	a1,-16(t1)
    free_area[k].nr_free -= (1UL << k);
ffffffffc0201094:	4805                	li	a6,1
    prev->next = next;
ffffffffc0201096:	01ceb423          	sd	t3,8(t4)
ffffffffc020109a:	00f81833          	sll	a6,a6,a5
    next->prev = prev;
ffffffffc020109e:	01de3023          	sd	t4,0(t3)
ffffffffc02010a2:	4105053b          	subw	a0,a0,a6
ffffffffc02010a6:	00a8a823          	sw	a0,16(a7)
    ClearPageProperty(page);
ffffffffc02010aa:	99f5                	andi	a1,a1,-3
ffffffffc02010ac:	feb33823          	sd	a1,-16(t1)
    struct Page *page = le2page(list_next(&(free_area[k].free_list)), page_link);
ffffffffc02010b0:	fe830513          	addi	a0,t1,-24
    while (k > order) {
ffffffffc02010b4:	04f6f863          	bgeu	a3,a5,ffffffffc0201104 <bs_alloc_pages+0xd0>
ffffffffc02010b8:	1721                	addi	a4,a4,-24
ffffffffc02010ba:	963a                	add	a2,a2,a4
        struct Page *buddy = page + (1UL << k);
ffffffffc02010bc:	02800f13          	li	t5,40
        buddy->property = (1UL << k);
ffffffffc02010c0:	4e85                	li	t4,1
        k --;
ffffffffc02010c2:	17fd                	addi	a5,a5,-1
        struct Page *buddy = page + (1UL << k);
ffffffffc02010c4:	00ff1733          	sll	a4,t5,a5
ffffffffc02010c8:	972a                	add	a4,a4,a0
        SetPageProperty(buddy);
ffffffffc02010ca:	00873883          	ld	a7,8(a4)
        buddy->property = (1UL << k);
ffffffffc02010ce:	00fe95b3          	sll	a1,t4,a5
    __list_add(elm, listelm, listelm->next);
ffffffffc02010d2:	00863e03          	ld	t3,8(a2)
ffffffffc02010d6:	2581                	sext.w	a1,a1
ffffffffc02010d8:	cb0c                	sw	a1,16(a4)
        SetPageProperty(buddy);
ffffffffc02010da:	0028e893          	ori	a7,a7,2
        free_area[k].nr_free += (1UL << k);
ffffffffc02010de:	01062803          	lw	a6,16(a2)
        SetPageProperty(buddy);
ffffffffc02010e2:	01173423          	sd	a7,8(a4)
        list_add(&(free_area[k].free_list), &(buddy->page_link));
ffffffffc02010e6:	01870893          	addi	a7,a4,24
    prev->next = next->prev = elm;
ffffffffc02010ea:	011e3023          	sd	a7,0(t3)
ffffffffc02010ee:	01163423          	sd	a7,8(a2)
    elm->prev = prev;
ffffffffc02010f2:	ef10                	sd	a2,24(a4)
    elm->next = next;
ffffffffc02010f4:	03c73023          	sd	t3,32(a4)
        free_area[k].nr_free += (1UL << k);
ffffffffc02010f8:	00b805bb          	addw	a1,a6,a1
ffffffffc02010fc:	ca0c                	sw	a1,16(a2)
    while (k > order) {
ffffffffc02010fe:	1621                	addi	a2,a2,-24
ffffffffc0201100:	fcd791e3          	bne	a5,a3,ffffffffc02010c2 <bs_alloc_pages+0x8e>
    page->property = (1UL << order);
ffffffffc0201104:	4785                	li	a5,1
ffffffffc0201106:	00d796b3          	sll	a3,a5,a3
ffffffffc020110a:	fed32c23          	sw	a3,-8(t1)
    return page;
ffffffffc020110e:	8082                	ret
bs_alloc_pages(size_t n) {
ffffffffc0201110:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc0201112:	00002697          	auipc	a3,0x2
ffffffffc0201116:	30e68693          	addi	a3,a3,782 # ffffffffc0203420 <etext+0x69c>
ffffffffc020111a:	00002617          	auipc	a2,0x2
ffffffffc020111e:	09e60613          	addi	a2,a2,158 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201122:	04300593          	li	a1,67
ffffffffc0201126:	00002517          	auipc	a0,0x2
ffffffffc020112a:	0aa50513          	addi	a0,a0,170 # ffffffffc02031d0 <etext+0x44c>
bs_alloc_pages(size_t n) {
ffffffffc020112e:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0201130:	89aff0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0201134 <bs_init_memmap>:
bs_init_memmap(struct Page *base, size_t n) {
ffffffffc0201134:	1101                	addi	sp,sp,-32
ffffffffc0201136:	ec06                	sd	ra,24(sp)
ffffffffc0201138:	e822                	sd	s0,16(sp)
ffffffffc020113a:	e426                	sd	s1,8(sp)
    assert(n > 0);
ffffffffc020113c:	12058063          	beqz	a1,ffffffffc020125c <bs_init_memmap+0x128>
    for (; p != base + n; p ++) {
ffffffffc0201140:	00259693          	slli	a3,a1,0x2
ffffffffc0201144:	96ae                	add	a3,a3,a1
ffffffffc0201146:	068e                	slli	a3,a3,0x3
ffffffffc0201148:	96aa                	add	a3,a3,a0
ffffffffc020114a:	87aa                	mv	a5,a0
ffffffffc020114c:	00d50f63          	beq	a0,a3,ffffffffc020116a <bs_init_memmap+0x36>
        assert(PageReserved(p));
ffffffffc0201150:	6798                	ld	a4,8(a5)
ffffffffc0201152:	8b05                	andi	a4,a4,1
ffffffffc0201154:	c765                	beqz	a4,ffffffffc020123c <bs_init_memmap+0x108>
        p->flags = p->property = 0;
ffffffffc0201156:	0007a823          	sw	zero,16(a5)
ffffffffc020115a:	0007b423          	sd	zero,8(a5)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc020115e:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0201162:	02878793          	addi	a5,a5,40
ffffffffc0201166:	fed795e3          	bne	a5,a3,ffffffffc0201150 <bs_init_memmap+0x1c>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc020116a:	00007297          	auipc	t0,0x7
ffffffffc020116e:	30e2b283          	ld	t0,782(t0) # ffffffffc0208478 <pages>
ffffffffc0201172:	405502b3          	sub	t0,a0,t0
ffffffffc0201176:	00003797          	auipc	a5,0x3
ffffffffc020117a:	1627b783          	ld	a5,354(a5) # ffffffffc02042d8 <nbase+0x8>
ffffffffc020117e:	4032d293          	srai	t0,t0,0x3
ffffffffc0201182:	02f282b3          	mul	t0,t0,a5
               && (1UL << (order + 1)) <= avail
ffffffffc0201186:	4885                	li	a7,1
ffffffffc0201188:	00003797          	auipc	a5,0x3
ffffffffc020118c:	1487b783          	ld	a5,328(a5) # ffffffffc02042d0 <nbase>
    size_t done = 0;
ffffffffc0201190:	4f01                	li	t5,0
ffffffffc0201192:	00007f97          	auipc	t6,0x7
ffffffffc0201196:	e86f8f93          	addi	t6,t6,-378 # ffffffffc0208018 <free_area>
               && (((ppn + done) & ((1UL << (order + 1)) - 1)) == 0)) {
ffffffffc020119a:	5e7d                	li	t3,-1
        while (order + 1 < BS_MAX_ORDER
ffffffffc020119c:	4efd                	li	t4,31
ffffffffc020119e:	01f89393          	slli	t2,a7,0x1f
ffffffffc02011a2:	92be                	add	t0,t0,a5
        size_t avail = n - done;
ffffffffc02011a4:	41e58633          	sub	a2,a1,t5
ffffffffc02011a8:	4701                	li	a4,0
               && (((ppn + done) & ((1UL << (order + 1)) - 1)) == 0)) {
ffffffffc02011aa:	01e28333          	add	t1,t0,t5
ffffffffc02011ae:	a819                	j	ffffffffc02011c4 <bs_init_memmap+0x90>
ffffffffc02011b0:	00fe17b3          	sll	a5,t3,a5
ffffffffc02011b4:	fff7c793          	not	a5,a5
ffffffffc02011b8:	0067f7b3          	and	a5,a5,t1
ffffffffc02011bc:	ef81                	bnez	a5,ffffffffc02011d4 <bs_init_memmap+0xa0>
        while (order + 1 < BS_MAX_ORDER
ffffffffc02011be:	0705                	addi	a4,a4,1
ffffffffc02011c0:	07d70663          	beq	a4,t4,ffffffffc020122c <bs_init_memmap+0xf8>
               && (1UL << (order + 1)) <= avail
ffffffffc02011c4:	0017079b          	addiw	a5,a4,1
ffffffffc02011c8:	00f896b3          	sll	a3,a7,a5
ffffffffc02011cc:	0007081b          	sext.w	a6,a4
ffffffffc02011d0:	fed670e3          	bgeu	a2,a3,ffffffffc02011b0 <bs_init_memmap+0x7c>
ffffffffc02011d4:	00171693          	slli	a3,a4,0x1
ffffffffc02011d8:	00e68633          	add	a2,a3,a4
ffffffffc02011dc:	01089833          	sll	a6,a7,a6
ffffffffc02011e0:	060e                	slli	a2,a2,0x3
ffffffffc02011e2:	0008041b          	sext.w	s0,a6
        struct Page *block = base + done;
ffffffffc02011e6:	002f1793          	slli	a5,t5,0x2
ffffffffc02011ea:	97fa                	add	a5,a5,t5
ffffffffc02011ec:	078e                	slli	a5,a5,0x3
ffffffffc02011ee:	97aa                	add	a5,a5,a0
    __list_add(elm, listelm, listelm->next);
ffffffffc02011f0:	9736                	add	a4,a4,a3
ffffffffc02011f2:	070e                	slli	a4,a4,0x3
        SetPageProperty(block);
ffffffffc02011f4:	6794                	ld	a3,8(a5)
ffffffffc02011f6:	977e                	add	a4,a4,t6
ffffffffc02011f8:	6704                	ld	s1,8(a4)
ffffffffc02011fa:	0026e693          	ori	a3,a3,2
        free_area[order].nr_free += size;
ffffffffc02011fe:	01072303          	lw	t1,16(a4)
        SetPageProperty(block);
ffffffffc0201202:	e794                	sd	a3,8(a5)
        block->property = size;
ffffffffc0201204:	cb80                	sw	s0,16(a5)
        list_add(&(free_area[order].free_list), &(block->page_link));
ffffffffc0201206:	01878693          	addi	a3,a5,24
    prev->next = next->prev = elm;
ffffffffc020120a:	e094                	sd	a3,0(s1)
ffffffffc020120c:	e714                	sd	a3,8(a4)
ffffffffc020120e:	00cf86b3          	add	a3,t6,a2
    elm->next = next;
ffffffffc0201212:	f384                	sd	s1,32(a5)
    elm->prev = prev;
ffffffffc0201214:	ef94                	sd	a3,24(a5)
        free_area[order].nr_free += size;
ffffffffc0201216:	008307bb          	addw	a5,t1,s0
ffffffffc020121a:	cb1c                	sw	a5,16(a4)
        done += size;
ffffffffc020121c:	9f42                	add	t5,t5,a6
    while (done < n) {
ffffffffc020121e:	f8bf63e3          	bltu	t5,a1,ffffffffc02011a4 <bs_init_memmap+0x70>
}
ffffffffc0201222:	60e2                	ld	ra,24(sp)
ffffffffc0201224:	6442                	ld	s0,16(sp)
ffffffffc0201226:	64a2                	ld	s1,8(sp)
ffffffffc0201228:	6105                	addi	sp,sp,32
ffffffffc020122a:	8082                	ret
ffffffffc020122c:	80000437          	lui	s0,0x80000
ffffffffc0201230:	881e                	mv	a6,t2
ffffffffc0201232:	2e800613          	li	a2,744
ffffffffc0201236:	00171693          	slli	a3,a4,0x1
ffffffffc020123a:	b775                	j	ffffffffc02011e6 <bs_init_memmap+0xb2>
        assert(PageReserved(p));
ffffffffc020123c:	00002697          	auipc	a3,0x2
ffffffffc0201240:	23c68693          	addi	a3,a3,572 # ffffffffc0203478 <etext+0x6f4>
ffffffffc0201244:	00002617          	auipc	a2,0x2
ffffffffc0201248:	f7460613          	addi	a2,a2,-140 # ffffffffc02031b8 <etext+0x434>
ffffffffc020124c:	02500593          	li	a1,37
ffffffffc0201250:	00002517          	auipc	a0,0x2
ffffffffc0201254:	f8050513          	addi	a0,a0,-128 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0201258:	f73fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(n > 0);
ffffffffc020125c:	00002697          	auipc	a3,0x2
ffffffffc0201260:	1c468693          	addi	a3,a3,452 # ffffffffc0203420 <etext+0x69c>
ffffffffc0201264:	00002617          	auipc	a2,0x2
ffffffffc0201268:	f5460613          	addi	a2,a2,-172 # ffffffffc02031b8 <etext+0x434>
ffffffffc020126c:	02100593          	li	a1,33
ffffffffc0201270:	00002517          	auipc	a0,0x2
ffffffffc0201274:	f6050513          	addi	a0,a0,-160 # ffffffffc02031d0 <etext+0x44c>
ffffffffc0201278:	f53fe0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc020127c <slub_init>:
    return slub_page_kva(page);
}

void
slub_init(void) {
    for (int k = 0; k < SLUB_NR_CLASSES; k ++) {
ffffffffc020127c:	00007797          	auipc	a5,0x7
ffffffffc0201280:	09c78793          	addi	a5,a5,156 # ffffffffc0208318 <slub_caches>
ffffffffc0201284:	4701                	li	a4,0
        list_init(&(slub_caches[k].slabs));
        slub_caches[k].obj_size = SLUB_MIN_OBJ_SIZE << k;
ffffffffc0201286:	4821                	li	a6,8
        slub_caches[k].objs_per_slab = PGSIZE / slub_caches[k].obj_size;
ffffffffc0201288:	6505                	lui	a0,0x1
    for (int k = 0; k < SLUB_NR_CLASSES; k ++) {
ffffffffc020128a:	45a5                	li	a1,9
        slub_caches[k].obj_size = SLUB_MIN_OBJ_SIZE << k;
ffffffffc020128c:	00e816b3          	sll	a3,a6,a4
        slub_caches[k].objs_per_slab = PGSIZE / slub_caches[k].obj_size;
ffffffffc0201290:	02d55633          	divu	a2,a0,a3
    elm->prev = elm->next = elm;
ffffffffc0201294:	e79c                	sd	a5,8(a5)
ffffffffc0201296:	e39c                	sd	a5,0(a5)
        slub_caches[k].obj_size = SLUB_MIN_OBJ_SIZE << k;
ffffffffc0201298:	eb94                	sd	a3,16(a5)
    for (int k = 0; k < SLUB_NR_CLASSES; k ++) {
ffffffffc020129a:	2705                	addiw	a4,a4,1
ffffffffc020129c:	02078793          	addi	a5,a5,32
        slub_caches[k].objs_per_slab = PGSIZE / slub_caches[k].obj_size;
ffffffffc02012a0:	fec7bc23          	sd	a2,-8(a5)
    for (int k = 0; k < SLUB_NR_CLASSES; k ++) {
ffffffffc02012a4:	feb714e3          	bne	a4,a1,ffffffffc020128c <slub_init+0x10>
    }
}
ffffffffc02012a8:	8082                	ret

ffffffffc02012aa <slub_alloc>:

void *
slub_alloc(size_t size) {
ffffffffc02012aa:	7139                	addi	sp,sp,-64
ffffffffc02012ac:	fc06                	sd	ra,56(sp)
ffffffffc02012ae:	f822                	sd	s0,48(sp)
ffffffffc02012b0:	f426                	sd	s1,40(sp)
ffffffffc02012b2:	f04a                	sd	s2,32(sp)
ffffffffc02012b4:	ec4e                	sd	s3,24(sp)
    assert(size > 0);
ffffffffc02012b6:	20050563          	beqz	a0,ffffffffc02014c0 <slub_alloc+0x216>
    size_t rounded = size < SLUB_MIN_OBJ_SIZE ? SLUB_MIN_OBJ_SIZE : size;
ffffffffc02012ba:	47a1                	li	a5,8
ffffffffc02012bc:	86aa                	mv	a3,a0
ffffffffc02012be:	0cf56863          	bltu	a0,a5,ffffffffc020138e <slub_alloc+0xe4>
    if (rounded > SLUB_MAX_OBJ_SIZE) {
ffffffffc02012c2:	6785                	lui	a5,0x1
ffffffffc02012c4:	80078713          	addi	a4,a5,-2048 # 800 <kern_entry-0xffffffffc01ff800>
ffffffffc02012c8:	16a76c63          	bltu	a4,a0,ffffffffc0201440 <slub_alloc+0x196>
    while ((SLUB_MIN_OBJ_SIZE << k) < rounded) {
ffffffffc02012cc:	47a1                	li	a5,8
ffffffffc02012ce:	14a7ff63          	bgeu	a5,a0,ffffffffc020142c <slub_alloc+0x182>
    int k = 0;
ffffffffc02012d2:	4781                	li	a5,0
    while ((SLUB_MIN_OBJ_SIZE << k) < rounded) {
ffffffffc02012d4:	4621                	li	a2,8
        k ++;
ffffffffc02012d6:	2785                	addiw	a5,a5,1
    while ((SLUB_MIN_OBJ_SIZE << k) < rounded) {
ffffffffc02012d8:	00f61733          	sll	a4,a2,a5
ffffffffc02012dc:	fed76de3          	bltu	a4,a3,ffffffffc02012d6 <slub_alloc+0x2c>
ffffffffc02012e0:	00007417          	auipc	s0,0x7
ffffffffc02012e4:	03840413          	addi	s0,s0,56 # ffffffffc0208318 <slub_caches>
ffffffffc02012e8:	00579913          	slli	s2,a5,0x5
ffffffffc02012ec:	01240733          	add	a4,s0,s2
    return list->next == list;
ffffffffc02012f0:	012404b3          	add	s1,s0,s2
ffffffffc02012f4:	0084b983          	ld	s3,8(s1)
    }

    slub_cache_t *cache = &slub_caches[k];
    struct Page *page;

    if (list_empty(&(cache->slabs))) {
ffffffffc02012f8:	0ae98063          	beq	s3,a4,ffffffffc0201398 <slub_alloc+0xee>
        }
    } else {
        page = le2page(list_next(&(cache->slabs)), page_link);
    }

    assert(PageSlub(page));
ffffffffc02012fc:	ff09b783          	ld	a5,-16(s3)
        page = le2page(list_next(&(cache->slabs)), page_link);
ffffffffc0201300:	fe898713          	addi	a4,s3,-24
    assert(PageSlub(page));
ffffffffc0201304:	8b91                	andi	a5,a5,4
ffffffffc0201306:	1e078d63          	beqz	a5,ffffffffc0201500 <slub_alloc+0x256>
    assert(page->ref > 0);
ffffffffc020130a:	4310                	lw	a2,0(a4)
ffffffffc020130c:	20c05a63          	blez	a2,ffffffffc0201520 <slub_alloc+0x276>
    assert(page->property < cache->objs_per_slab);
ffffffffc0201310:	944a                	add	s0,s0,s2
ffffffffc0201312:	01076503          	lwu	a0,16(a4)
ffffffffc0201316:	6c1c                	ld	a5,24(s0)
ffffffffc0201318:	1cf57463          	bgeu	a0,a5,ffffffffc02014e0 <slub_alloc+0x236>
ffffffffc020131c:	00007797          	auipc	a5,0x7
ffffffffc0201320:	15c7b783          	ld	a5,348(a5) # ffffffffc0208478 <pages>
ffffffffc0201324:	40f707b3          	sub	a5,a4,a5
ffffffffc0201328:	00003697          	auipc	a3,0x3
ffffffffc020132c:	fb06b683          	ld	a3,-80(a3) # ffffffffc02042d8 <nbase+0x8>
ffffffffc0201330:	878d                	srai	a5,a5,0x3
ffffffffc0201332:	02d787b3          	mul	a5,a5,a3

    char *base = (char *)slub_page_kva(page);
    void *obj = base + (size_t)page->property * cache->obj_size;
ffffffffc0201336:	01043803          	ld	a6,16(s0)
ffffffffc020133a:	00003697          	auipc	a3,0x3
ffffffffc020133e:	f966b683          	ld	a3,-106(a3) # ffffffffc02042d0 <nbase>
ffffffffc0201342:	03050533          	mul	a0,a0,a6
ffffffffc0201346:	97b6                	add	a5,a5,a3
    return page2ppn(page) << PGSHIFT;
ffffffffc0201348:	07b2                	slli	a5,a5,0xc
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc020134a:	00007697          	auipc	a3,0x7
ffffffffc020134e:	1266b683          	ld	a3,294(a3) # ffffffffc0208470 <va_pa_offset>
ffffffffc0201352:	97b6                	add	a5,a5,a3
    void *obj = base + (size_t)page->property * cache->obj_size;
ffffffffc0201354:	953e                	add	a0,a0,a5
    void *next = *(void **)obj;
ffffffffc0201356:	6114                	ld	a3,0(a0)

    if (next == NULL) {
ffffffffc0201358:	ce8d                	beqz	a3,ffffffffc0201392 <slub_alloc+0xe8>
        page->property = 0;     /* meaningless once the slab becomes full */
    } else {
        assert((uintptr_t)next >= (uintptr_t)base
ffffffffc020135a:	14f6e363          	bltu	a3,a5,ffffffffc02014a0 <slub_alloc+0x1f6>
ffffffffc020135e:	6585                	lui	a1,0x1
ffffffffc0201360:	95be                	add	a1,a1,a5
ffffffffc0201362:	12b6ff63          	bgeu	a3,a1,ffffffffc02014a0 <slub_alloc+0x1f6>
               && (uintptr_t)next < (uintptr_t)base + PGSIZE);
        page->property =
            (unsigned int)(((uintptr_t)next - (uintptr_t)base) / cache->obj_size);
ffffffffc0201366:	40f687b3          	sub	a5,a3,a5
ffffffffc020136a:	0307d7b3          	divu	a5,a5,a6
ffffffffc020136e:	cb1c                	sw	a5,16(a4)
    }

    page->ref --;
ffffffffc0201370:	fff6069b          	addiw	a3,a2,-1
ffffffffc0201374:	c314                	sw	a3,0(a4)
    if (page->ref == 0) {
ffffffffc0201376:	e689                	bnez	a3,ffffffffc0201380 <slub_alloc+0xd6>
    __list_del(listelm->prev, listelm->next);
ffffffffc0201378:	6f14                	ld	a3,24(a4)
ffffffffc020137a:	731c                	ld	a5,32(a4)
    prev->next = next;
ffffffffc020137c:	e69c                	sd	a5,8(a3)
    next->prev = prev;
ffffffffc020137e:	e394                	sd	a3,0(a5)
        /* The slab is full: it has nothing to offer other allocations. */
        list_del(&(page->page_link));
    }
    return obj;
}
ffffffffc0201380:	70e2                	ld	ra,56(sp)
ffffffffc0201382:	7442                	ld	s0,48(sp)
ffffffffc0201384:	74a2                	ld	s1,40(sp)
ffffffffc0201386:	7902                	ld	s2,32(sp)
ffffffffc0201388:	69e2                	ld	s3,24(sp)
ffffffffc020138a:	6121                	addi	sp,sp,64
ffffffffc020138c:	8082                	ret
    size_t rounded = size < SLUB_MIN_OBJ_SIZE ? SLUB_MIN_OBJ_SIZE : size;
ffffffffc020138e:	46a1                	li	a3,8
ffffffffc0201390:	bf0d                	j	ffffffffc02012c2 <slub_alloc+0x18>
        page->property = 0;     /* meaningless once the slab becomes full */
ffffffffc0201392:	00072823          	sw	zero,16(a4)
ffffffffc0201396:	bfe9                	j	ffffffffc0201370 <slub_alloc+0xc6>
    struct Page *page = pmm_manager->alloc_pages(1);
ffffffffc0201398:	00007717          	auipc	a4,0x7
ffffffffc020139c:	0d073703          	ld	a4,208(a4) # ffffffffc0208468 <pmm_manager>
ffffffffc02013a0:	6f18                	ld	a4,24(a4)
ffffffffc02013a2:	4505                	li	a0,1
ffffffffc02013a4:	e43e                	sd	a5,8(sp)
ffffffffc02013a6:	9702                	jalr	a4
ffffffffc02013a8:	872a                	mv	a4,a0
    if (page == NULL) {
ffffffffc02013aa:	c949                	beqz	a0,ffffffffc020143c <slub_alloc+0x192>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02013ac:	00007517          	auipc	a0,0x7
ffffffffc02013b0:	0cc53503          	ld	a0,204(a0) # ffffffffc0208478 <pages>
ffffffffc02013b4:	40a70533          	sub	a0,a4,a0
ffffffffc02013b8:	00003697          	auipc	a3,0x3
ffffffffc02013bc:	f206b683          	ld	a3,-224(a3) # ffffffffc02042d8 <nbase+0x8>
ffffffffc02013c0:	850d                	srai	a0,a0,0x3
ffffffffc02013c2:	02d50533          	mul	a0,a0,a3
    SetPageSlub(page, k);
ffffffffc02013c6:	67a2                	ld	a5,8(sp)
    page->ref = (int)cache->objs_per_slab;
ffffffffc02013c8:	6c8c                	ld	a1,24(s1)
ffffffffc02013ca:	00003617          	auipc	a2,0x3
ffffffffc02013ce:	f0663603          	ld	a2,-250(a2) # ffffffffc02042d0 <nbase>
    SetPageSlub(page, k);
ffffffffc02013d2:	07a2                	slli	a5,a5,0x8
ffffffffc02013d4:	0047e793          	ori	a5,a5,4
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc02013d8:	00007697          	auipc	a3,0x7
ffffffffc02013dc:	0986b683          	ld	a3,152(a3) # ffffffffc0208470 <va_pa_offset>
    SetPageSlub(page, k);
ffffffffc02013e0:	e71c                	sd	a5,8(a4)
    page->ref = (int)cache->objs_per_slab;
ffffffffc02013e2:	c30c                	sw	a1,0(a4)
    page->property = 0;
ffffffffc02013e4:	00072823          	sw	zero,16(a4)
ffffffffc02013e8:	9532                	add	a0,a0,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc02013ea:	0532                	slli	a0,a0,0xc
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc02013ec:	9536                	add	a0,a0,a3
    for (size_t i = 0; i < cache->objs_per_slab; i ++) {
ffffffffc02013ee:	4781                	li	a5,0
        void *obj = base + i * cache->obj_size;
ffffffffc02013f0:	86a6                	mv	a3,s1
    for (size_t i = 0; i < cache->objs_per_slab; i ++) {
ffffffffc02013f2:	c195                	beqz	a1,ffffffffc0201416 <slub_alloc+0x16c>
        void *obj = base + i * cache->obj_size;
ffffffffc02013f4:	6a90                	ld	a2,16(a3)
                            : NULL;
ffffffffc02013f6:	4801                	li	a6,0
        void *obj = base + i * cache->obj_size;
ffffffffc02013f8:	02f608b3          	mul	a7,a2,a5
        *(void **)obj = (i + 1 < cache->objs_per_slab)
ffffffffc02013fc:	0785                	addi	a5,a5,1
        void *obj = base + i * cache->obj_size;
ffffffffc02013fe:	01150333          	add	t1,a0,a7
                            : NULL;
ffffffffc0201402:	00b7f563          	bgeu	a5,a1,ffffffffc020140c <slub_alloc+0x162>
                            ? (void *)(base + (i + 1) * cache->obj_size)
ffffffffc0201406:	9646                	add	a2,a2,a7
                            : NULL;
ffffffffc0201408:	00c50833          	add	a6,a0,a2
        *(void **)obj = (i + 1 < cache->objs_per_slab)
ffffffffc020140c:	01033023          	sd	a6,0(t1)
    for (size_t i = 0; i < cache->objs_per_slab; i ++) {
ffffffffc0201410:	6e8c                	ld	a1,24(a3)
ffffffffc0201412:	feb7e1e3          	bltu	a5,a1,ffffffffc02013f4 <slub_alloc+0x14a>
    __list_add(elm, listelm, listelm->next);
ffffffffc0201416:	012406b3          	add	a3,s0,s2
ffffffffc020141a:	669c                	ld	a5,8(a3)
    list_add(&(cache->slabs), &(page->page_link));
ffffffffc020141c:	01870613          	addi	a2,a4,24
    prev->next = next->prev = elm;
ffffffffc0201420:	e390                	sd	a2,0(a5)
ffffffffc0201422:	e690                	sd	a2,8(a3)
    elm->next = next;
ffffffffc0201424:	f31c                	sd	a5,32(a4)
    elm->prev = prev;
ffffffffc0201426:	01373c23          	sd	s3,24(a4)
    assert(PageSlub(page));
ffffffffc020142a:	b5c5                	j	ffffffffc020130a <slub_alloc+0x60>
    while ((SLUB_MIN_OBJ_SIZE << k) < rounded) {
ffffffffc020142c:	00007417          	auipc	s0,0x7
ffffffffc0201430:	eec40413          	addi	s0,s0,-276 # ffffffffc0208318 <slub_caches>
ffffffffc0201434:	4781                	li	a5,0
ffffffffc0201436:	8722                	mv	a4,s0
ffffffffc0201438:	4901                	li	s2,0
ffffffffc020143a:	bd5d                	j	ffffffffc02012f0 <slub_alloc+0x46>
        return NULL;
ffffffffc020143c:	4501                	li	a0,0
ffffffffc020143e:	b789                	j	ffffffffc0201380 <slub_alloc+0xd6>
    if (size > (size_t)-1 - (PGSIZE - 1)) {
ffffffffc0201440:	777d                	lui	a4,0xfffff
ffffffffc0201442:	fea76de3          	bltu	a4,a0,ffffffffc020143c <slub_alloc+0x192>
    size_t npages = ROUNDUP(size, PGSIZE) / PGSIZE;
ffffffffc0201446:	17fd                	addi	a5,a5,-1
ffffffffc0201448:	953e                	add	a0,a0,a5
ffffffffc020144a:	00c55413          	srli	s0,a0,0xc
    if (npages == 0 || npages > 0xffffffffUL) {
ffffffffc020144e:	57fd                	li	a5,-1
ffffffffc0201450:	fff40713          	addi	a4,s0,-1
ffffffffc0201454:	9381                	srli	a5,a5,0x20
ffffffffc0201456:	fef773e3          	bgeu	a4,a5,ffffffffc020143c <slub_alloc+0x192>
    struct Page *page = pmm_manager->alloc_pages(npages);
ffffffffc020145a:	00007797          	auipc	a5,0x7
ffffffffc020145e:	00e7b783          	ld	a5,14(a5) # ffffffffc0208468 <pmm_manager>
ffffffffc0201462:	6f9c                	ld	a5,24(a5)
ffffffffc0201464:	8522                	mv	a0,s0
ffffffffc0201466:	9782                	jalr	a5
ffffffffc0201468:	87aa                	mv	a5,a0
    if (page == NULL) {
ffffffffc020146a:	d969                	beqz	a0,ffffffffc020143c <slub_alloc+0x192>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc020146c:	00007517          	auipc	a0,0x7
ffffffffc0201470:	00c53503          	ld	a0,12(a0) # ffffffffc0208478 <pages>
ffffffffc0201474:	40a78533          	sub	a0,a5,a0
ffffffffc0201478:	850d                	srai	a0,a0,0x3
ffffffffc020147a:	00003717          	auipc	a4,0x3
ffffffffc020147e:	e5e73703          	ld	a4,-418(a4) # ffffffffc02042d8 <nbase+0x8>
ffffffffc0201482:	02e50533          	mul	a0,a0,a4
    page->property = (unsigned int)npages;
ffffffffc0201486:	cb80                	sw	s0,16(a5)
ffffffffc0201488:	00003797          	auipc	a5,0x3
ffffffffc020148c:	e487b783          	ld	a5,-440(a5) # ffffffffc02042d0 <nbase>
ffffffffc0201490:	953e                	add	a0,a0,a5
    return page2ppn(page) << PGSHIFT;
ffffffffc0201492:	0532                	slli	a0,a0,0xc
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc0201494:	00007797          	auipc	a5,0x7
ffffffffc0201498:	fdc7b783          	ld	a5,-36(a5) # ffffffffc0208470 <va_pa_offset>
ffffffffc020149c:	953e                	add	a0,a0,a5
    return slub_page_kva(page);
ffffffffc020149e:	b5cd                	j	ffffffffc0201380 <slub_alloc+0xd6>
        assert((uintptr_t)next >= (uintptr_t)base
ffffffffc02014a0:	00002697          	auipc	a3,0x2
ffffffffc02014a4:	09868693          	addi	a3,a3,152 # ffffffffc0203538 <bs_pmm_manager+0xa0>
ffffffffc02014a8:	00002617          	auipc	a2,0x2
ffffffffc02014ac:	d1060613          	addi	a2,a2,-752 # ffffffffc02031b8 <etext+0x434>
ffffffffc02014b0:	0a900593          	li	a1,169
ffffffffc02014b4:	00002517          	auipc	a0,0x2
ffffffffc02014b8:	02c50513          	addi	a0,a0,44 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc02014bc:	d0ffe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(size > 0);
ffffffffc02014c0:	00002697          	auipc	a3,0x2
ffffffffc02014c4:	01068693          	addi	a3,a3,16 # ffffffffc02034d0 <bs_pmm_manager+0x38>
ffffffffc02014c8:	00002617          	auipc	a2,0x2
ffffffffc02014cc:	cf060613          	addi	a2,a2,-784 # ffffffffc02031b8 <etext+0x434>
ffffffffc02014d0:	08b00593          	li	a1,139
ffffffffc02014d4:	00002517          	auipc	a0,0x2
ffffffffc02014d8:	00c50513          	addi	a0,a0,12 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc02014dc:	ceffe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(page->property < cache->objs_per_slab);
ffffffffc02014e0:	00002697          	auipc	a3,0x2
ffffffffc02014e4:	03068693          	addi	a3,a3,48 # ffffffffc0203510 <bs_pmm_manager+0x78>
ffffffffc02014e8:	00002617          	auipc	a2,0x2
ffffffffc02014ec:	cd060613          	addi	a2,a2,-816 # ffffffffc02031b8 <etext+0x434>
ffffffffc02014f0:	0a000593          	li	a1,160
ffffffffc02014f4:	00002517          	auipc	a0,0x2
ffffffffc02014f8:	fec50513          	addi	a0,a0,-20 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc02014fc:	ccffe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(PageSlub(page));
ffffffffc0201500:	00002697          	auipc	a3,0x2
ffffffffc0201504:	ff068693          	addi	a3,a3,-16 # ffffffffc02034f0 <bs_pmm_manager+0x58>
ffffffffc0201508:	00002617          	auipc	a2,0x2
ffffffffc020150c:	cb060613          	addi	a2,a2,-848 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201510:	09e00593          	li	a1,158
ffffffffc0201514:	00002517          	auipc	a0,0x2
ffffffffc0201518:	fcc50513          	addi	a0,a0,-52 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc020151c:	caffe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(page->ref > 0);
ffffffffc0201520:	00002697          	auipc	a3,0x2
ffffffffc0201524:	fe068693          	addi	a3,a3,-32 # ffffffffc0203500 <bs_pmm_manager+0x68>
ffffffffc0201528:	00002617          	auipc	a2,0x2
ffffffffc020152c:	c9060613          	addi	a2,a2,-880 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201530:	09f00593          	li	a1,159
ffffffffc0201534:	00002517          	auipc	a0,0x2
ffffffffc0201538:	fac50513          	addi	a0,a0,-84 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc020153c:	c8ffe0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0201540 <slub_free>:
    }
}

void
slub_free(void *ptr) {
    if (ptr == NULL) {
ffffffffc0201540:	14050263          	beqz	a0,ffffffffc0201684 <slub_free+0x144>
slub_free(void *ptr) {
ffffffffc0201544:	1141                	addi	sp,sp,-16
ffffffffc0201546:	e406                	sd	ra,8(sp)
        return;
    }

    uintptr_t va = (uintptr_t)ptr;
    if (va < va_pa_offset) {
ffffffffc0201548:	00007617          	auipc	a2,0x7
ffffffffc020154c:	f2863603          	ld	a2,-216(a2) # ffffffffc0208470 <va_pa_offset>
ffffffffc0201550:	86aa                	mv	a3,a0
ffffffffc0201552:	16c56263          	bltu	a0,a2,ffffffffc02016b6 <slub_free+0x176>
    return pa2page((uintptr_t)ptr - va_pa_offset);
ffffffffc0201556:	40c507b3          	sub	a5,a0,a2
    if (PPN(pa) >= npage) {
ffffffffc020155a:	83b1                	srli	a5,a5,0xc
ffffffffc020155c:	00007717          	auipc	a4,0x7
ffffffffc0201560:	ef473703          	ld	a4,-268(a4) # ffffffffc0208450 <npage>
ffffffffc0201564:	12e7fd63          	bgeu	a5,a4,ffffffffc020169e <slub_free+0x15e>
    return &pages[PPN(pa) - nbase];
ffffffffc0201568:	00003597          	auipc	a1,0x3
ffffffffc020156c:	d685b583          	ld	a1,-664(a1) # ffffffffc02042d0 <nbase>
ffffffffc0201570:	40b78733          	sub	a4,a5,a1
ffffffffc0201574:	00271793          	slli	a5,a4,0x2
ffffffffc0201578:	97ba                	add	a5,a5,a4
ffffffffc020157a:	078e                	slli	a5,a5,0x3
ffffffffc020157c:	00007517          	auipc	a0,0x7
ffffffffc0201580:	efc53503          	ld	a0,-260(a0) # ffffffffc0208478 <pages>
ffffffffc0201584:	953e                	add	a0,a0,a5
        panic("slub_free: invalid pointer 0x%lx", va);
    }

    struct Page *page = slub_kva_to_page(ptr);
    if (PageSlub(page)) {
ffffffffc0201586:	6518                	ld	a4,8(a0)
ffffffffc0201588:	00477813          	andi	a6,a4,4
ffffffffc020158c:	00081e63          	bnez	a6,ffffffffc02015a8 <slub_free+0x68>
        slub_free_small(ptr, page);
        return;
    }

    /* Large allocation: page->property records how many pages it owns. */
    size_t npages = page->property;
ffffffffc0201590:	01056583          	lwu	a1,16(a0)
    if (npages == 0) {
ffffffffc0201594:	c9ed                	beqz	a1,ffffffffc0201686 <slub_free+0x146>
        panic("slub_free: 0x%lx is not a valid slub allocation", va);
    }
    pmm_manager->free_pages(page, npages);
ffffffffc0201596:	00007797          	auipc	a5,0x7
ffffffffc020159a:	ed27b783          	ld	a5,-302(a5) # ffffffffc0208468 <pmm_manager>
}
ffffffffc020159e:	60a2                	ld	ra,8(sp)
    pmm_manager->free_pages(page, npages);
ffffffffc02015a0:	0207b303          	ld	t1,32(a5)
}
ffffffffc02015a4:	0141                	addi	sp,sp,16
    pmm_manager->free_pages(page, npages);
ffffffffc02015a6:	8302                	jr	t1
    unsigned int k = (unsigned int)SlubClass(page);
ffffffffc02015a8:	8321                	srli	a4,a4,0x8
ffffffffc02015aa:	0ff77713          	andi	a4,a4,255
    assert(k < SLUB_NR_CLASSES);
ffffffffc02015ae:	4821                	li	a6,8
ffffffffc02015b0:	12e86f63          	bltu	a6,a4,ffffffffc02016ee <slub_free+0x1ae>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02015b4:	00003817          	auipc	a6,0x3
ffffffffc02015b8:	d2483803          	ld	a6,-732(a6) # ffffffffc02042d8 <nbase+0x8>
ffffffffc02015bc:	878d                	srai	a5,a5,0x3
ffffffffc02015be:	030787b3          	mul	a5,a5,a6
    assert(offset < PGSIZE);
ffffffffc02015c2:	6805                	lui	a6,0x1
ffffffffc02015c4:	97ae                	add	a5,a5,a1
    return page2ppn(page) << PGSHIFT;
ffffffffc02015c6:	07b2                	slli	a5,a5,0xc
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc02015c8:	97b2                	add	a5,a5,a2
    uintptr_t offset = (uintptr_t)ptr - (uintptr_t)base;
ffffffffc02015ca:	40f68633          	sub	a2,a3,a5
    assert(offset < PGSIZE);
ffffffffc02015ce:	11067063          	bgeu	a2,a6,ffffffffc02016ce <slub_free+0x18e>
    assert(cache->obj_size != 0 && offset % cache->obj_size == 0);
ffffffffc02015d2:	00571893          	slli	a7,a4,0x5
ffffffffc02015d6:	00007597          	auipc	a1,0x7
ffffffffc02015da:	d4258593          	addi	a1,a1,-702 # ffffffffc0208318 <slub_caches>
ffffffffc02015de:	98ae                	add	a7,a7,a1
ffffffffc02015e0:	0108b803          	ld	a6,16(a7)
ffffffffc02015e4:	1702                	slli	a4,a4,0x20
ffffffffc02015e6:	9301                	srli	a4,a4,0x20
ffffffffc02015e8:	16080363          	beqz	a6,ffffffffc020174e <slub_free+0x20e>
ffffffffc02015ec:	03067333          	remu	t1,a2,a6
ffffffffc02015f0:	14031f63          	bnez	t1,ffffffffc020174e <slub_free+0x20e>
    assert(page->ref < (int)cache->objs_per_slab);  /* catch double free */
ffffffffc02015f4:	0188b303          	ld	t1,24(a7)
ffffffffc02015f8:	00052883          	lw	a7,0(a0)
ffffffffc02015fc:	00030e1b          	sext.w	t3,t1
ffffffffc0201600:	13c8d763          	bge	a7,t3,ffffffffc020172e <slub_free+0x1ee>
    size_t idx = offset / cache->obj_size;
ffffffffc0201604:	03065633          	divu	a2,a2,a6
    assert(idx < cache->objs_per_slab);
ffffffffc0201608:	10667363          	bgeu	a2,t1,ffffffffc020170e <slub_free+0x1ce>
    if (!was_full) {
ffffffffc020160c:	02088763          	beqz	a7,ffffffffc020163a <slub_free+0xfa>
        assert(page->property < cache->objs_per_slab);
ffffffffc0201610:	01056e03          	lwu	t3,16(a0)
ffffffffc0201614:	146e7d63          	bgeu	t3,t1,ffffffffc020176e <slub_free+0x22e>
        old_head = base + (size_t)page->property * cache->obj_size;
ffffffffc0201618:	03c80833          	mul	a6,a6,t3
    page->ref ++;
ffffffffc020161c:	0018831b          	addiw	t1,a7,1
        old_head = base + (size_t)page->property * cache->obj_size;
ffffffffc0201620:	97c2                	add	a5,a5,a6
    *(void **)ptr = old_head;       /* push onto this slab's free list */
ffffffffc0201622:	e29c                	sd	a5,0(a3)
    page->property = (unsigned int)idx;
ffffffffc0201624:	c910                	sw	a2,16(a0)
    page->ref ++;
ffffffffc0201626:	00652023          	sw	t1,0(a0)
    if (page->ref == (int)cache->objs_per_slab) {
ffffffffc020162a:	0716                	slli	a4,a4,0x5
ffffffffc020162c:	972e                	add	a4,a4,a1
ffffffffc020162e:	4f1c                	lw	a5,24(a4)
ffffffffc0201630:	02678663          	beq	a5,t1,ffffffffc020165c <slub_free+0x11c>
}
ffffffffc0201634:	60a2                	ld	ra,8(sp)
ffffffffc0201636:	0141                	addi	sp,sp,16
ffffffffc0201638:	8082                	ret
    __list_add(elm, listelm, listelm->next);
ffffffffc020163a:	00571793          	slli	a5,a4,0x5
    *(void **)ptr = old_head;       /* push onto this slab's free list */
ffffffffc020163e:	0006b023          	sd	zero,0(a3)
ffffffffc0201642:	97ae                	add	a5,a5,a1
ffffffffc0201644:	6794                	ld	a3,8(a5)
    page->property = (unsigned int)idx;
ffffffffc0201646:	c910                	sw	a2,16(a0)
    page->ref ++;
ffffffffc0201648:	4605                	li	a2,1
ffffffffc020164a:	c110                	sw	a2,0(a0)
        list_add(&(cache->slabs), &(page->page_link));
ffffffffc020164c:	01850613          	addi	a2,a0,24
    prev->next = next->prev = elm;
ffffffffc0201650:	e290                	sd	a2,0(a3)
ffffffffc0201652:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0201654:	f114                	sd	a3,32(a0)
    elm->prev = prev;
ffffffffc0201656:	ed1c                	sd	a5,24(a0)
    page->ref ++;
ffffffffc0201658:	4305                	li	t1,1
}
ffffffffc020165a:	bfc1                	j	ffffffffc020162a <slub_free+0xea>
    __list_del(listelm->prev, listelm->next);
ffffffffc020165c:	6d18                	ld	a4,24(a0)
ffffffffc020165e:	711c                	ld	a5,32(a0)
        pmm_manager->free_pages(page, 1);
ffffffffc0201660:	00007697          	auipc	a3,0x7
ffffffffc0201664:	e086b683          	ld	a3,-504(a3) # ffffffffc0208468 <pmm_manager>
ffffffffc0201668:	0206b303          	ld	t1,32(a3)
    prev->next = next;
ffffffffc020166c:	e71c                	sd	a5,8(a4)
    next->prev = prev;
ffffffffc020166e:	e398                	sd	a4,0(a5)
}
ffffffffc0201670:	60a2                	ld	ra,8(sp)
        ClearPageSlub(page);
ffffffffc0201672:	00053423          	sd	zero,8(a0)
        page->property = 0;
ffffffffc0201676:	00052823          	sw	zero,16(a0)
        page->ref = 0;
ffffffffc020167a:	00052023          	sw	zero,0(a0)
        pmm_manager->free_pages(page, 1);
ffffffffc020167e:	4585                	li	a1,1
}
ffffffffc0201680:	0141                	addi	sp,sp,16
        pmm_manager->free_pages(page, 1);
ffffffffc0201682:	8302                	jr	t1
ffffffffc0201684:	8082                	ret
        panic("slub_free: 0x%lx is not a valid slub allocation", va);
ffffffffc0201686:	00002617          	auipc	a2,0x2
ffffffffc020168a:	fda60613          	addi	a2,a2,-38 # ffffffffc0203660 <bs_pmm_manager+0x1c8>
ffffffffc020168e:	0f600593          	li	a1,246
ffffffffc0201692:	00002517          	auipc	a0,0x2
ffffffffc0201696:	e4e50513          	addi	a0,a0,-434 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc020169a:	b31fe0ef          	jal	ra,ffffffffc02001ca <__panic>
        panic("pa2page called with invalid pa");
ffffffffc020169e:	00002617          	auipc	a2,0x2
ffffffffc02016a2:	94a60613          	addi	a2,a2,-1718 # ffffffffc0202fe8 <etext+0x264>
ffffffffc02016a6:	06c00593          	li	a1,108
ffffffffc02016aa:	00002517          	auipc	a0,0x2
ffffffffc02016ae:	95e50513          	addi	a0,a0,-1698 # ffffffffc0203008 <etext+0x284>
ffffffffc02016b2:	b19fe0ef          	jal	ra,ffffffffc02001ca <__panic>
        panic("slub_free: invalid pointer 0x%lx", va);
ffffffffc02016b6:	00002617          	auipc	a2,0x2
ffffffffc02016ba:	eda60613          	addi	a2,a2,-294 # ffffffffc0203590 <bs_pmm_manager+0xf8>
ffffffffc02016be:	0ea00593          	li	a1,234
ffffffffc02016c2:	00002517          	auipc	a0,0x2
ffffffffc02016c6:	e1e50513          	addi	a0,a0,-482 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc02016ca:	b01fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(offset < PGSIZE);
ffffffffc02016ce:	00002697          	auipc	a3,0x2
ffffffffc02016d2:	f0268693          	addi	a3,a3,-254 # ffffffffc02035d0 <bs_pmm_manager+0x138>
ffffffffc02016d6:	00002617          	auipc	a2,0x2
ffffffffc02016da:	ae260613          	addi	a2,a2,-1310 # ffffffffc02031b8 <etext+0x434>
ffffffffc02016de:	0c100593          	li	a1,193
ffffffffc02016e2:	00002517          	auipc	a0,0x2
ffffffffc02016e6:	dfe50513          	addi	a0,a0,-514 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc02016ea:	ae1fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(k < SLUB_NR_CLASSES);
ffffffffc02016ee:	00002697          	auipc	a3,0x2
ffffffffc02016f2:	eca68693          	addi	a3,a3,-310 # ffffffffc02035b8 <bs_pmm_manager+0x120>
ffffffffc02016f6:	00002617          	auipc	a2,0x2
ffffffffc02016fa:	ac260613          	addi	a2,a2,-1342 # ffffffffc02031b8 <etext+0x434>
ffffffffc02016fe:	0bb00593          	li	a1,187
ffffffffc0201702:	00002517          	auipc	a0,0x2
ffffffffc0201706:	dde50513          	addi	a0,a0,-546 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc020170a:	ac1fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(idx < cache->objs_per_slab);
ffffffffc020170e:	00002697          	auipc	a3,0x2
ffffffffc0201712:	f3268693          	addi	a3,a3,-206 # ffffffffc0203640 <bs_pmm_manager+0x1a8>
ffffffffc0201716:	00002617          	auipc	a2,0x2
ffffffffc020171a:	aa260613          	addi	a2,a2,-1374 # ffffffffc02031b8 <etext+0x434>
ffffffffc020171e:	0c600593          	li	a1,198
ffffffffc0201722:	00002517          	auipc	a0,0x2
ffffffffc0201726:	dbe50513          	addi	a0,a0,-578 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc020172a:	aa1fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(page->ref < (int)cache->objs_per_slab);  /* catch double free */
ffffffffc020172e:	00002697          	auipc	a3,0x2
ffffffffc0201732:	eea68693          	addi	a3,a3,-278 # ffffffffc0203618 <bs_pmm_manager+0x180>
ffffffffc0201736:	00002617          	auipc	a2,0x2
ffffffffc020173a:	a8260613          	addi	a2,a2,-1406 # ffffffffc02031b8 <etext+0x434>
ffffffffc020173e:	0c300593          	li	a1,195
ffffffffc0201742:	00002517          	auipc	a0,0x2
ffffffffc0201746:	d9e50513          	addi	a0,a0,-610 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc020174a:	a81fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(cache->obj_size != 0 && offset % cache->obj_size == 0);
ffffffffc020174e:	00002697          	auipc	a3,0x2
ffffffffc0201752:	e9268693          	addi	a3,a3,-366 # ffffffffc02035e0 <bs_pmm_manager+0x148>
ffffffffc0201756:	00002617          	auipc	a2,0x2
ffffffffc020175a:	a6260613          	addi	a2,a2,-1438 # ffffffffc02031b8 <etext+0x434>
ffffffffc020175e:	0c200593          	li	a1,194
ffffffffc0201762:	00002517          	auipc	a0,0x2
ffffffffc0201766:	d7e50513          	addi	a0,a0,-642 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc020176a:	a61fe0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(page->property < cache->objs_per_slab);
ffffffffc020176e:	00002697          	auipc	a3,0x2
ffffffffc0201772:	da268693          	addi	a3,a3,-606 # ffffffffc0203510 <bs_pmm_manager+0x78>
ffffffffc0201776:	00002617          	auipc	a2,0x2
ffffffffc020177a:	a4260613          	addi	a2,a2,-1470 # ffffffffc02031b8 <etext+0x434>
ffffffffc020177e:	0cb00593          	li	a1,203
ffffffffc0201782:	00002517          	auipc	a0,0x2
ffffffffc0201786:	d5e50513          	addi	a0,a0,-674 # ffffffffc02034e0 <bs_pmm_manager+0x48>
ffffffffc020178a:	a41fe0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc020178e <test_buddy_system>:

    cprintf("[Buddy Test] oversize request returns NULL: PASS\n");
}

void
test_buddy_system(void) {
ffffffffc020178e:	715d                	addi	sp,sp,-80
ffffffffc0201790:	f44e                	sd	s3,40(sp)
    // 当前物理内存管理器必须是 Buddy System
    if (pmm_manager != &bs_pmm_manager) {
ffffffffc0201792:	00007997          	auipc	s3,0x7
ffffffffc0201796:	cd698993          	addi	s3,s3,-810 # ffffffffc0208468 <pmm_manager>
ffffffffc020179a:	0009b783          	ld	a5,0(s3)
test_buddy_system(void) {
ffffffffc020179e:	e486                	sd	ra,72(sp)
ffffffffc02017a0:	e0a2                	sd	s0,64(sp)
ffffffffc02017a2:	fc26                	sd	s1,56(sp)
ffffffffc02017a4:	f84a                	sd	s2,48(sp)
ffffffffc02017a6:	f052                	sd	s4,32(sp)
ffffffffc02017a8:	ec56                	sd	s5,24(sp)
ffffffffc02017aa:	e85a                	sd	s6,16(sp)
ffffffffc02017ac:	e45e                	sd	s7,8(sp)
    if (pmm_manager != &bs_pmm_manager) {
ffffffffc02017ae:	00002717          	auipc	a4,0x2
ffffffffc02017b2:	cea70713          	addi	a4,a4,-790 # ffffffffc0203498 <bs_pmm_manager>
ffffffffc02017b6:	28e79163          	bne	a5,a4,ffffffffc0201a38 <test_buddy_system+0x2aa>
        panic("test_buddy_system: current pmm_manager is %s, not bs_pmm_manager",
              pmm_manager->name);
    }
    cprintf("[Buddy Test] current algorithm is bs_pmm_manager: PASS\n");
ffffffffc02017ba:	00002517          	auipc	a0,0x2
ffffffffc02017be:	f3650513          	addi	a0,a0,-202 # ffffffffc02036f0 <bs_pmm_manager+0x258>
ffffffffc02017c2:	993fe0ef          	jal	ra,ffffffffc0200154 <cprintf>
    size_t before = nr_free_pages();
ffffffffc02017c6:	e33fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc02017ca:	8aaa                	mv	s5,a0
    struct Page *p = alloc_pages(8);
ffffffffc02017cc:	4521                	li	a0,8
ffffffffc02017ce:	daffe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc02017d2:	842a                	mv	s0,a0
    assert(p != NULL);
ffffffffc02017d4:	5e050a63          	beqz	a0,ffffffffc0201dc8 <test_buddy_system+0x63a>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02017d8:	00007a17          	auipc	s4,0x7
ffffffffc02017dc:	ca0a0a13          	addi	s4,s4,-864 # ffffffffc0208478 <pages>
ffffffffc02017e0:	000a3783          	ld	a5,0(s4)
ffffffffc02017e4:	00003917          	auipc	s2,0x3
ffffffffc02017e8:	af493903          	ld	s2,-1292(s2) # ffffffffc02042d8 <nbase+0x8>
ffffffffc02017ec:	00003497          	auipc	s1,0x3
ffffffffc02017f0:	ae44b483          	ld	s1,-1308(s1) # ffffffffc02042d0 <nbase>
ffffffffc02017f4:	40f507b3          	sub	a5,a0,a5
ffffffffc02017f8:	878d                	srai	a5,a5,0x3
ffffffffc02017fa:	032787b3          	mul	a5,a5,s2
ffffffffc02017fe:	97a6                	add	a5,a5,s1
    assert((page2ppn(p) & 7) == 0);
ffffffffc0201800:	8b9d                	andi	a5,a5,7
ffffffffc0201802:	5a079463          	bnez	a5,ffffffffc0201daa <test_buddy_system+0x61c>
    assert(nr_free_pages() == before - 8);
ffffffffc0201806:	df3fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020180a:	ff8a8793          	addi	a5,s5,-8
ffffffffc020180e:	56f51f63          	bne	a0,a5,ffffffffc0201d8c <test_buddy_system+0x5fe>
    free_pages(p, 8);
ffffffffc0201812:	45a1                	li	a1,8
ffffffffc0201814:	8522                	mv	a0,s0
ffffffffc0201816:	dd5fe0ef          	jal	ra,ffffffffc02005ea <free_pages>
    assert(nr_free_pages() == before);
ffffffffc020181a:	ddffe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020181e:	54aa9863          	bne	s5,a0,ffffffffc0201d6e <test_buddy_system+0x5e0>
    cprintf("[Buddy Test] power-of-two allocation (8 pages -> k=3): PASS\n");
ffffffffc0201822:	00002517          	auipc	a0,0x2
ffffffffc0201826:	f6e50513          	addi	a0,a0,-146 # ffffffffc0203790 <bs_pmm_manager+0x2f8>
ffffffffc020182a:	92bfe0ef          	jal	ra,ffffffffc0200154 <cprintf>
    size_t before = nr_free_pages();
ffffffffc020182e:	dcbfe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0201832:	8aaa                	mv	s5,a0
    struct Page *p = alloc_pages(7);
ffffffffc0201834:	451d                	li	a0,7
ffffffffc0201836:	d47fe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc020183a:	842a                	mv	s0,a0
    assert(p != NULL);
ffffffffc020183c:	50050a63          	beqz	a0,ffffffffc0201d50 <test_buddy_system+0x5c2>
ffffffffc0201840:	000a3783          	ld	a5,0(s4)
ffffffffc0201844:	40f507b3          	sub	a5,a0,a5
ffffffffc0201848:	878d                	srai	a5,a5,0x3
ffffffffc020184a:	032787b3          	mul	a5,a5,s2
ffffffffc020184e:	97a6                	add	a5,a5,s1
    assert((page2ppn(p) & 7) == 0);
ffffffffc0201850:	8b9d                	andi	a5,a5,7
ffffffffc0201852:	4e079063          	bnez	a5,ffffffffc0201d32 <test_buddy_system+0x5a4>
    assert(nr_free_pages() == before - 8);
ffffffffc0201856:	da3fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020185a:	ff8a8793          	addi	a5,s5,-8
ffffffffc020185e:	4af51a63          	bne	a0,a5,ffffffffc0201d12 <test_buddy_system+0x584>
    free_pages(p, 7);
ffffffffc0201862:	459d                	li	a1,7
ffffffffc0201864:	8522                	mv	a0,s0
ffffffffc0201866:	d85fe0ef          	jal	ra,ffffffffc02005ea <free_pages>
    assert(nr_free_pages() == before);
ffffffffc020186a:	d8ffe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020186e:	48aa9263          	bne	s5,a0,ffffffffc0201cf2 <test_buddy_system+0x564>
    cprintf("[Buddy Test] non-power-of-two allocation (7 pages -> 8 pages): PASS\n");
ffffffffc0201872:	00002517          	auipc	a0,0x2
ffffffffc0201876:	f5e50513          	addi	a0,a0,-162 # ffffffffc02037d0 <bs_pmm_manager+0x338>
ffffffffc020187a:	8dbfe0ef          	jal	ra,ffffffffc0200154 <cprintf>
    size_t before = nr_free_pages();
ffffffffc020187e:	d7bfe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0201882:	8aaa                	mv	s5,a0
    struct Page *p = alloc_pages(8);
ffffffffc0201884:	4521                	li	a0,8
ffffffffc0201886:	cf7fe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc020188a:	842a                	mv	s0,a0
    assert(p != NULL);
ffffffffc020188c:	44050363          	beqz	a0,ffffffffc0201cd2 <test_buddy_system+0x544>
ffffffffc0201890:	000a3783          	ld	a5,0(s4)
ffffffffc0201894:	00850713          	addi	a4,a0,8
ffffffffc0201898:	12050693          	addi	a3,a0,288
ffffffffc020189c:	40f507b3          	sub	a5,a0,a5
ffffffffc02018a0:	878d                	srai	a5,a5,0x3
ffffffffc02018a2:	032787b3          	mul	a5,a5,s2
ffffffffc02018a6:	97a6                	add	a5,a5,s1
    assert((page2ppn(p) & 7) == 0);
ffffffffc02018a8:	8b9d                	andi	a5,a5,7
ffffffffc02018aa:	40079463          	bnez	a5,ffffffffc0201cb2 <test_buddy_system+0x524>
        SetPageReserved(p + i);
ffffffffc02018ae:	631c                	ld	a5,0(a4)
ffffffffc02018b0:	02870713          	addi	a4,a4,40
ffffffffc02018b4:	0017e793          	ori	a5,a5,1
ffffffffc02018b8:	fcf73c23          	sd	a5,-40(a4)
    for (int i = 0; i < 7; i ++) {
ffffffffc02018bc:	fed719e3          	bne	a4,a3,ffffffffc02018ae <test_buddy_system+0x120>
    pmm_manager->init_memmap(p, 7);
ffffffffc02018c0:	0009b783          	ld	a5,0(s3)
ffffffffc02018c4:	459d                	li	a1,7
ffffffffc02018c6:	8522                	mv	a0,s0
ffffffffc02018c8:	6b9c                	ld	a5,16(a5)
ffffffffc02018ca:	9782                	jalr	a5
    assert(nr_free_pages() == before - 8 + 7);
ffffffffc02018cc:	d2dfe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc02018d0:	fffa8793          	addi	a5,s5,-1
ffffffffc02018d4:	8b2a                	mv	s6,a0
ffffffffc02018d6:	3af51e63          	bne	a0,a5,ffffffffc0201c92 <test_buddy_system+0x504>
    struct Page *k2 = alloc_pages(4);
ffffffffc02018da:	4511                	li	a0,4
ffffffffc02018dc:	ca1fe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc02018e0:	8baa                	mv	s7,a0
    struct Page *k1 = alloc_pages(2);
ffffffffc02018e2:	4509                	li	a0,2
ffffffffc02018e4:	c99fe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc02018e8:	89aa                	mv	s3,a0
    struct Page *k0 = alloc_page();
ffffffffc02018ea:	4505                	li	a0,1
ffffffffc02018ec:	c91fe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
    assert(k2 == p);
ffffffffc02018f0:	39741163          	bne	s0,s7,ffffffffc0201c72 <test_buddy_system+0x4e4>
    assert(k1 == p + 4);
ffffffffc02018f4:	0a040713          	addi	a4,s0,160
ffffffffc02018f8:	34e99d63          	bne	s3,a4,ffffffffc0201c52 <test_buddy_system+0x4c4>
    assert(k0 == p + 6);
ffffffffc02018fc:	0f040b93          	addi	s7,s0,240
ffffffffc0201900:	33751963          	bne	a0,s7,ffffffffc0201c32 <test_buddy_system+0x4a4>
ffffffffc0201904:	000a3783          	ld	a5,0(s4)
ffffffffc0201908:	40f40733          	sub	a4,s0,a5
ffffffffc020190c:	870d                	srai	a4,a4,0x3
ffffffffc020190e:	03270733          	mul	a4,a4,s2
ffffffffc0201912:	9726                	add	a4,a4,s1
    assert((page2ppn(k2) & 3) == 0);
ffffffffc0201914:	8b0d                	andi	a4,a4,3
ffffffffc0201916:	2e071e63          	bnez	a4,ffffffffc0201c12 <test_buddy_system+0x484>
ffffffffc020191a:	40f987b3          	sub	a5,s3,a5
ffffffffc020191e:	878d                	srai	a5,a5,0x3
ffffffffc0201920:	032787b3          	mul	a5,a5,s2
ffffffffc0201924:	97a6                	add	a5,a5,s1
    assert((page2ppn(k1) & 1) == 0);
ffffffffc0201926:	8b85                	andi	a5,a5,1
ffffffffc0201928:	2c079563          	bnez	a5,ffffffffc0201bf2 <test_buddy_system+0x464>
    free_page(k0);
ffffffffc020192c:	4585                	li	a1,1
ffffffffc020192e:	cbdfe0ef          	jal	ra,ffffffffc02005ea <free_pages>
    free_pages(k1, 2);
ffffffffc0201932:	4589                	li	a1,2
ffffffffc0201934:	854e                	mv	a0,s3
ffffffffc0201936:	cb5fe0ef          	jal	ra,ffffffffc02005ea <free_pages>
    free_pages(k2, 4);
ffffffffc020193a:	4591                	li	a1,4
ffffffffc020193c:	8522                	mv	a0,s0
ffffffffc020193e:	cadfe0ef          	jal	ra,ffffffffc02005ea <free_pages>
    assert(nr_free_pages() == before - 8 + 7);
ffffffffc0201942:	cb7fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0201946:	28ab1663          	bne	s6,a0,ffffffffc0201bd2 <test_buddy_system+0x444>
    assert(alloc_pages(4) == p);
ffffffffc020194a:	4511                	li	a0,4
ffffffffc020194c:	c31fe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc0201950:	26a41163          	bne	s0,a0,ffffffffc0201bb2 <test_buddy_system+0x424>
    assert(alloc_pages(2) == p + 4);
ffffffffc0201954:	4509                	li	a0,2
ffffffffc0201956:	c27fe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc020195a:	22a99c63          	bne	s3,a0,ffffffffc0201b92 <test_buddy_system+0x404>
    assert(alloc_page() == p + 6);
ffffffffc020195e:	4505                	li	a0,1
ffffffffc0201960:	c1dfe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc0201964:	20ab9763          	bne	s7,a0,ffffffffc0201b72 <test_buddy_system+0x3e4>
    free_pages(p, 8);
ffffffffc0201968:	45a1                	li	a1,8
ffffffffc020196a:	8522                	mv	a0,s0
ffffffffc020196c:	c7ffe0ef          	jal	ra,ffffffffc02005ea <free_pages>
    assert(nr_free_pages() == before);
ffffffffc0201970:	c89fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0201974:	1caa9f63          	bne	s5,a0,ffffffffc0201b52 <test_buddy_system+0x3c4>
    cprintf("[Buddy Test] 7-page decomposition (4 + 2 + 1): PASS\n");
ffffffffc0201978:	00002517          	auipc	a0,0x2
ffffffffc020197c:	f6850513          	addi	a0,a0,-152 # ffffffffc02038e0 <bs_pmm_manager+0x448>
ffffffffc0201980:	fd4fe0ef          	jal	ra,ffffffffc0200154 <cprintf>
    size_t before = nr_free_pages();
ffffffffc0201984:	c75fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0201988:	89aa                	mv	s3,a0
    struct Page *p = alloc_pages(16);
ffffffffc020198a:	4541                	li	a0,16
ffffffffc020198c:	bf1fe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc0201990:	842a                	mv	s0,a0
    assert(p != NULL);
ffffffffc0201992:	1a050063          	beqz	a0,ffffffffc0201b32 <test_buddy_system+0x3a4>
ffffffffc0201996:	000a3783          	ld	a5,0(s4)
ffffffffc020199a:	40f507b3          	sub	a5,a0,a5
ffffffffc020199e:	878d                	srai	a5,a5,0x3
ffffffffc02019a0:	03278933          	mul	s2,a5,s2
ffffffffc02019a4:	94ca                	add	s1,s1,s2
    assert((page2ppn(p) & 15) == 0);
ffffffffc02019a6:	88bd                	andi	s1,s1,15
ffffffffc02019a8:	16049563          	bnez	s1,ffffffffc0201b12 <test_buddy_system+0x384>
    assert(nr_free_pages() == before - 16);
ffffffffc02019ac:	c4dfe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc02019b0:	ff098793          	addi	a5,s3,-16
ffffffffc02019b4:	12f51f63          	bne	a0,a5,ffffffffc0201af2 <test_buddy_system+0x364>
    free_pages(p, 8);
ffffffffc02019b8:	45a1                	li	a1,8
ffffffffc02019ba:	8522                	mv	a0,s0
ffffffffc02019bc:	c2ffe0ef          	jal	ra,ffffffffc02005ea <free_pages>
    free_pages(p + 8, 8);
ffffffffc02019c0:	45a1                	li	a1,8
ffffffffc02019c2:	14040513          	addi	a0,s0,320
ffffffffc02019c6:	c25fe0ef          	jal	ra,ffffffffc02005ea <free_pages>
    assert(nr_free_pages() == before);
ffffffffc02019ca:	c2ffe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc02019ce:	10a99263          	bne	s3,a0,ffffffffc0201ad2 <test_buddy_system+0x344>
    assert(alloc_pages(16) == p);
ffffffffc02019d2:	4541                	li	a0,16
ffffffffc02019d4:	ba9fe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc02019d8:	0ca41d63          	bne	s0,a0,ffffffffc0201ab2 <test_buddy_system+0x324>
    free_pages(p, 16);
ffffffffc02019dc:	45c1                	li	a1,16
ffffffffc02019de:	c0dfe0ef          	jal	ra,ffffffffc02005ea <free_pages>
    assert(nr_free_pages() == before);
ffffffffc02019e2:	c17fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc02019e6:	0aa99663          	bne	s3,a0,ffffffffc0201a92 <test_buddy_system+0x304>
    cprintf("[Buddy Test] adjacent free block merge (k=3 + k=3 -> k=4): PASS\n");
ffffffffc02019ea:	00002517          	auipc	a0,0x2
ffffffffc02019ee:	f7e50513          	addi	a0,a0,-130 # ffffffffc0203968 <bs_pmm_manager+0x4d0>
ffffffffc02019f2:	f62fe0ef          	jal	ra,ffffffffc0200154 <cprintf>
    size_t before = nr_free_pages();
ffffffffc02019f6:	c03fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc02019fa:	842a                	mv	s0,a0
    assert(alloc_pages(before + 1) == NULL);
ffffffffc02019fc:	0505                	addi	a0,a0,1
ffffffffc02019fe:	b7ffe0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc0201a02:	e925                	bnez	a0,ffffffffc0201a72 <test_buddy_system+0x2e4>
    assert(nr_free_pages() == before);
ffffffffc0201a04:	bf5fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0201a08:	04a41563          	bne	s0,a0,ffffffffc0201a52 <test_buddy_system+0x2c4>
    cprintf("[Buddy Test] oversize request returns NULL: PASS\n");
ffffffffc0201a0c:	00002517          	auipc	a0,0x2
ffffffffc0201a10:	fc450513          	addi	a0,a0,-60 # ffffffffc02039d0 <bs_pmm_manager+0x538>
ffffffffc0201a14:	f40fe0ef          	jal	ra,ffffffffc0200154 <cprintf>
    test_buddy_decompose_seven();
    test_buddy_merge();
    test_buddy_oversize();

    cprintf("[Buddy Test] ALL PASS\n");
}
ffffffffc0201a18:	6406                	ld	s0,64(sp)
ffffffffc0201a1a:	60a6                	ld	ra,72(sp)
ffffffffc0201a1c:	74e2                	ld	s1,56(sp)
ffffffffc0201a1e:	7942                	ld	s2,48(sp)
ffffffffc0201a20:	79a2                	ld	s3,40(sp)
ffffffffc0201a22:	7a02                	ld	s4,32(sp)
ffffffffc0201a24:	6ae2                	ld	s5,24(sp)
ffffffffc0201a26:	6b42                	ld	s6,16(sp)
ffffffffc0201a28:	6ba2                	ld	s7,8(sp)
    cprintf("[Buddy Test] ALL PASS\n");
ffffffffc0201a2a:	00002517          	auipc	a0,0x2
ffffffffc0201a2e:	fde50513          	addi	a0,a0,-34 # ffffffffc0203a08 <bs_pmm_manager+0x570>
}
ffffffffc0201a32:	6161                	addi	sp,sp,80
    cprintf("[Buddy Test] ALL PASS\n");
ffffffffc0201a34:	f20fe06f          	j	ffffffffc0200154 <cprintf>
        panic("test_buddy_system: current pmm_manager is %s, not bs_pmm_manager",
ffffffffc0201a38:	6394                	ld	a3,0(a5)
ffffffffc0201a3a:	00002617          	auipc	a2,0x2
ffffffffc0201a3e:	c5660613          	addi	a2,a2,-938 # ffffffffc0203690 <bs_pmm_manager+0x1f8>
ffffffffc0201a42:	07600593          	li	a1,118
ffffffffc0201a46:	00002517          	auipc	a0,0x2
ffffffffc0201a4a:	c9250513          	addi	a0,a0,-878 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201a4e:	f7cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc0201a52:	00002697          	auipc	a3,0x2
ffffffffc0201a56:	d1e68693          	addi	a3,a3,-738 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc0201a5a:	00001617          	auipc	a2,0x1
ffffffffc0201a5e:	75e60613          	addi	a2,a2,1886 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201a62:	06d00593          	li	a1,109
ffffffffc0201a66:	00002517          	auipc	a0,0x2
ffffffffc0201a6a:	c7250513          	addi	a0,a0,-910 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201a6e:	f5cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_pages(before + 1) == NULL);
ffffffffc0201a72:	00002697          	auipc	a3,0x2
ffffffffc0201a76:	f3e68693          	addi	a3,a3,-194 # ffffffffc02039b0 <bs_pmm_manager+0x518>
ffffffffc0201a7a:	00001617          	auipc	a2,0x1
ffffffffc0201a7e:	73e60613          	addi	a2,a2,1854 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201a82:	06c00593          	li	a1,108
ffffffffc0201a86:	00002517          	auipc	a0,0x2
ffffffffc0201a8a:	c5250513          	addi	a0,a0,-942 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201a8e:	f3cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc0201a92:	00002697          	auipc	a3,0x2
ffffffffc0201a96:	cde68693          	addi	a3,a3,-802 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc0201a9a:	00001617          	auipc	a2,0x1
ffffffffc0201a9e:	71e60613          	addi	a2,a2,1822 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201aa2:	06200593          	li	a1,98
ffffffffc0201aa6:	00002517          	auipc	a0,0x2
ffffffffc0201aaa:	c3250513          	addi	a0,a0,-974 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201aae:	f1cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_pages(16) == p);
ffffffffc0201ab2:	00002697          	auipc	a3,0x2
ffffffffc0201ab6:	e9e68693          	addi	a3,a3,-354 # ffffffffc0203950 <bs_pmm_manager+0x4b8>
ffffffffc0201aba:	00001617          	auipc	a2,0x1
ffffffffc0201abe:	6fe60613          	addi	a2,a2,1790 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201ac2:	06000593          	li	a1,96
ffffffffc0201ac6:	00002517          	auipc	a0,0x2
ffffffffc0201aca:	c1250513          	addi	a0,a0,-1006 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201ace:	efcfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc0201ad2:	00002697          	auipc	a3,0x2
ffffffffc0201ad6:	c9e68693          	addi	a3,a3,-866 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc0201ada:	00001617          	auipc	a2,0x1
ffffffffc0201ade:	6de60613          	addi	a2,a2,1758 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201ae2:	05d00593          	li	a1,93
ffffffffc0201ae6:	00002517          	auipc	a0,0x2
ffffffffc0201aea:	bf250513          	addi	a0,a0,-1038 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201aee:	edcfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 16);
ffffffffc0201af2:	00002697          	auipc	a3,0x2
ffffffffc0201af6:	e3e68693          	addi	a3,a3,-450 # ffffffffc0203930 <bs_pmm_manager+0x498>
ffffffffc0201afa:	00001617          	auipc	a2,0x1
ffffffffc0201afe:	6be60613          	addi	a2,a2,1726 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201b02:	05900593          	li	a1,89
ffffffffc0201b06:	00002517          	auipc	a0,0x2
ffffffffc0201b0a:	bd250513          	addi	a0,a0,-1070 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201b0e:	ebcfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((page2ppn(p) & 15) == 0);
ffffffffc0201b12:	00002697          	auipc	a3,0x2
ffffffffc0201b16:	e0668693          	addi	a3,a3,-506 # ffffffffc0203918 <bs_pmm_manager+0x480>
ffffffffc0201b1a:	00001617          	auipc	a2,0x1
ffffffffc0201b1e:	69e60613          	addi	a2,a2,1694 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201b22:	05800593          	li	a1,88
ffffffffc0201b26:	00002517          	auipc	a0,0x2
ffffffffc0201b2a:	bb250513          	addi	a0,a0,-1102 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201b2e:	e9cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(p != NULL);
ffffffffc0201b32:	00002697          	auipc	a3,0x2
ffffffffc0201b36:	bf668693          	addi	a3,a3,-1034 # ffffffffc0203728 <bs_pmm_manager+0x290>
ffffffffc0201b3a:	00001617          	auipc	a2,0x1
ffffffffc0201b3e:	67e60613          	addi	a2,a2,1662 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201b42:	05700593          	li	a1,87
ffffffffc0201b46:	00002517          	auipc	a0,0x2
ffffffffc0201b4a:	b9250513          	addi	a0,a0,-1134 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201b4e:	e7cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc0201b52:	00002697          	auipc	a3,0x2
ffffffffc0201b56:	c1e68693          	addi	a3,a3,-994 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc0201b5a:	00001617          	auipc	a2,0x1
ffffffffc0201b5e:	65e60613          	addi	a2,a2,1630 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201b62:	04c00593          	li	a1,76
ffffffffc0201b66:	00002517          	auipc	a0,0x2
ffffffffc0201b6a:	b7250513          	addi	a0,a0,-1166 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201b6e:	e5cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_page() == p + 6);
ffffffffc0201b72:	00002697          	auipc	a3,0x2
ffffffffc0201b76:	d5668693          	addi	a3,a3,-682 # ffffffffc02038c8 <bs_pmm_manager+0x430>
ffffffffc0201b7a:	00001617          	auipc	a2,0x1
ffffffffc0201b7e:	63e60613          	addi	a2,a2,1598 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201b82:	04a00593          	li	a1,74
ffffffffc0201b86:	00002517          	auipc	a0,0x2
ffffffffc0201b8a:	b5250513          	addi	a0,a0,-1198 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201b8e:	e3cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_pages(2) == p + 4);
ffffffffc0201b92:	00002697          	auipc	a3,0x2
ffffffffc0201b96:	d1e68693          	addi	a3,a3,-738 # ffffffffc02038b0 <bs_pmm_manager+0x418>
ffffffffc0201b9a:	00001617          	auipc	a2,0x1
ffffffffc0201b9e:	61e60613          	addi	a2,a2,1566 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201ba2:	04900593          	li	a1,73
ffffffffc0201ba6:	00002517          	auipc	a0,0x2
ffffffffc0201baa:	b3250513          	addi	a0,a0,-1230 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201bae:	e1cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_pages(4) == p);
ffffffffc0201bb2:	00002697          	auipc	a3,0x2
ffffffffc0201bb6:	ce668693          	addi	a3,a3,-794 # ffffffffc0203898 <bs_pmm_manager+0x400>
ffffffffc0201bba:	00001617          	auipc	a2,0x1
ffffffffc0201bbe:	5fe60613          	addi	a2,a2,1534 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201bc2:	04800593          	li	a1,72
ffffffffc0201bc6:	00002517          	auipc	a0,0x2
ffffffffc0201bca:	b1250513          	addi	a0,a0,-1262 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201bce:	dfcfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 8 + 7);
ffffffffc0201bd2:	00002697          	auipc	a3,0x2
ffffffffc0201bd6:	c4668693          	addi	a3,a3,-954 # ffffffffc0203818 <bs_pmm_manager+0x380>
ffffffffc0201bda:	00001617          	auipc	a2,0x1
ffffffffc0201bde:	5de60613          	addi	a2,a2,1502 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201be2:	04500593          	li	a1,69
ffffffffc0201be6:	00002517          	auipc	a0,0x2
ffffffffc0201bea:	af250513          	addi	a0,a0,-1294 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201bee:	ddcfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((page2ppn(k1) & 1) == 0);
ffffffffc0201bf2:	00002697          	auipc	a3,0x2
ffffffffc0201bf6:	c8e68693          	addi	a3,a3,-882 # ffffffffc0203880 <bs_pmm_manager+0x3e8>
ffffffffc0201bfa:	00001617          	auipc	a2,0x1
ffffffffc0201bfe:	5be60613          	addi	a2,a2,1470 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201c02:	04000593          	li	a1,64
ffffffffc0201c06:	00002517          	auipc	a0,0x2
ffffffffc0201c0a:	ad250513          	addi	a0,a0,-1326 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201c0e:	dbcfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((page2ppn(k2) & 3) == 0);
ffffffffc0201c12:	00002697          	auipc	a3,0x2
ffffffffc0201c16:	c5668693          	addi	a3,a3,-938 # ffffffffc0203868 <bs_pmm_manager+0x3d0>
ffffffffc0201c1a:	00001617          	auipc	a2,0x1
ffffffffc0201c1e:	59e60613          	addi	a2,a2,1438 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201c22:	03f00593          	li	a1,63
ffffffffc0201c26:	00002517          	auipc	a0,0x2
ffffffffc0201c2a:	ab250513          	addi	a0,a0,-1358 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201c2e:	d9cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(k0 == p + 6);
ffffffffc0201c32:	00002697          	auipc	a3,0x2
ffffffffc0201c36:	c2668693          	addi	a3,a3,-986 # ffffffffc0203858 <bs_pmm_manager+0x3c0>
ffffffffc0201c3a:	00001617          	auipc	a2,0x1
ffffffffc0201c3e:	57e60613          	addi	a2,a2,1406 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201c42:	03e00593          	li	a1,62
ffffffffc0201c46:	00002517          	auipc	a0,0x2
ffffffffc0201c4a:	a9250513          	addi	a0,a0,-1390 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201c4e:	d7cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(k1 == p + 4);
ffffffffc0201c52:	00002697          	auipc	a3,0x2
ffffffffc0201c56:	bf668693          	addi	a3,a3,-1034 # ffffffffc0203848 <bs_pmm_manager+0x3b0>
ffffffffc0201c5a:	00001617          	auipc	a2,0x1
ffffffffc0201c5e:	55e60613          	addi	a2,a2,1374 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201c62:	03d00593          	li	a1,61
ffffffffc0201c66:	00002517          	auipc	a0,0x2
ffffffffc0201c6a:	a7250513          	addi	a0,a0,-1422 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201c6e:	d5cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(k2 == p);
ffffffffc0201c72:	00002697          	auipc	a3,0x2
ffffffffc0201c76:	bce68693          	addi	a3,a3,-1074 # ffffffffc0203840 <bs_pmm_manager+0x3a8>
ffffffffc0201c7a:	00001617          	auipc	a2,0x1
ffffffffc0201c7e:	53e60613          	addi	a2,a2,1342 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201c82:	03c00593          	li	a1,60
ffffffffc0201c86:	00002517          	auipc	a0,0x2
ffffffffc0201c8a:	a5250513          	addi	a0,a0,-1454 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201c8e:	d3cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 8 + 7);
ffffffffc0201c92:	00002697          	auipc	a3,0x2
ffffffffc0201c96:	b8668693          	addi	a3,a3,-1146 # ffffffffc0203818 <bs_pmm_manager+0x380>
ffffffffc0201c9a:	00001617          	auipc	a2,0x1
ffffffffc0201c9e:	51e60613          	addi	a2,a2,1310 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201ca2:	03600593          	li	a1,54
ffffffffc0201ca6:	00002517          	auipc	a0,0x2
ffffffffc0201caa:	a3250513          	addi	a0,a0,-1486 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201cae:	d1cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((page2ppn(p) & 7) == 0);
ffffffffc0201cb2:	00002697          	auipc	a3,0x2
ffffffffc0201cb6:	a8668693          	addi	a3,a3,-1402 # ffffffffc0203738 <bs_pmm_manager+0x2a0>
ffffffffc0201cba:	00001617          	auipc	a2,0x1
ffffffffc0201cbe:	4fe60613          	addi	a2,a2,1278 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201cc2:	03000593          	li	a1,48
ffffffffc0201cc6:	00002517          	auipc	a0,0x2
ffffffffc0201cca:	a1250513          	addi	a0,a0,-1518 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201cce:	cfcfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(p != NULL);
ffffffffc0201cd2:	00002697          	auipc	a3,0x2
ffffffffc0201cd6:	a5668693          	addi	a3,a3,-1450 # ffffffffc0203728 <bs_pmm_manager+0x290>
ffffffffc0201cda:	00001617          	auipc	a2,0x1
ffffffffc0201cde:	4de60613          	addi	a2,a2,1246 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201ce2:	02f00593          	li	a1,47
ffffffffc0201ce6:	00002517          	auipc	a0,0x2
ffffffffc0201cea:	9f250513          	addi	a0,a0,-1550 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201cee:	cdcfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc0201cf2:	00002697          	auipc	a3,0x2
ffffffffc0201cf6:	a7e68693          	addi	a3,a3,-1410 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc0201cfa:	00001617          	auipc	a2,0x1
ffffffffc0201cfe:	4be60613          	addi	a2,a2,1214 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201d02:	02300593          	li	a1,35
ffffffffc0201d06:	00002517          	auipc	a0,0x2
ffffffffc0201d0a:	9d250513          	addi	a0,a0,-1582 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201d0e:	cbcfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 8);
ffffffffc0201d12:	00002697          	auipc	a3,0x2
ffffffffc0201d16:	a3e68693          	addi	a3,a3,-1474 # ffffffffc0203750 <bs_pmm_manager+0x2b8>
ffffffffc0201d1a:	00001617          	auipc	a2,0x1
ffffffffc0201d1e:	49e60613          	addi	a2,a2,1182 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201d22:	02000593          	li	a1,32
ffffffffc0201d26:	00002517          	auipc	a0,0x2
ffffffffc0201d2a:	9b250513          	addi	a0,a0,-1614 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201d2e:	c9cfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((page2ppn(p) & 7) == 0);
ffffffffc0201d32:	00002697          	auipc	a3,0x2
ffffffffc0201d36:	a0668693          	addi	a3,a3,-1530 # ffffffffc0203738 <bs_pmm_manager+0x2a0>
ffffffffc0201d3a:	00001617          	auipc	a2,0x1
ffffffffc0201d3e:	47e60613          	addi	a2,a2,1150 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201d42:	45fd                	li	a1,31
ffffffffc0201d44:	00002517          	auipc	a0,0x2
ffffffffc0201d48:	99450513          	addi	a0,a0,-1644 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201d4c:	c7efe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(p != NULL);
ffffffffc0201d50:	00002697          	auipc	a3,0x2
ffffffffc0201d54:	9d868693          	addi	a3,a3,-1576 # ffffffffc0203728 <bs_pmm_manager+0x290>
ffffffffc0201d58:	00001617          	auipc	a2,0x1
ffffffffc0201d5c:	46060613          	addi	a2,a2,1120 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201d60:	45f9                	li	a1,30
ffffffffc0201d62:	00002517          	auipc	a0,0x2
ffffffffc0201d66:	97650513          	addi	a0,a0,-1674 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201d6a:	c60fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc0201d6e:	00002697          	auipc	a3,0x2
ffffffffc0201d72:	a0268693          	addi	a3,a3,-1534 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc0201d76:	00001617          	auipc	a2,0x1
ffffffffc0201d7a:	44260613          	addi	a2,a2,1090 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201d7e:	45cd                	li	a1,19
ffffffffc0201d80:	00002517          	auipc	a0,0x2
ffffffffc0201d84:	95850513          	addi	a0,a0,-1704 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201d88:	c42fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 8);
ffffffffc0201d8c:	00002697          	auipc	a3,0x2
ffffffffc0201d90:	9c468693          	addi	a3,a3,-1596 # ffffffffc0203750 <bs_pmm_manager+0x2b8>
ffffffffc0201d94:	00001617          	auipc	a2,0x1
ffffffffc0201d98:	42460613          	addi	a2,a2,1060 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201d9c:	45c1                	li	a1,16
ffffffffc0201d9e:	00002517          	auipc	a0,0x2
ffffffffc0201da2:	93a50513          	addi	a0,a0,-1734 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201da6:	c24fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((page2ppn(p) & 7) == 0);
ffffffffc0201daa:	00002697          	auipc	a3,0x2
ffffffffc0201dae:	98e68693          	addi	a3,a3,-1650 # ffffffffc0203738 <bs_pmm_manager+0x2a0>
ffffffffc0201db2:	00001617          	auipc	a2,0x1
ffffffffc0201db6:	40660613          	addi	a2,a2,1030 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201dba:	45bd                	li	a1,15
ffffffffc0201dbc:	00002517          	auipc	a0,0x2
ffffffffc0201dc0:	91c50513          	addi	a0,a0,-1764 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201dc4:	c06fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(p != NULL);
ffffffffc0201dc8:	00002697          	auipc	a3,0x2
ffffffffc0201dcc:	96068693          	addi	a3,a3,-1696 # ffffffffc0203728 <bs_pmm_manager+0x290>
ffffffffc0201dd0:	00001617          	auipc	a2,0x1
ffffffffc0201dd4:	3e860613          	addi	a2,a2,1000 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201dd8:	45b9                	li	a1,14
ffffffffc0201dda:	00002517          	auipc	a0,0x2
ffffffffc0201dde:	8fe50513          	addi	a0,a0,-1794 # ffffffffc02036d8 <bs_pmm_manager+0x240>
ffffffffc0201de2:	be8fe0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0201de6 <test_verify>:
}

static void
test_verify(const void *ptr, size_t size, uint8_t seed) {
    const volatile uint8_t *p = (const volatile uint8_t *)ptr;
    for (size_t i = 0; i < size; i ++) {
ffffffffc0201de6:	c98d                	beqz	a1,ffffffffc0201e18 <test_verify+0x32>
ffffffffc0201de8:	4681                	li	a3,0
ffffffffc0201dea:	4701                	li	a4,0
        assert(p[i] == (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8)));
ffffffffc0201dec:	00e507b3          	add	a5,a0,a4
ffffffffc0201df0:	0007c803          	lbu	a6,0(a5)
ffffffffc0201df4:	00875893          	srli	a7,a4,0x8
ffffffffc0201df8:	00d607bb          	addw	a5,a2,a3
ffffffffc0201dfc:	011787bb          	addw	a5,a5,a7
ffffffffc0201e00:	0ff87813          	andi	a6,a6,255
ffffffffc0201e04:	0ff7f793          	andi	a5,a5,255
ffffffffc0201e08:	00f81963          	bne	a6,a5,ffffffffc0201e1a <test_verify+0x34>
    for (size_t i = 0; i < size; i ++) {
ffffffffc0201e0c:	26fd                	addiw	a3,a3,31
ffffffffc0201e0e:	0705                	addi	a4,a4,1
ffffffffc0201e10:	0ff6f693          	andi	a3,a3,255
ffffffffc0201e14:	fce59ce3          	bne	a1,a4,ffffffffc0201dec <test_verify+0x6>
ffffffffc0201e18:	8082                	ret
test_verify(const void *ptr, size_t size, uint8_t seed) {
ffffffffc0201e1a:	1141                	addi	sp,sp,-16
        assert(p[i] == (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8)));
ffffffffc0201e1c:	00002697          	auipc	a3,0x2
ffffffffc0201e20:	c0468693          	addi	a3,a3,-1020 # ffffffffc0203a20 <bs_pmm_manager+0x588>
ffffffffc0201e24:	00001617          	auipc	a2,0x1
ffffffffc0201e28:	39460613          	addi	a2,a2,916 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201e2c:	03000593          	li	a1,48
ffffffffc0201e30:	00002517          	auipc	a0,0x2
ffffffffc0201e34:	c3050513          	addi	a0,a0,-976 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
test_verify(const void *ptr, size_t size, uint8_t seed) {
ffffffffc0201e38:	e406                	sd	ra,8(sp)
        assert(p[i] == (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8)));
ffffffffc0201e3a:	b90fe0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0201e3e <test_isolation>:
    cprintf("[SLUB Test] size boundaries and rounding: PASS\n");
}

/* 2. Many live objects of mixed sizes must not overwrite each other. */
static void
test_isolation(void) {
ffffffffc0201e3e:	7119                	addi	sp,sp,-128
ffffffffc0201e40:	737d                	lui	t1,0xfffff
ffffffffc0201e42:	f4a6                	sd	s1,104(sp)
ffffffffc0201e44:	f0ca                	sd	s2,96(sp)
ffffffffc0201e46:	ecce                	sd	s3,88(sp)
ffffffffc0201e48:	e8d2                	sd	s4,80(sp)
ffffffffc0201e4a:	e4d6                	sd	s5,72(sp)
ffffffffc0201e4c:	e0da                	sd	s6,64(sp)
ffffffffc0201e4e:	fc5e                	sd	s7,56(sp)
ffffffffc0201e50:	f862                	sd	s8,48(sp)
ffffffffc0201e52:	f466                	sd	s9,40(sp)
ffffffffc0201e54:	f06a                	sd	s10,32(sp)
ffffffffc0201e56:	ec6e                	sd	s11,24(sp)
ffffffffc0201e58:	fc86                	sd	ra,120(sp)
ffffffffc0201e5a:	f8a2                	sd	s0,112(sp)
ffffffffc0201e5c:	6785                	lui	a5,0x1
ffffffffc0201e5e:	911a                	add	sp,sp,t1
ffffffffc0201e60:	80078793          	addi	a5,a5,-2048 # 800 <kern_entry-0xffffffffc01ff800>
ffffffffc0201e64:	0818                	addi	a4,sp,16
ffffffffc0201e66:	00f70933          	add	s2,a4,a5
ffffffffc0201e6a:	6785                	lui	a5,0x1
ffffffffc0201e6c:	74fd                	lui	s1,0xfffff
ffffffffc0201e6e:	97ba                	add	a5,a5,a4
ffffffffc0201e70:	94be                	add	s1,s1,a5
    if (size <= 2048) {
ffffffffc0201e72:	6a05                	lui	s4,0x1
test_isolation(void) {
ffffffffc0201e74:	8d26                	mv	s10,s1
ffffffffc0201e76:	8dca                	mv	s11,s2
ffffffffc0201e78:	49a1                	li	s3,8
    };
    void *objs[SLUB_TEST_MAX_OBJS];
    size_t sizes[SLUB_TEST_MAX_OBJS];
    size_t nmix = sizeof(mix) / sizeof(mix[0]);

    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
ffffffffc0201e7a:	4c81                	li	s9,0
    if (size <= 2048) {
ffffffffc0201e7c:	800a0a13          	addi	s4,s4,-2048 # 800 <kern_entry-0xffffffffc01ff800>
    while (rounded < size) {
ffffffffc0201e80:	4c21                	li	s8,8
    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
ffffffffc0201e82:	10000a93          	li	s5,256
ffffffffc0201e86:	00002b97          	auipc	s7,0x2
ffffffffc0201e8a:	082b8b93          	addi	s7,s7,130 # ffffffffc0203f08 <mix.1237>
ffffffffc0201e8e:	4b39                	li	s6,14
        *alignment = PGSIZE;
ffffffffc0201e90:	6405                	lui	s0,0x1
    if (size <= 2048) {
ffffffffc0201e92:	013a6863          	bltu	s4,s3,ffffffffc0201ea2 <test_isolation+0x64>
    size_t rounded = 8;
ffffffffc0201e96:	4421                	li	s0,8
    while (rounded < size) {
ffffffffc0201e98:	013c7563          	bgeu	s8,s3,ffffffffc0201ea2 <test_isolation+0x64>
        rounded <<= 1;
ffffffffc0201e9c:	0406                	slli	s0,s0,0x1
    while (rounded < size) {
ffffffffc0201e9e:	ff346fe3          	bltu	s0,s3,ffffffffc0201e9c <test_isolation+0x5e>
        size_t size = mix[i % nmix];
        size_t writable, alignment;
        test_expect(size, &writable, &alignment);

        objs[i] = slub_alloc(size);
ffffffffc0201ea2:	854e                	mv	a0,s3
ffffffffc0201ea4:	c06ff0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc0201ea8:	00ad3023          	sd	a0,0(s10) # ff0000 <kern_entry-0xffffffffbf210000>
        assert(objs[i] != NULL);
ffffffffc0201eac:	12050463          	beqz	a0,ffffffffc0201fd4 <test_isolation+0x196>
        assert(((uintptr_t)objs[i] & (alignment - 1)) == 0);
ffffffffc0201eb0:	147d                	addi	s0,s0,-1
ffffffffc0201eb2:	8c69                	and	s0,s0,a0
ffffffffc0201eb4:	16041063          	bnez	s0,ffffffffc0202014 <test_isolation+0x1d6>
        sizes[i] = size;
ffffffffc0201eb8:	013db023          	sd	s3,0(s11)
    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
ffffffffc0201ebc:	0c85                	addi	s9,s9,1
ffffffffc0201ebe:	0da1                	addi	s11,s11,8
ffffffffc0201ec0:	0d21                	addi	s10,s10,8
ffffffffc0201ec2:	015c8963          	beq	s9,s5,ffffffffc0201ed4 <test_isolation+0x96>
ffffffffc0201ec6:	036cf7b3          	remu	a5,s9,s6
ffffffffc0201eca:	078e                	slli	a5,a5,0x3
ffffffffc0201ecc:	97de                	add	a5,a5,s7
ffffffffc0201ece:	0007b983          	ld	s3,0(a5) # 1000 <kern_entry-0xffffffffc01ff000>
ffffffffc0201ed2:	bf7d                	j	ffffffffc0201e90 <test_isolation+0x52>
    if (size <= 2048) {
ffffffffc0201ed4:	6e85                	lui	t4,0x1
ffffffffc0201ed6:	8e26                	mv	t3,s1
ffffffffc0201ed8:	834a                	mv	t1,s2
ffffffffc0201eda:	4885                	li	a7,1
ffffffffc0201edc:	800e8e93          	addi	t4,t4,-2048 # 800 <kern_entry-0xffffffffc01ff800>
    while (rounded < size) {
ffffffffc0201ee0:	4fa1                	li	t6,8
    }

    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
ffffffffc0201ee2:	10100f13          	li	t5,257
        size_t writable, alignment;
        test_expect(sizes[i], &writable, &alignment);
ffffffffc0201ee6:	00033583          	ld	a1,0(t1) # fffffffffffff000 <end+0x3fdf6b80>
    if (size <= 2048) {
ffffffffc0201eea:	00bee963          	bltu	t4,a1,ffffffffc0201efc <test_isolation+0xbe>
    while (rounded < size) {
ffffffffc0201eee:	0ebff163          	bgeu	t6,a1,ffffffffc0201fd0 <test_isolation+0x192>
    size_t rounded = 8;
ffffffffc0201ef2:	47a1                	li	a5,8
        rounded <<= 1;
ffffffffc0201ef4:	0786                	slli	a5,a5,0x1
    while (rounded < size) {
ffffffffc0201ef6:	feb7efe3          	bltu	a5,a1,ffffffffc0201ef4 <test_isolation+0xb6>
        rounded <<= 1;
ffffffffc0201efa:	85be                	mv	a1,a5
        test_fill(objs[i], writable, (uint8_t)(i + 1));
ffffffffc0201efc:	000e3803          	ld	a6,0(t3)
ffffffffc0201f00:	0ff8f513          	andi	a0,a7,255
    for (size_t i = 0; i < size; i ++) {
ffffffffc0201f04:	4681                	li	a3,0
        test_fill(objs[i], writable, (uint8_t)(i + 1));
ffffffffc0201f06:	4701                	li	a4,0
        p[i] = (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8));
ffffffffc0201f08:	0086d613          	srli	a2,a3,0x8
ffffffffc0201f0c:	00e507bb          	addw	a5,a0,a4
ffffffffc0201f10:	9fb1                	addw	a5,a5,a2
ffffffffc0201f12:	0ff7f793          	andi	a5,a5,255
ffffffffc0201f16:	00d80633          	add	a2,a6,a3
ffffffffc0201f1a:	277d                	addiw	a4,a4,31
ffffffffc0201f1c:	00f60023          	sb	a5,0(a2)
    for (size_t i = 0; i < size; i ++) {
ffffffffc0201f20:	0685                	addi	a3,a3,1
ffffffffc0201f22:	0ff77713          	andi	a4,a4,255
ffffffffc0201f26:	feb691e3          	bne	a3,a1,ffffffffc0201f08 <test_isolation+0xca>
    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
ffffffffc0201f2a:	0885                	addi	a7,a7,1
ffffffffc0201f2c:	0321                	addi	t1,t1,8
ffffffffc0201f2e:	0e21                	addi	t3,t3,8
ffffffffc0201f30:	fbe89be3          	bne	a7,t5,ffffffffc0201ee6 <test_isolation+0xa8>
    if (size <= 2048) {
ffffffffc0201f34:	6a05                	lui	s4,0x1
ffffffffc0201f36:	4985                	li	s3,1
ffffffffc0201f38:	800a0a13          	addi	s4,s4,-2048 # 800 <kern_entry-0xffffffffc01ff800>
    while (rounded < size) {
ffffffffc0201f3c:	4b21                	li	s6,8
    }

    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
ffffffffc0201f3e:	10100a93          	li	s5,257
        size_t writable, alignment;
        test_expect(sizes[i], &writable, &alignment);
ffffffffc0201f42:	00093583          	ld	a1,0(s2)
    if (size <= 2048) {
ffffffffc0201f46:	00ba6963          	bltu	s4,a1,ffffffffc0201f58 <test_isolation+0x11a>
    while (rounded < size) {
ffffffffc0201f4a:	08bb7163          	bgeu	s6,a1,ffffffffc0201fcc <test_isolation+0x18e>
    size_t rounded = 8;
ffffffffc0201f4e:	47a1                	li	a5,8
        rounded <<= 1;
ffffffffc0201f50:	0786                	slli	a5,a5,0x1
    while (rounded < size) {
ffffffffc0201f52:	feb7efe3          	bltu	a5,a1,ffffffffc0201f50 <test_isolation+0x112>
        rounded <<= 1;
ffffffffc0201f56:	85be                	mv	a1,a5
        test_verify(objs[i], writable, (uint8_t)(i + 1));
ffffffffc0201f58:	6088                	ld	a0,0(s1)
ffffffffc0201f5a:	0ff9f613          	andi	a2,s3,255
ffffffffc0201f5e:	0985                	addi	s3,s3,1
ffffffffc0201f60:	e87ff0ef          	jal	ra,ffffffffc0201de6 <test_verify>
    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
ffffffffc0201f64:	0921                	addi	s2,s2,8
ffffffffc0201f66:	04a1                	addi	s1,s1,8
ffffffffc0201f68:	fd599de3          	bne	s3,s5,ffffffffc0201f42 <test_isolation+0x104>
    }

    /* Free in a permutation of 0..255 (gcd(37, 256) == 1). */
    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
        size_t j = (i * 37) % SLUB_TEST_MAX_OBJS;
        assert(objs[j] != NULL);
ffffffffc0201f6c:	6705                	lui	a4,0x1
ffffffffc0201f6e:	0814                	addi	a3,sp,16
ffffffffc0201f70:	77fd                	lui	a5,0xfffff
ffffffffc0201f72:	9736                	add	a4,a4,a3
ffffffffc0201f74:	97ba                	add	a5,a5,a4
    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
ffffffffc0201f76:	6909                	lui	s2,0x2
        assert(objs[j] != NULL);
ffffffffc0201f78:	e43e                	sd	a5,8(sp)
    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
ffffffffc0201f7a:	50090913          	addi	s2,s2,1280 # 2500 <kern_entry-0xffffffffc01fdb00>
        assert(objs[j] != NULL);
ffffffffc0201f7e:	67a2                	ld	a5,8(sp)
        size_t j = (i * 37) % SLUB_TEST_MAX_OBJS;
ffffffffc0201f80:	0ff47493          	andi	s1,s0,255
        assert(objs[j] != NULL);
ffffffffc0201f84:	048e                	slli	s1,s1,0x3
ffffffffc0201f86:	94be                	add	s1,s1,a5
ffffffffc0201f88:	6088                	ld	a0,0(s1)
ffffffffc0201f8a:	c52d                	beqz	a0,ffffffffc0201ff4 <test_isolation+0x1b6>
        slub_free(objs[j]);
ffffffffc0201f8c:	db4ff0ef          	jal	ra,ffffffffc0201540 <slub_free>
        objs[j] = NULL;
ffffffffc0201f90:	02540413          	addi	s0,s0,37 # 1025 <kern_entry-0xffffffffc01fefdb>
ffffffffc0201f94:	0004b023          	sd	zero,0(s1) # fffffffffffff000 <end+0x3fdf6b80>
    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
ffffffffc0201f98:	ff2413e3          	bne	s0,s2,ffffffffc0201f7e <test_isolation+0x140>
    }

    cprintf("[SLUB Test] %d mixed live objects stay isolated: PASS\n",
            SLUB_TEST_MAX_OBJS);
}
ffffffffc0201f9c:	6305                	lui	t1,0x1
ffffffffc0201f9e:	911a                	add	sp,sp,t1
ffffffffc0201fa0:	70e6                	ld	ra,120(sp)
ffffffffc0201fa2:	7446                	ld	s0,112(sp)
ffffffffc0201fa4:	74a6                	ld	s1,104(sp)
ffffffffc0201fa6:	7906                	ld	s2,96(sp)
ffffffffc0201fa8:	69e6                	ld	s3,88(sp)
ffffffffc0201faa:	6a46                	ld	s4,80(sp)
ffffffffc0201fac:	6aa6                	ld	s5,72(sp)
ffffffffc0201fae:	6b06                	ld	s6,64(sp)
ffffffffc0201fb0:	7be2                	ld	s7,56(sp)
ffffffffc0201fb2:	7c42                	ld	s8,48(sp)
ffffffffc0201fb4:	7ca2                	ld	s9,40(sp)
ffffffffc0201fb6:	7d02                	ld	s10,32(sp)
ffffffffc0201fb8:	6de2                	ld	s11,24(sp)
    cprintf("[SLUB Test] %d mixed live objects stay isolated: PASS\n",
ffffffffc0201fba:	10000593          	li	a1,256
ffffffffc0201fbe:	00002517          	auipc	a0,0x2
ffffffffc0201fc2:	b0a50513          	addi	a0,a0,-1270 # ffffffffc0203ac8 <bs_pmm_manager+0x630>
}
ffffffffc0201fc6:	6109                	addi	sp,sp,128
    cprintf("[SLUB Test] %d mixed live objects stay isolated: PASS\n",
ffffffffc0201fc8:	98cfe06f          	j	ffffffffc0200154 <cprintf>
    size_t rounded = 8;
ffffffffc0201fcc:	45a1                	li	a1,8
ffffffffc0201fce:	b769                	j	ffffffffc0201f58 <test_isolation+0x11a>
ffffffffc0201fd0:	45a1                	li	a1,8
ffffffffc0201fd2:	b72d                	j	ffffffffc0201efc <test_isolation+0xbe>
        assert(objs[i] != NULL);
ffffffffc0201fd4:	00002697          	auipc	a3,0x2
ffffffffc0201fd8:	aa468693          	addi	a3,a3,-1372 # ffffffffc0203a78 <bs_pmm_manager+0x5e0>
ffffffffc0201fdc:	00001617          	auipc	a2,0x1
ffffffffc0201fe0:	1dc60613          	addi	a2,a2,476 # ffffffffc02031b8 <etext+0x434>
ffffffffc0201fe4:	06e00593          	li	a1,110
ffffffffc0201fe8:	00002517          	auipc	a0,0x2
ffffffffc0201fec:	a7850513          	addi	a0,a0,-1416 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc0201ff0:	9dafe0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(objs[j] != NULL);
ffffffffc0201ff4:	00002697          	auipc	a3,0x2
ffffffffc0201ff8:	ac468693          	addi	a3,a3,-1340 # ffffffffc0203ab8 <bs_pmm_manager+0x620>
ffffffffc0201ffc:	00001617          	auipc	a2,0x1
ffffffffc0202000:	1bc60613          	addi	a2,a2,444 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202004:	08200593          	li	a1,130
ffffffffc0202008:	00002517          	auipc	a0,0x2
ffffffffc020200c:	a5850513          	addi	a0,a0,-1448 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc0202010:	9bafe0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(((uintptr_t)objs[i] & (alignment - 1)) == 0);
ffffffffc0202014:	00002697          	auipc	a3,0x2
ffffffffc0202018:	a7468693          	addi	a3,a3,-1420 # ffffffffc0203a88 <bs_pmm_manager+0x5f0>
ffffffffc020201c:	00001617          	auipc	a2,0x1
ffffffffc0202020:	19c60613          	addi	a2,a2,412 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202024:	06f00593          	li	a1,111
ffffffffc0202028:	00002517          	auipc	a0,0x2
ffffffffc020202c:	a3850513          	addi	a0,a0,-1480 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc0202030:	99afe0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0202034 <test_page_reclaim>:

/* 3. Whole-page reclaim and cross-page allocations. */
static void
test_page_reclaim(void) {
ffffffffc0202034:	db010113          	addi	sp,sp,-592
ffffffffc0202038:	24813023          	sd	s0,576(sp)
ffffffffc020203c:	22913c23          	sd	s1,568(sp)
ffffffffc0202040:	23213823          	sd	s2,560(sp)
ffffffffc0202044:	24113423          	sd	ra,584(sp)
ffffffffc0202048:	23313423          	sd	s3,552(sp)
ffffffffc020204c:	23413023          	sd	s4,544(sp)
ffffffffc0202050:	21513c23          	sd	s5,536(sp)
ffffffffc0202054:	21613823          	sd	s6,528(sp)
ffffffffc0202058:	21713423          	sd	s7,520(sp)
    size_t before = nr_free_pages();
ffffffffc020205c:	d9cfe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202060:	892a                	mv	s2,a0

    /* A 4 KiB page holds exactly 64 objects of 64 bytes; the page must only
     * be returned after the 64th object is freed. */
    void *objs64[64];
    for (int i = 0; i < 64; i ++) {
ffffffffc0202062:	840a                	mv	s0,sp
ffffffffc0202064:	0404                	addi	s1,sp,512
        objs64[i] = slub_alloc(64);
ffffffffc0202066:	04000513          	li	a0,64
ffffffffc020206a:	a40ff0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc020206e:	e008                	sd	a0,0(s0)
        assert(objs64[i] != NULL);
ffffffffc0202070:	2a050863          	beqz	a0,ffffffffc0202320 <test_page_reclaim+0x2ec>
    for (int i = 0; i < 64; i ++) {
ffffffffc0202074:	0421                	addi	s0,s0,8
ffffffffc0202076:	fe9418e3          	bne	s0,s1,ffffffffc0202066 <test_page_reclaim+0x32>
    }
    assert(nr_free_pages() == before - 1);
ffffffffc020207a:	d7efe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020207e:	fff90a13          	addi	s4,s2,-1
ffffffffc0202082:	4d451f63          	bne	a0,s4,ffffffffc0202560 <test_page_reclaim+0x52c>

    uintptr_t slab = (uintptr_t)objs64[0] & ~(uintptr_t)(PGSIZE - 1);
ffffffffc0202086:	6b82                	ld	s7,0(sp)
ffffffffc0202088:	0020                	addi	s0,sp,8
ffffffffc020208a:	79fd                	lui	s3,0xfffff
ffffffffc020208c:	013bf9b3          	and	s3,s7,s3
ffffffffc0202090:	85a2                	mv	a1,s0
    for (int i = 0; i < 64; i ++) {
        assert(((uintptr_t)objs64[i] & ~(uintptr_t)(PGSIZE - 1)) == slab);
ffffffffc0202092:	875e                	mv	a4,s7
    uintptr_t slab = (uintptr_t)objs64[0] & ~(uintptr_t)(PGSIZE - 1);
ffffffffc0202094:	0c000613          	li	a2,192
    for (int i = 0; i < 64; i ++) {
ffffffffc0202098:	0ff00513          	li	a0,255
        assert(((uintptr_t)objs64[i] & ~(uintptr_t)(PGSIZE - 1)) == slab);
ffffffffc020209c:	787d                	lui	a6,0xfffff
    for (size_t i = 0; i < size; i ++) {
ffffffffc020209e:	0406079b          	addiw	a5,a2,64
ffffffffc02020a2:	0ff7f793          	andi	a5,a5,255
        p[i] = (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8));
ffffffffc02020a6:	01f7869b          	addiw	a3,a5,31
ffffffffc02020aa:	00f70023          	sb	a5,0(a4) # 1000 <kern_entry-0xffffffffc01ff000>
    for (size_t i = 0; i < size; i ++) {
ffffffffc02020ae:	0ff6f793          	andi	a5,a3,255
ffffffffc02020b2:	0705                	addi	a4,a4,1
ffffffffc02020b4:	fef619e3          	bne	a2,a5,ffffffffc02020a6 <test_page_reclaim+0x72>
    for (int i = 0; i < 64; i ++) {
ffffffffc02020b8:	02a60b63          	beq	a2,a0,ffffffffc02020ee <test_page_reclaim+0xba>
        assert(((uintptr_t)objs64[i] & ~(uintptr_t)(PGSIZE - 1)) == slab);
ffffffffc02020bc:	6198                	ld	a4,0(a1)
ffffffffc02020be:	2605                	addiw	a2,a2,1
ffffffffc02020c0:	05a1                	addi	a1,a1,8
ffffffffc02020c2:	010777b3          	and	a5,a4,a6
ffffffffc02020c6:	0ff67613          	andi	a2,a2,255
ffffffffc02020ca:	fd378ae3          	beq	a5,s3,ffffffffc020209e <test_page_reclaim+0x6a>
ffffffffc02020ce:	00002697          	auipc	a3,0x2
ffffffffc02020d2:	a6a68693          	addi	a3,a3,-1430 # ffffffffc0203b38 <bs_pmm_manager+0x6a0>
ffffffffc02020d6:	00001617          	auipc	a2,0x1
ffffffffc02020da:	0e260613          	addi	a2,a2,226 # ffffffffc02031b8 <etext+0x434>
ffffffffc02020de:	09b00593          	li	a1,155
ffffffffc02020e2:	00002517          	auipc	a0,0x2
ffffffffc02020e6:	97e50513          	addi	a0,a0,-1666 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02020ea:	8e0fe0ef          	jal	ra,ffffffffc02001ca <__panic>
ffffffffc02020ee:	8b22                	mv	s6,s0
ffffffffc02020f0:	855e                	mv	a0,s7
        test_fill(objs64[i], 64, (uint8_t)i);
    }
    for (int i = 0; i < 64; i ++) {
ffffffffc02020f2:	4a81                	li	s5,0
ffffffffc02020f4:	a021                	j	ffffffffc02020fc <test_page_reclaim+0xc8>
ffffffffc02020f6:	000b3503          	ld	a0,0(s6)
ffffffffc02020fa:	0b21                	addi	s6,s6,8
        test_verify(objs64[i], 64, (uint8_t)i);
ffffffffc02020fc:	0ffaf613          	andi	a2,s5,255
ffffffffc0202100:	04000593          	li	a1,64
ffffffffc0202104:	ce3ff0ef          	jal	ra,ffffffffc0201de6 <test_verify>
    for (int i = 0; i < 64; i ++) {
ffffffffc0202108:	2a85                	addiw	s5,s5,1
ffffffffc020210a:	04000793          	li	a5,64
ffffffffc020210e:	fefa94e3          	bne	s5,a5,ffffffffc02020f6 <test_page_reclaim+0xc2>
    }

    void *extra64 = slub_alloc(64);
ffffffffc0202112:	04000513          	li	a0,64
ffffffffc0202116:	994ff0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc020211a:	8aaa                	mv	s5,a0
    assert(extra64 != NULL);
ffffffffc020211c:	42050263          	beqz	a0,ffffffffc0202540 <test_page_reclaim+0x50c>
    assert(((uintptr_t)extra64 & ~(uintptr_t)(PGSIZE - 1)) != slab);
ffffffffc0202120:	77fd                	lui	a5,0xfffff
ffffffffc0202122:	8fe9                	and	a5,a5,a0
ffffffffc0202124:	3f378e63          	beq	a5,s3,ffffffffc0202520 <test_page_reclaim+0x4ec>
    assert(nr_free_pages() == before - 2);
ffffffffc0202128:	cd0fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020212c:	ffe90793          	addi	a5,s2,-2
ffffffffc0202130:	3cf51863          	bne	a0,a5,ffffffffc0202500 <test_page_reclaim+0x4cc>

    slub_free(extra64);
ffffffffc0202134:	8556                	mv	a0,s5
ffffffffc0202136:	c0aff0ef          	jal	ra,ffffffffc0201540 <slub_free>
    assert(nr_free_pages() == before - 1);
ffffffffc020213a:	cbefe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020213e:	00aa0663          	beq	s4,a0,ffffffffc020214a <test_page_reclaim+0x116>
ffffffffc0202142:	ae79                	j	ffffffffc02024e0 <test_page_reclaim+0x4ac>
ffffffffc0202144:	00043b83          	ld	s7,0(s0)
ffffffffc0202148:	0421                	addi	s0,s0,8
    for (int i = 0; i < 64; i ++) {
        slub_free(objs64[i]);
ffffffffc020214a:	855e                	mv	a0,s7
ffffffffc020214c:	bf4ff0ef          	jal	ra,ffffffffc0201540 <slub_free>
    for (int i = 0; i < 64; i ++) {
ffffffffc0202150:	fe849ae3          	bne	s1,s0,ffffffffc0202144 <test_page_reclaim+0x110>
    }
    assert(nr_free_pages() == before);
ffffffffc0202154:	ca4fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202158:	37251463          	bne	a0,s2,ffffffffc02024c0 <test_page_reclaim+0x48c>
    cprintf("[SLUB Test] 64B slab whole-page reclaim: PASS\n");
ffffffffc020215c:	00002517          	auipc	a0,0x2
ffffffffc0202160:	a8450513          	addi	a0,a0,-1404 # ffffffffc0203be0 <bs_pmm_manager+0x748>
ffffffffc0202164:	ff1fd0ef          	jal	ra,ffffffffc0200154 <cprintf>

    /* 2048-byte objects: two per page. */
    before = nr_free_pages();
ffffffffc0202168:	c90fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
    void *objs2048[2];
    for (int i = 0; i < 2; i ++) {
        objs2048[i] = slub_alloc(2048);
ffffffffc020216c:	6485                	lui	s1,0x1
    before = nr_free_pages();
ffffffffc020216e:	842a                	mv	s0,a0
        objs2048[i] = slub_alloc(2048);
ffffffffc0202170:	80048513          	addi	a0,s1,-2048 # 800 <kern_entry-0xffffffffc01ff800>
ffffffffc0202174:	936ff0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc0202178:	8a2a                	mv	s4,a0
        assert(objs2048[i] != NULL);
ffffffffc020217a:	32050363          	beqz	a0,ffffffffc02024a0 <test_page_reclaim+0x46c>
        objs2048[i] = slub_alloc(2048);
ffffffffc020217e:	80048513          	addi	a0,s1,-2048
ffffffffc0202182:	928ff0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc0202186:	892a                	mv	s2,a0
        assert(objs2048[i] != NULL);
ffffffffc0202188:	30050c63          	beqz	a0,ffffffffc02024a0 <test_page_reclaim+0x46c>
    }
    assert(nr_free_pages() == before - 1);
ffffffffc020218c:	c6cfe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202190:	fff40493          	addi	s1,s0,-1
ffffffffc0202194:	2e951663          	bne	a0,s1,ffffffffc0202480 <test_page_reclaim+0x44c>

    slab = (uintptr_t)objs2048[0] & ~(uintptr_t)(PGSIZE - 1);
ffffffffc0202198:	7afd                	lui	s5,0xfffff
ffffffffc020219a:	015a7ab3          	and	s5,s4,s5
ffffffffc020219e:	4681                	li	a3,0
    for (size_t i = 0; i < size; i ++) {
ffffffffc02021a0:	4701                	li	a4,0
        p[i] = (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8));
ffffffffc02021a2:	00875613          	srli	a2,a4,0x8
ffffffffc02021a6:	0406879b          	addiw	a5,a3,64
ffffffffc02021aa:	9fb1                	addw	a5,a5,a2
ffffffffc02021ac:	0ff7f793          	andi	a5,a5,255
ffffffffc02021b0:	00ea0633          	add	a2,s4,a4
    for (size_t i = 0; i < size; i ++) {
ffffffffc02021b4:	0705                	addi	a4,a4,1
ffffffffc02021b6:	26fd                	addiw	a3,a3,31
        p[i] = (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8));
ffffffffc02021b8:	00f60023          	sb	a5,0(a2)
    for (size_t i = 0; i < size; i ++) {
ffffffffc02021bc:	80070793          	addi	a5,a4,-2048
ffffffffc02021c0:	0ff6f693          	andi	a3,a3,255
ffffffffc02021c4:	fff9                	bnez	a5,ffffffffc02021a2 <test_page_reclaim+0x16e>
    for (int i = 0; i < 2; i ++) {
        assert(((uintptr_t)objs2048[i] & ~(uintptr_t)(PGSIZE - 1)) == slab);
ffffffffc02021c6:	77fd                	lui	a5,0xfffff
ffffffffc02021c8:	00f977b3          	and	a5,s2,a5
ffffffffc02021cc:	28fa9a63          	bne	s5,a5,ffffffffc0202460 <test_page_reclaim+0x42c>
ffffffffc02021d0:	4681                	li	a3,0
    for (size_t i = 0; i < size; i ++) {
ffffffffc02021d2:	4701                	li	a4,0
        p[i] = (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8));
ffffffffc02021d4:	00875613          	srli	a2,a4,0x8
ffffffffc02021d8:	0416879b          	addiw	a5,a3,65
ffffffffc02021dc:	9fb1                	addw	a5,a5,a2
ffffffffc02021de:	0ff7f793          	andi	a5,a5,255
ffffffffc02021e2:	00e90633          	add	a2,s2,a4
    for (size_t i = 0; i < size; i ++) {
ffffffffc02021e6:	0705                	addi	a4,a4,1
ffffffffc02021e8:	26fd                	addiw	a3,a3,31
        p[i] = (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8));
ffffffffc02021ea:	00f60023          	sb	a5,0(a2)
    for (size_t i = 0; i < size; i ++) {
ffffffffc02021ee:	80070793          	addi	a5,a4,-2048
ffffffffc02021f2:	0ff6f693          	andi	a3,a3,255
ffffffffc02021f6:	fff9                	bnez	a5,ffffffffc02021d4 <test_page_reclaim+0x1a0>
        test_fill(objs2048[i], 2048, (uint8_t)(0x40 + i));
    }
    for (int i = 0; i < 2; i ++) {
        test_verify(objs2048[i], 2048, (uint8_t)(0x40 + i));
ffffffffc02021f8:	6985                	lui	s3,0x1
ffffffffc02021fa:	04000613          	li	a2,64
ffffffffc02021fe:	80098593          	addi	a1,s3,-2048 # 800 <kern_entry-0xffffffffc01ff800>
ffffffffc0202202:	8552                	mv	a0,s4
ffffffffc0202204:	be3ff0ef          	jal	ra,ffffffffc0201de6 <test_verify>
ffffffffc0202208:	04100613          	li	a2,65
ffffffffc020220c:	80098593          	addi	a1,s3,-2048
ffffffffc0202210:	854a                	mv	a0,s2
ffffffffc0202212:	bd5ff0ef          	jal	ra,ffffffffc0201de6 <test_verify>
    }

    void *extra2048 = slub_alloc(2048);
ffffffffc0202216:	80098513          	addi	a0,s3,-2048
ffffffffc020221a:	890ff0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc020221e:	8b2a                	mv	s6,a0
    assert(extra2048 != NULL);
ffffffffc0202220:	22050063          	beqz	a0,ffffffffc0202440 <test_page_reclaim+0x40c>
    assert(((uintptr_t)extra2048 & ~(uintptr_t)(PGSIZE - 1)) != slab);
ffffffffc0202224:	77fd                	lui	a5,0xfffff
ffffffffc0202226:	8fe9                	and	a5,a5,a0
ffffffffc0202228:	1f578c63          	beq	a5,s5,ffffffffc0202420 <test_page_reclaim+0x3ec>
    assert(nr_free_pages() == before - 2);
ffffffffc020222c:	bccfe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202230:	ffe40793          	addi	a5,s0,-2
ffffffffc0202234:	1cf51663          	bne	a0,a5,ffffffffc0202400 <test_page_reclaim+0x3cc>

    slub_free(extra2048);
ffffffffc0202238:	855a                	mv	a0,s6
ffffffffc020223a:	b06ff0ef          	jal	ra,ffffffffc0201540 <slub_free>
    assert(nr_free_pages() == before - 1);
ffffffffc020223e:	bbafe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202242:	18a49f63          	bne	s1,a0,ffffffffc02023e0 <test_page_reclaim+0x3ac>
    for (int i = 0; i < 2; i ++) {
        slub_free(objs2048[i]);
ffffffffc0202246:	8552                	mv	a0,s4
ffffffffc0202248:	af8ff0ef          	jal	ra,ffffffffc0201540 <slub_free>
ffffffffc020224c:	854a                	mv	a0,s2
ffffffffc020224e:	af2ff0ef          	jal	ra,ffffffffc0201540 <slub_free>
    }
    assert(nr_free_pages() == before);
ffffffffc0202252:	ba6fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202256:	16851563          	bne	a0,s0,ffffffffc02023c0 <test_page_reclaim+0x38c>
    cprintf("[SLUB Test] 2048B slab whole-page reclaim: PASS\n");
ffffffffc020225a:	00002517          	auipc	a0,0x2
ffffffffc020225e:	a6650513          	addi	a0,a0,-1434 # ffffffffc0203cc0 <bs_pmm_manager+0x828>
ffffffffc0202262:	ef3fd0ef          	jal	ra,ffffffffc0200154 <cprintf>

    /* 4097 bytes needs two pages; bytes on both sides of the boundary must
     * be usable. */
    before = nr_free_pages();
ffffffffc0202266:	b92fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020226a:	892a                	mv	s2,a0
    uint8_t *big = (uint8_t *)slub_alloc(4097);
ffffffffc020226c:	00198513          	addi	a0,s3,1
ffffffffc0202270:	83aff0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc0202274:	84aa                	mv	s1,a0
    assert(big != NULL);
ffffffffc0202276:	12050563          	beqz	a0,ffffffffc02023a0 <test_page_reclaim+0x36c>
    assert(((uintptr_t)big & (PGSIZE - 1)) == 0);
ffffffffc020227a:	fff98413          	addi	s0,s3,-1
ffffffffc020227e:	8c69                	and	s0,s0,a0
ffffffffc0202280:	10041063          	bnez	s0,ffffffffc0202380 <test_page_reclaim+0x34c>
    assert(nr_free_pages() == before - 2);
ffffffffc0202284:	b74fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202288:	ffe90793          	addi	a5,s2,-2
ffffffffc020228c:	0cf51a63          	bne	a0,a5,ffffffffc0202360 <test_page_reclaim+0x32c>

    big[0] = 0x11;
ffffffffc0202290:	47c5                	li	a5,17
ffffffffc0202292:	00f48023          	sb	a5,0(s1)
    big[PGSIZE - 1] = 0x22;
ffffffffc0202296:	02200713          	li	a4,34
ffffffffc020229a:	013487b3          	add	a5,s1,s3
ffffffffc020229e:	fee78fa3          	sb	a4,-1(a5) # ffffffffffffefff <end+0x3fdf6b7f>
    big[PGSIZE] = 0x33;
ffffffffc02022a2:	03300713          	li	a4,51
ffffffffc02022a6:	00e78023          	sb	a4,0(a5)
    for (size_t i = 0; i < size; i ++) {
ffffffffc02022aa:	00198613          	addi	a2,s3,1
    big[PGSIZE] = 0x33;
ffffffffc02022ae:	4701                	li	a4,0
        p[i] = (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8));
ffffffffc02022b0:	00845693          	srli	a3,s0,0x8
ffffffffc02022b4:	0777079b          	addiw	a5,a4,119
ffffffffc02022b8:	9fb5                	addw	a5,a5,a3
ffffffffc02022ba:	0ff7f793          	andi	a5,a5,255
ffffffffc02022be:	008486b3          	add	a3,s1,s0
ffffffffc02022c2:	277d                	addiw	a4,a4,31
ffffffffc02022c4:	00f68023          	sb	a5,0(a3)
    for (size_t i = 0; i < size; i ++) {
ffffffffc02022c8:	0405                	addi	s0,s0,1
ffffffffc02022ca:	0ff77713          	andi	a4,a4,255
ffffffffc02022ce:	fec411e3          	bne	s0,a2,ffffffffc02022b0 <test_page_reclaim+0x27c>
    assert(big[PGSIZE - 1] == 0x22);
    assert(big[PGSIZE] == 0x33);

    /* The remaining bytes across both pages must also be usable. */
    test_fill(big, 4097, 0x77);
    test_verify(big, 4097, 0x77);
ffffffffc02022d2:	07700613          	li	a2,119
ffffffffc02022d6:	85a2                	mv	a1,s0
ffffffffc02022d8:	8526                	mv	a0,s1
ffffffffc02022da:	b0dff0ef          	jal	ra,ffffffffc0201de6 <test_verify>

    slub_free(big);
ffffffffc02022de:	8526                	mv	a0,s1
ffffffffc02022e0:	a60ff0ef          	jal	ra,ffffffffc0201540 <slub_free>
    assert(nr_free_pages() == before);
ffffffffc02022e4:	b14fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc02022e8:	05251c63          	bne	a0,s2,ffffffffc0202340 <test_page_reclaim+0x30c>
    cprintf("[SLUB Test] 4097B cross-page allocation: PASS\n");
}
ffffffffc02022ec:	24013403          	ld	s0,576(sp)
ffffffffc02022f0:	24813083          	ld	ra,584(sp)
ffffffffc02022f4:	23813483          	ld	s1,568(sp)
ffffffffc02022f8:	23013903          	ld	s2,560(sp)
ffffffffc02022fc:	22813983          	ld	s3,552(sp)
ffffffffc0202300:	22013a03          	ld	s4,544(sp)
ffffffffc0202304:	21813a83          	ld	s5,536(sp)
ffffffffc0202308:	21013b03          	ld	s6,528(sp)
ffffffffc020230c:	20813b83          	ld	s7,520(sp)
    cprintf("[SLUB Test] 4097B cross-page allocation: PASS\n");
ffffffffc0202310:	00002517          	auipc	a0,0x2
ffffffffc0202314:	a2050513          	addi	a0,a0,-1504 # ffffffffc0203d30 <bs_pmm_manager+0x898>
}
ffffffffc0202318:	25010113          	addi	sp,sp,592
    cprintf("[SLUB Test] 4097B cross-page allocation: PASS\n");
ffffffffc020231c:	e39fd06f          	j	ffffffffc0200154 <cprintf>
        assert(objs64[i] != NULL);
ffffffffc0202320:	00001697          	auipc	a3,0x1
ffffffffc0202324:	7e068693          	addi	a3,a3,2016 # ffffffffc0203b00 <bs_pmm_manager+0x668>
ffffffffc0202328:	00001617          	auipc	a2,0x1
ffffffffc020232c:	e9060613          	addi	a2,a2,-368 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202330:	09500593          	li	a1,149
ffffffffc0202334:	00001517          	auipc	a0,0x1
ffffffffc0202338:	72c50513          	addi	a0,a0,1836 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020233c:	e8ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc0202340:	00001697          	auipc	a3,0x1
ffffffffc0202344:	43068693          	addi	a3,a3,1072 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc0202348:	00001617          	auipc	a2,0x1
ffffffffc020234c:	e7060613          	addi	a2,a2,-400 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202350:	0e200593          	li	a1,226
ffffffffc0202354:	00001517          	auipc	a0,0x1
ffffffffc0202358:	70c50513          	addi	a0,a0,1804 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020235c:	e6ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 2);
ffffffffc0202360:	00002697          	auipc	a3,0x2
ffffffffc0202364:	86068693          	addi	a3,a3,-1952 # ffffffffc0203bc0 <bs_pmm_manager+0x728>
ffffffffc0202368:	00001617          	auipc	a2,0x1
ffffffffc020236c:	e5060613          	addi	a2,a2,-432 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202370:	0d400593          	li	a1,212
ffffffffc0202374:	00001517          	auipc	a0,0x1
ffffffffc0202378:	6ec50513          	addi	a0,a0,1772 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020237c:	e4ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(((uintptr_t)big & (PGSIZE - 1)) == 0);
ffffffffc0202380:	00002697          	auipc	a3,0x2
ffffffffc0202384:	98868693          	addi	a3,a3,-1656 # ffffffffc0203d08 <bs_pmm_manager+0x870>
ffffffffc0202388:	00001617          	auipc	a2,0x1
ffffffffc020238c:	e3060613          	addi	a2,a2,-464 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202390:	0d300593          	li	a1,211
ffffffffc0202394:	00001517          	auipc	a0,0x1
ffffffffc0202398:	6cc50513          	addi	a0,a0,1740 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020239c:	e2ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(big != NULL);
ffffffffc02023a0:	00002697          	auipc	a3,0x2
ffffffffc02023a4:	95868693          	addi	a3,a3,-1704 # ffffffffc0203cf8 <bs_pmm_manager+0x860>
ffffffffc02023a8:	00001617          	auipc	a2,0x1
ffffffffc02023ac:	e1060613          	addi	a2,a2,-496 # ffffffffc02031b8 <etext+0x434>
ffffffffc02023b0:	0d200593          	li	a1,210
ffffffffc02023b4:	00001517          	auipc	a0,0x1
ffffffffc02023b8:	6ac50513          	addi	a0,a0,1708 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02023bc:	e0ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc02023c0:	00001697          	auipc	a3,0x1
ffffffffc02023c4:	3b068693          	addi	a3,a3,944 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc02023c8:	00001617          	auipc	a2,0x1
ffffffffc02023cc:	df060613          	addi	a2,a2,-528 # ffffffffc02031b8 <etext+0x434>
ffffffffc02023d0:	0cb00593          	li	a1,203
ffffffffc02023d4:	00001517          	auipc	a0,0x1
ffffffffc02023d8:	68c50513          	addi	a0,a0,1676 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02023dc:	deffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 1);
ffffffffc02023e0:	00001697          	auipc	a3,0x1
ffffffffc02023e4:	73868693          	addi	a3,a3,1848 # ffffffffc0203b18 <bs_pmm_manager+0x680>
ffffffffc02023e8:	00001617          	auipc	a2,0x1
ffffffffc02023ec:	dd060613          	addi	a2,a2,-560 # ffffffffc02031b8 <etext+0x434>
ffffffffc02023f0:	0c700593          	li	a1,199
ffffffffc02023f4:	00001517          	auipc	a0,0x1
ffffffffc02023f8:	66c50513          	addi	a0,a0,1644 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02023fc:	dcffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 2);
ffffffffc0202400:	00001697          	auipc	a3,0x1
ffffffffc0202404:	7c068693          	addi	a3,a3,1984 # ffffffffc0203bc0 <bs_pmm_manager+0x728>
ffffffffc0202408:	00001617          	auipc	a2,0x1
ffffffffc020240c:	db060613          	addi	a2,a2,-592 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202410:	0c400593          	li	a1,196
ffffffffc0202414:	00001517          	auipc	a0,0x1
ffffffffc0202418:	64c50513          	addi	a0,a0,1612 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020241c:	daffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(((uintptr_t)extra2048 & ~(uintptr_t)(PGSIZE - 1)) != slab);
ffffffffc0202420:	00002697          	auipc	a3,0x2
ffffffffc0202424:	86068693          	addi	a3,a3,-1952 # ffffffffc0203c80 <bs_pmm_manager+0x7e8>
ffffffffc0202428:	00001617          	auipc	a2,0x1
ffffffffc020242c:	d9060613          	addi	a2,a2,-624 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202430:	0c300593          	li	a1,195
ffffffffc0202434:	00001517          	auipc	a0,0x1
ffffffffc0202438:	62c50513          	addi	a0,a0,1580 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020243c:	d8ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(extra2048 != NULL);
ffffffffc0202440:	00002697          	auipc	a3,0x2
ffffffffc0202444:	82868693          	addi	a3,a3,-2008 # ffffffffc0203c68 <bs_pmm_manager+0x7d0>
ffffffffc0202448:	00001617          	auipc	a2,0x1
ffffffffc020244c:	d7060613          	addi	a2,a2,-656 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202450:	0c200593          	li	a1,194
ffffffffc0202454:	00001517          	auipc	a0,0x1
ffffffffc0202458:	60c50513          	addi	a0,a0,1548 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020245c:	d6ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(((uintptr_t)objs2048[i] & ~(uintptr_t)(PGSIZE - 1)) == slab);
ffffffffc0202460:	00001697          	auipc	a3,0x1
ffffffffc0202464:	7c868693          	addi	a3,a3,1992 # ffffffffc0203c28 <bs_pmm_manager+0x790>
ffffffffc0202468:	00001617          	auipc	a2,0x1
ffffffffc020246c:	d5060613          	addi	a2,a2,-688 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202470:	0ba00593          	li	a1,186
ffffffffc0202474:	00001517          	auipc	a0,0x1
ffffffffc0202478:	5ec50513          	addi	a0,a0,1516 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020247c:	d4ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 1);
ffffffffc0202480:	00001697          	auipc	a3,0x1
ffffffffc0202484:	69868693          	addi	a3,a3,1688 # ffffffffc0203b18 <bs_pmm_manager+0x680>
ffffffffc0202488:	00001617          	auipc	a2,0x1
ffffffffc020248c:	d3060613          	addi	a2,a2,-720 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202490:	0b600593          	li	a1,182
ffffffffc0202494:	00001517          	auipc	a0,0x1
ffffffffc0202498:	5cc50513          	addi	a0,a0,1484 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020249c:	d2ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(objs2048[i] != NULL);
ffffffffc02024a0:	00001697          	auipc	a3,0x1
ffffffffc02024a4:	77068693          	addi	a3,a3,1904 # ffffffffc0203c10 <bs_pmm_manager+0x778>
ffffffffc02024a8:	00001617          	auipc	a2,0x1
ffffffffc02024ac:	d1060613          	addi	a2,a2,-752 # ffffffffc02031b8 <etext+0x434>
ffffffffc02024b0:	0b400593          	li	a1,180
ffffffffc02024b4:	00001517          	auipc	a0,0x1
ffffffffc02024b8:	5ac50513          	addi	a0,a0,1452 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02024bc:	d0ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc02024c0:	00001697          	auipc	a3,0x1
ffffffffc02024c4:	2b068693          	addi	a3,a3,688 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc02024c8:	00001617          	auipc	a2,0x1
ffffffffc02024cc:	cf060613          	addi	a2,a2,-784 # ffffffffc02031b8 <etext+0x434>
ffffffffc02024d0:	0ac00593          	li	a1,172
ffffffffc02024d4:	00001517          	auipc	a0,0x1
ffffffffc02024d8:	58c50513          	addi	a0,a0,1420 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02024dc:	ceffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 1);
ffffffffc02024e0:	00001697          	auipc	a3,0x1
ffffffffc02024e4:	63868693          	addi	a3,a3,1592 # ffffffffc0203b18 <bs_pmm_manager+0x680>
ffffffffc02024e8:	00001617          	auipc	a2,0x1
ffffffffc02024ec:	cd060613          	addi	a2,a2,-816 # ffffffffc02031b8 <etext+0x434>
ffffffffc02024f0:	0a800593          	li	a1,168
ffffffffc02024f4:	00001517          	auipc	a0,0x1
ffffffffc02024f8:	56c50513          	addi	a0,a0,1388 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02024fc:	ccffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 2);
ffffffffc0202500:	00001697          	auipc	a3,0x1
ffffffffc0202504:	6c068693          	addi	a3,a3,1728 # ffffffffc0203bc0 <bs_pmm_manager+0x728>
ffffffffc0202508:	00001617          	auipc	a2,0x1
ffffffffc020250c:	cb060613          	addi	a2,a2,-848 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202510:	0a500593          	li	a1,165
ffffffffc0202514:	00001517          	auipc	a0,0x1
ffffffffc0202518:	54c50513          	addi	a0,a0,1356 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020251c:	caffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(((uintptr_t)extra64 & ~(uintptr_t)(PGSIZE - 1)) != slab);
ffffffffc0202520:	00001697          	auipc	a3,0x1
ffffffffc0202524:	66868693          	addi	a3,a3,1640 # ffffffffc0203b88 <bs_pmm_manager+0x6f0>
ffffffffc0202528:	00001617          	auipc	a2,0x1
ffffffffc020252c:	c9060613          	addi	a2,a2,-880 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202530:	0a400593          	li	a1,164
ffffffffc0202534:	00001517          	auipc	a0,0x1
ffffffffc0202538:	52c50513          	addi	a0,a0,1324 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020253c:	c8ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(extra64 != NULL);
ffffffffc0202540:	00001697          	auipc	a3,0x1
ffffffffc0202544:	63868693          	addi	a3,a3,1592 # ffffffffc0203b78 <bs_pmm_manager+0x6e0>
ffffffffc0202548:	00001617          	auipc	a2,0x1
ffffffffc020254c:	c7060613          	addi	a2,a2,-912 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202550:	0a300593          	li	a1,163
ffffffffc0202554:	00001517          	auipc	a0,0x1
ffffffffc0202558:	50c50513          	addi	a0,a0,1292 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020255c:	c6ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 1);
ffffffffc0202560:	00001697          	auipc	a3,0x1
ffffffffc0202564:	5b868693          	addi	a3,a3,1464 # ffffffffc0203b18 <bs_pmm_manager+0x680>
ffffffffc0202568:	00001617          	auipc	a2,0x1
ffffffffc020256c:	c5060613          	addi	a2,a2,-944 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202570:	09700593          	li	a1,151
ffffffffc0202574:	00001517          	auipc	a0,0x1
ffffffffc0202578:	4ec50513          	addi	a0,a0,1260 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020257c:	c4ffd0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0202580 <slub_check>:
    assert(nr_free_pages() == before);
    cprintf("[SLUB Test] alloc_pages/free_pages page path: PASS\n");
}

void
slub_check(void) {
ffffffffc0202580:	715d                	addi	sp,sp,-80
    cprintf("[SLUB Test] begin\n");
ffffffffc0202582:	00001517          	auipc	a0,0x1
ffffffffc0202586:	7de50513          	addi	a0,a0,2014 # ffffffffc0203d60 <bs_pmm_manager+0x8c8>
slub_check(void) {
ffffffffc020258a:	e486                	sd	ra,72(sp)
ffffffffc020258c:	fc26                	sd	s1,56(sp)
ffffffffc020258e:	f052                	sd	s4,32(sp)
ffffffffc0202590:	ec56                	sd	s5,24(sp)
ffffffffc0202592:	e85a                	sd	s6,16(sp)
ffffffffc0202594:	e45e                	sd	s7,8(sp)
ffffffffc0202596:	e062                	sd	s8,0(sp)
ffffffffc0202598:	e0a2                	sd	s0,64(sp)
ffffffffc020259a:	f84a                	sd	s2,48(sp)
ffffffffc020259c:	f44e                	sd	s3,40(sp)
    cprintf("[SLUB Test] begin\n");
ffffffffc020259e:	bb7fd0ef          	jal	ra,ffffffffc0200154 <cprintf>
    size_t baseline = nr_free_pages();
ffffffffc02025a2:	856fe0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
    if (size <= 2048) {
ffffffffc02025a6:	6a85                	lui	s5,0x1
    size_t baseline = nr_free_pages();
ffffffffc02025a8:	84aa                	mv	s1,a0
    if (size <= 2048) {
ffffffffc02025aa:	800a8a93          	addi	s5,s5,-2048 # 800 <kern_entry-0xffffffffc01ff800>
    size_t baseline = nr_free_pages();
ffffffffc02025ae:	4505                	li	a0,1
ffffffffc02025b0:	00002c17          	auipc	s8,0x2
ffffffffc02025b4:	9d0c0c13          	addi	s8,s8,-1584 # ffffffffc0203f80 <sizes.1225+0x8>
ffffffffc02025b8:	4a05                	li	s4,1
    while (rounded < size) {
ffffffffc02025ba:	4ba1                	li	s7,8
    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i ++) {
ffffffffc02025bc:	02300b13          	li	s6,35
    if (size <= 2048) {
ffffffffc02025c0:	06aae563          	bltu	s5,a0,ffffffffc020262a <slub_check+0xaa>
    while (rounded < size) {
ffffffffc02025c4:	06abf663          	bgeu	s7,a0,ffffffffc0202630 <slub_check+0xb0>
    size_t rounded = 8;
ffffffffc02025c8:	49a1                	li	s3,8
        rounded <<= 1;
ffffffffc02025ca:	0986                	slli	s3,s3,0x1
    while (rounded < size) {
ffffffffc02025cc:	fea9efe3          	bltu	s3,a0,ffffffffc02025ca <slub_check+0x4a>
        rounded <<= 1;
ffffffffc02025d0:	844e                	mv	s0,s3
        void *p = slub_alloc(size);
ffffffffc02025d2:	cd9fe0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc02025d6:	892a                	mv	s2,a0
        assert(p != NULL);
ffffffffc02025d8:	16050c63          	beqz	a0,ffffffffc0202750 <slub_check+0x1d0>
        assert(((uintptr_t)p & (alignment - 1)) == 0);
ffffffffc02025dc:	fff40593          	addi	a1,s0,-1
ffffffffc02025e0:	8de9                	and	a1,a1,a0
ffffffffc02025e2:	18059763          	bnez	a1,ffffffffc0202770 <slub_check+0x1f0>
        test_fill(p, writable, (uint8_t)(i + 1));
ffffffffc02025e6:	0ffa7613          	andi	a2,s4,255
        assert(((uintptr_t)p & (alignment - 1)) == 0);
ffffffffc02025ea:	4781                	li	a5,0
        p[i] = (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8));
ffffffffc02025ec:	0085d693          	srli	a3,a1,0x8
ffffffffc02025f0:	00c7873b          	addw	a4,a5,a2
ffffffffc02025f4:	9f35                	addw	a4,a4,a3
ffffffffc02025f6:	0ff77713          	andi	a4,a4,255
ffffffffc02025fa:	00b906b3          	add	a3,s2,a1
ffffffffc02025fe:	27fd                	addiw	a5,a5,31
ffffffffc0202600:	00e68023          	sb	a4,0(a3)
    for (size_t i = 0; i < size; i ++) {
ffffffffc0202604:	0585                	addi	a1,a1,1
ffffffffc0202606:	0ff7f793          	andi	a5,a5,255
ffffffffc020260a:	ff3591e3          	bne	a1,s3,ffffffffc02025ec <slub_check+0x6c>
        test_verify(p, writable, (uint8_t)(i + 1));
ffffffffc020260e:	854a                	mv	a0,s2
ffffffffc0202610:	fd6ff0ef          	jal	ra,ffffffffc0201de6 <test_verify>
        slub_free(p);
ffffffffc0202614:	0a05                	addi	s4,s4,1
ffffffffc0202616:	854a                	mv	a0,s2
ffffffffc0202618:	f29fe0ef          	jal	ra,ffffffffc0201540 <slub_free>
    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i ++) {
ffffffffc020261c:	016a0d63          	beq	s4,s6,ffffffffc0202636 <slub_check+0xb6>
ffffffffc0202620:	000c3503          	ld	a0,0(s8)
ffffffffc0202624:	0c21                	addi	s8,s8,8
    if (size <= 2048) {
ffffffffc0202626:	f8aaffe3          	bgeu	s5,a0,ffffffffc02025c4 <slub_check+0x44>
ffffffffc020262a:	89aa                	mv	s3,a0
        *alignment = PGSIZE;
ffffffffc020262c:	6405                	lui	s0,0x1
ffffffffc020262e:	b755                	j	ffffffffc02025d2 <slub_check+0x52>
    size_t rounded = 8;
ffffffffc0202630:	4421                	li	s0,8
ffffffffc0202632:	49a1                	li	s3,8
ffffffffc0202634:	bf79                	j	ffffffffc02025d2 <slub_check+0x52>
    cprintf("[SLUB Test] size boundaries and rounding: PASS\n");
ffffffffc0202636:	00001517          	auipc	a0,0x1
ffffffffc020263a:	76a50513          	addi	a0,a0,1898 # ffffffffc0203da0 <bs_pmm_manager+0x908>
ffffffffc020263e:	b17fd0ef          	jal	ra,ffffffffc0200154 <cprintf>

    test_boundaries();
    test_isolation();
ffffffffc0202642:	ffcff0ef          	jal	ra,ffffffffc0201e3e <test_isolation>
    test_page_reclaim();
ffffffffc0202646:	9efff0ef          	jal	ra,ffffffffc0202034 <test_page_reclaim>
    size_t before = nr_free_pages();
ffffffffc020264a:	faffd0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020264e:	842a                	mv	s0,a0
    slub_free(NULL);
ffffffffc0202650:	4501                	li	a0,0
ffffffffc0202652:	eeffe0ef          	jal	ra,ffffffffc0201540 <slub_free>
    assert(nr_free_pages() == before);
ffffffffc0202656:	fa3fd0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020265a:	12a41b63          	bne	s0,a0,ffffffffc0202790 <slub_check+0x210>
    assert(slub_alloc((size_t)-1) == NULL);
ffffffffc020265e:	557d                	li	a0,-1
ffffffffc0202660:	c4bfe0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc0202664:	16051663          	bnez	a0,ffffffffc02027d0 <slub_check+0x250>
    assert(nr_free_pages() == before);
ffffffffc0202668:	f91fd0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020266c:	14a41263          	bne	s0,a0,ffffffffc02027b0 <slub_check+0x230>
    assert(slub_alloc((size_t)1 << 40) == NULL);
ffffffffc0202670:	4505                	li	a0,1
ffffffffc0202672:	1522                	slli	a0,a0,0x28
ffffffffc0202674:	c37fe0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc0202678:	24051c63          	bnez	a0,ffffffffc02028d0 <slub_check+0x350>
    assert(nr_free_pages() == before);
ffffffffc020267c:	f7dfd0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202680:	22a41863          	bne	s0,a0,ffffffffc02028b0 <slub_check+0x330>
    assert(slub_alloc((nr_free_pages() + 1) * PGSIZE) == NULL);
ffffffffc0202684:	f75fd0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202688:	0505                	addi	a0,a0,1
ffffffffc020268a:	0532                	slli	a0,a0,0xc
ffffffffc020268c:	c1ffe0ef          	jal	ra,ffffffffc02012aa <slub_alloc>
ffffffffc0202690:	20051063          	bnez	a0,ffffffffc0202890 <slub_check+0x310>
    assert(nr_free_pages() == before);
ffffffffc0202694:	f65fd0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202698:	1ca41c63          	bne	s0,a0,ffffffffc0202870 <slub_check+0x2f0>
    cprintf("[SLUB Test] oversized allocation and free(NULL): PASS\n");
ffffffffc020269c:	00001517          	auipc	a0,0x1
ffffffffc02026a0:	7b450513          	addi	a0,a0,1972 # ffffffffc0203e50 <bs_pmm_manager+0x9b8>
ffffffffc02026a4:	ab1fd0ef          	jal	ra,ffffffffc0200154 <cprintf>
    size_t before = nr_free_pages();
ffffffffc02026a8:	f51fd0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc02026ac:	892a                	mv	s2,a0
    struct Page *page = alloc_pages(2);
ffffffffc02026ae:	4509                	li	a0,2
ffffffffc02026b0:	ecdfd0ef          	jal	ra,ffffffffc020057c <alloc_pages>
ffffffffc02026b4:	842a                	mv	s0,a0
    assert(page != NULL);
ffffffffc02026b6:	18050d63          	beqz	a0,ffffffffc0202850 <slub_check+0x2d0>
    assert(nr_free_pages() == before - 2);
ffffffffc02026ba:	f3ffd0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc02026be:	ffe90793          	addi	a5,s2,-2
ffffffffc02026c2:	16f51763          	bne	a0,a5,ffffffffc0202830 <slub_check+0x2b0>
ffffffffc02026c6:	00006797          	auipc	a5,0x6
ffffffffc02026ca:	db27b783          	ld	a5,-590(a5) # ffffffffc0208478 <pages>
ffffffffc02026ce:	40f407b3          	sub	a5,s0,a5
ffffffffc02026d2:	00002717          	auipc	a4,0x2
ffffffffc02026d6:	c0673703          	ld	a4,-1018(a4) # ffffffffc02042d8 <nbase+0x8>
ffffffffc02026da:	878d                	srai	a5,a5,0x3
ffffffffc02026dc:	02e787b3          	mul	a5,a5,a4
ffffffffc02026e0:	00002717          	auipc	a4,0x2
ffffffffc02026e4:	bf073703          	ld	a4,-1040(a4) # ffffffffc02042d0 <nbase>
    free_pages(page, 2);
ffffffffc02026e8:	4589                	li	a1,2
ffffffffc02026ea:	8522                	mv	a0,s0
ffffffffc02026ec:	97ba                	add	a5,a5,a4
    return page2ppn(page) << PGSHIFT;
ffffffffc02026ee:	07b2                	slli	a5,a5,0xc
    uint8_t *kva = (uint8_t *)(page2pa(page) + va_pa_offset);
ffffffffc02026f0:	00006717          	auipc	a4,0x6
ffffffffc02026f4:	d8073703          	ld	a4,-640(a4) # ffffffffc0208470 <va_pa_offset>
ffffffffc02026f8:	97ba                	add	a5,a5,a4
    kva[0] = 0x5a;
ffffffffc02026fa:	05a00713          	li	a4,90
ffffffffc02026fe:	00e78023          	sb	a4,0(a5)
    kva[PGSIZE] = 0xa5;
ffffffffc0202702:	6705                	lui	a4,0x1
ffffffffc0202704:	97ba                	add	a5,a5,a4
ffffffffc0202706:	fa500713          	li	a4,-91
ffffffffc020270a:	00e78023          	sb	a4,0(a5)
    free_pages(page, 2);
ffffffffc020270e:	eddfd0ef          	jal	ra,ffffffffc02005ea <free_pages>
    assert(nr_free_pages() == before);
ffffffffc0202712:	ee7fd0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc0202716:	0ea91d63          	bne	s2,a0,ffffffffc0202810 <slub_check+0x290>
    cprintf("[SLUB Test] alloc_pages/free_pages page path: PASS\n");
ffffffffc020271a:	00001517          	auipc	a0,0x1
ffffffffc020271e:	77e50513          	addi	a0,a0,1918 # ffffffffc0203e98 <bs_pmm_manager+0xa00>
ffffffffc0202722:	a33fd0ef          	jal	ra,ffffffffc0200154 <cprintf>
    test_invalid_requests();
    test_page_api();

    assert(nr_free_pages() == baseline);
ffffffffc0202726:	ed3fd0ef          	jal	ra,ffffffffc02005f8 <nr_free_pages>
ffffffffc020272a:	0c951363          	bne	a0,s1,ffffffffc02027f0 <slub_check+0x270>
    cprintf("[SLUB Test] ALL PASS\n");
}
ffffffffc020272e:	6406                	ld	s0,64(sp)
ffffffffc0202730:	60a6                	ld	ra,72(sp)
ffffffffc0202732:	74e2                	ld	s1,56(sp)
ffffffffc0202734:	7942                	ld	s2,48(sp)
ffffffffc0202736:	79a2                	ld	s3,40(sp)
ffffffffc0202738:	7a02                	ld	s4,32(sp)
ffffffffc020273a:	6ae2                	ld	s5,24(sp)
ffffffffc020273c:	6b42                	ld	s6,16(sp)
ffffffffc020273e:	6ba2                	ld	s7,8(sp)
ffffffffc0202740:	6c02                	ld	s8,0(sp)
    cprintf("[SLUB Test] ALL PASS\n");
ffffffffc0202742:	00001517          	auipc	a0,0x1
ffffffffc0202746:	7ae50513          	addi	a0,a0,1966 # ffffffffc0203ef0 <bs_pmm_manager+0xa58>
}
ffffffffc020274a:	6161                	addi	sp,sp,80
    cprintf("[SLUB Test] ALL PASS\n");
ffffffffc020274c:	a09fd06f          	j	ffffffffc0200154 <cprintf>
        assert(p != NULL);
ffffffffc0202750:	00001697          	auipc	a3,0x1
ffffffffc0202754:	fd868693          	addi	a3,a3,-40 # ffffffffc0203728 <bs_pmm_manager+0x290>
ffffffffc0202758:	00001617          	auipc	a2,0x1
ffffffffc020275c:	a6060613          	addi	a2,a2,-1440 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202760:	05100593          	li	a1,81
ffffffffc0202764:	00001517          	auipc	a0,0x1
ffffffffc0202768:	2fc50513          	addi	a0,a0,764 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020276c:	a5ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(((uintptr_t)p & (alignment - 1)) == 0);
ffffffffc0202770:	00001697          	auipc	a3,0x1
ffffffffc0202774:	60868693          	addi	a3,a3,1544 # ffffffffc0203d78 <bs_pmm_manager+0x8e0>
ffffffffc0202778:	00001617          	auipc	a2,0x1
ffffffffc020277c:	a4060613          	addi	a2,a2,-1472 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202780:	05200593          	li	a1,82
ffffffffc0202784:	00001517          	auipc	a0,0x1
ffffffffc0202788:	2dc50513          	addi	a0,a0,732 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020278c:	a3ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc0202790:	00001697          	auipc	a3,0x1
ffffffffc0202794:	fe068693          	addi	a3,a3,-32 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc0202798:	00001617          	auipc	a2,0x1
ffffffffc020279c:	a2060613          	addi	a2,a2,-1504 # ffffffffc02031b8 <etext+0x434>
ffffffffc02027a0:	0ec00593          	li	a1,236
ffffffffc02027a4:	00001517          	auipc	a0,0x1
ffffffffc02027a8:	2bc50513          	addi	a0,a0,700 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02027ac:	a1ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc02027b0:	00001697          	auipc	a3,0x1
ffffffffc02027b4:	fc068693          	addi	a3,a3,-64 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc02027b8:	00001617          	auipc	a2,0x1
ffffffffc02027bc:	a0060613          	addi	a2,a2,-1536 # ffffffffc02031b8 <etext+0x434>
ffffffffc02027c0:	0ef00593          	li	a1,239
ffffffffc02027c4:	00001517          	auipc	a0,0x1
ffffffffc02027c8:	29c50513          	addi	a0,a0,668 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02027cc:	9fffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(slub_alloc((size_t)-1) == NULL);
ffffffffc02027d0:	00001697          	auipc	a3,0x1
ffffffffc02027d4:	60068693          	addi	a3,a3,1536 # ffffffffc0203dd0 <bs_pmm_manager+0x938>
ffffffffc02027d8:	00001617          	auipc	a2,0x1
ffffffffc02027dc:	9e060613          	addi	a2,a2,-1568 # ffffffffc02031b8 <etext+0x434>
ffffffffc02027e0:	0ee00593          	li	a1,238
ffffffffc02027e4:	00001517          	auipc	a0,0x1
ffffffffc02027e8:	27c50513          	addi	a0,a0,636 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02027ec:	9dffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == baseline);
ffffffffc02027f0:	00001697          	auipc	a3,0x1
ffffffffc02027f4:	6e068693          	addi	a3,a3,1760 # ffffffffc0203ed0 <bs_pmm_manager+0xa38>
ffffffffc02027f8:	00001617          	auipc	a2,0x1
ffffffffc02027fc:	9c060613          	addi	a2,a2,-1600 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202800:	11900593          	li	a1,281
ffffffffc0202804:	00001517          	auipc	a0,0x1
ffffffffc0202808:	25c50513          	addi	a0,a0,604 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020280c:	9bffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc0202810:	00001697          	auipc	a3,0x1
ffffffffc0202814:	f6068693          	addi	a3,a3,-160 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc0202818:	00001617          	auipc	a2,0x1
ffffffffc020281c:	9a060613          	addi	a2,a2,-1632 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202820:	10a00593          	li	a1,266
ffffffffc0202824:	00001517          	auipc	a0,0x1
ffffffffc0202828:	23c50513          	addi	a0,a0,572 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020282c:	99ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before - 2);
ffffffffc0202830:	00001697          	auipc	a3,0x1
ffffffffc0202834:	39068693          	addi	a3,a3,912 # ffffffffc0203bc0 <bs_pmm_manager+0x728>
ffffffffc0202838:	00001617          	auipc	a2,0x1
ffffffffc020283c:	98060613          	addi	a2,a2,-1664 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202840:	10100593          	li	a1,257
ffffffffc0202844:	00001517          	auipc	a0,0x1
ffffffffc0202848:	21c50513          	addi	a0,a0,540 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020284c:	97ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(page != NULL);
ffffffffc0202850:	00001697          	auipc	a3,0x1
ffffffffc0202854:	63868693          	addi	a3,a3,1592 # ffffffffc0203e88 <bs_pmm_manager+0x9f0>
ffffffffc0202858:	00001617          	auipc	a2,0x1
ffffffffc020285c:	96060613          	addi	a2,a2,-1696 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202860:	10000593          	li	a1,256
ffffffffc0202864:	00001517          	auipc	a0,0x1
ffffffffc0202868:	1fc50513          	addi	a0,a0,508 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020286c:	95ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc0202870:	00001697          	auipc	a3,0x1
ffffffffc0202874:	f0068693          	addi	a3,a3,-256 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc0202878:	00001617          	auipc	a2,0x1
ffffffffc020287c:	94060613          	addi	a2,a2,-1728 # ffffffffc02031b8 <etext+0x434>
ffffffffc0202880:	0f500593          	li	a1,245
ffffffffc0202884:	00001517          	auipc	a0,0x1
ffffffffc0202888:	1dc50513          	addi	a0,a0,476 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc020288c:	93ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(slub_alloc((nr_free_pages() + 1) * PGSIZE) == NULL);
ffffffffc0202890:	00001697          	auipc	a3,0x1
ffffffffc0202894:	58868693          	addi	a3,a3,1416 # ffffffffc0203e18 <bs_pmm_manager+0x980>
ffffffffc0202898:	00001617          	auipc	a2,0x1
ffffffffc020289c:	92060613          	addi	a2,a2,-1760 # ffffffffc02031b8 <etext+0x434>
ffffffffc02028a0:	0f400593          	li	a1,244
ffffffffc02028a4:	00001517          	auipc	a0,0x1
ffffffffc02028a8:	1bc50513          	addi	a0,a0,444 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02028ac:	91ffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == before);
ffffffffc02028b0:	00001697          	auipc	a3,0x1
ffffffffc02028b4:	ec068693          	addi	a3,a3,-320 # ffffffffc0203770 <bs_pmm_manager+0x2d8>
ffffffffc02028b8:	00001617          	auipc	a2,0x1
ffffffffc02028bc:	90060613          	addi	a2,a2,-1792 # ffffffffc02031b8 <etext+0x434>
ffffffffc02028c0:	0f200593          	li	a1,242
ffffffffc02028c4:	00001517          	auipc	a0,0x1
ffffffffc02028c8:	19c50513          	addi	a0,a0,412 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02028cc:	8fffd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(slub_alloc((size_t)1 << 40) == NULL);
ffffffffc02028d0:	00001697          	auipc	a3,0x1
ffffffffc02028d4:	52068693          	addi	a3,a3,1312 # ffffffffc0203df0 <bs_pmm_manager+0x958>
ffffffffc02028d8:	00001617          	auipc	a2,0x1
ffffffffc02028dc:	8e060613          	addi	a2,a2,-1824 # ffffffffc02031b8 <etext+0x434>
ffffffffc02028e0:	0f100593          	li	a1,241
ffffffffc02028e4:	00001517          	auipc	a0,0x1
ffffffffc02028e8:	17c50513          	addi	a0,a0,380 # ffffffffc0203a60 <bs_pmm_manager+0x5c8>
ffffffffc02028ec:	8dffd0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc02028f0 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc02028f0:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc02028f4:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc02028f6:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc02028f8:	cb81                	beqz	a5,ffffffffc0202908 <strlen+0x18>
        cnt ++;
ffffffffc02028fa:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc02028fc:	00a707b3          	add	a5,a4,a0
ffffffffc0202900:	0007c783          	lbu	a5,0(a5)
ffffffffc0202904:	fbfd                	bnez	a5,ffffffffc02028fa <strlen+0xa>
ffffffffc0202906:	8082                	ret
    }
    return cnt;
}
ffffffffc0202908:	8082                	ret

ffffffffc020290a <strnlen>:
 * The return value is strlen(s), if that is less than @len, or
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
ffffffffc020290a:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc020290c:	4501                	li	a0,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc020290e:	e589                	bnez	a1,ffffffffc0202918 <strnlen+0xe>
ffffffffc0202910:	a811                	j	ffffffffc0202924 <strnlen+0x1a>
        cnt ++;
ffffffffc0202912:	0505                	addi	a0,a0,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0202914:	00a58763          	beq	a1,a0,ffffffffc0202922 <strnlen+0x18>
ffffffffc0202918:	00a707b3          	add	a5,a4,a0
ffffffffc020291c:	0007c783          	lbu	a5,0(a5)
ffffffffc0202920:	fbed                	bnez	a5,ffffffffc0202912 <strnlen+0x8>
    }
    return cnt;
}
ffffffffc0202922:	8082                	ret
ffffffffc0202924:	8082                	ret

ffffffffc0202926 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0202926:	00054783          	lbu	a5,0(a0)
ffffffffc020292a:	0005c703          	lbu	a4,0(a1)
ffffffffc020292e:	cb89                	beqz	a5,ffffffffc0202940 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc0202930:	0505                	addi	a0,a0,1
ffffffffc0202932:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0202934:	fee789e3          	beq	a5,a4,ffffffffc0202926 <strcmp>
ffffffffc0202938:	0007851b          	sext.w	a0,a5
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc020293c:	9d19                	subw	a0,a0,a4
ffffffffc020293e:	8082                	ret
ffffffffc0202940:	4501                	li	a0,0
ffffffffc0202942:	bfed                	j	ffffffffc020293c <strcmp+0x16>

ffffffffc0202944 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0202944:	c20d                	beqz	a2,ffffffffc0202966 <strncmp+0x22>
ffffffffc0202946:	962e                	add	a2,a2,a1
ffffffffc0202948:	a031                	j	ffffffffc0202954 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc020294a:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020294c:	00e79a63          	bne	a5,a4,ffffffffc0202960 <strncmp+0x1c>
ffffffffc0202950:	00b60b63          	beq	a2,a1,ffffffffc0202966 <strncmp+0x22>
ffffffffc0202954:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0202958:	0585                	addi	a1,a1,1
ffffffffc020295a:	fff5c703          	lbu	a4,-1(a1)
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020295e:	f7f5                	bnez	a5,ffffffffc020294a <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0202960:	40e7853b          	subw	a0,a5,a4
}
ffffffffc0202964:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0202966:	4501                	li	a0,0
ffffffffc0202968:	8082                	ret

ffffffffc020296a <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc020296a:	ca01                	beqz	a2,ffffffffc020297a <memset+0x10>
ffffffffc020296c:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc020296e:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0202970:	0785                	addi	a5,a5,1
ffffffffc0202972:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0202976:	fec79de3          	bne	a5,a2,ffffffffc0202970 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc020297a:	8082                	ret

ffffffffc020297c <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc020297c:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0202980:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0202982:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0202986:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0202988:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc020298c:	f022                	sd	s0,32(sp)
ffffffffc020298e:	ec26                	sd	s1,24(sp)
ffffffffc0202990:	e84a                	sd	s2,16(sp)
ffffffffc0202992:	f406                	sd	ra,40(sp)
ffffffffc0202994:	e44e                	sd	s3,8(sp)
ffffffffc0202996:	84aa                	mv	s1,a0
ffffffffc0202998:	892e                	mv	s2,a1
ffffffffc020299a:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc020299e:	2a01                	sext.w	s4,s4

    // first recursively print all preceding (more significant) digits
    if (num >= base) {
ffffffffc02029a0:	03067e63          	bgeu	a2,a6,ffffffffc02029dc <printnum+0x60>
ffffffffc02029a4:	89be                	mv	s3,a5
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc02029a6:	00805763          	blez	s0,ffffffffc02029b4 <printnum+0x38>
ffffffffc02029aa:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc02029ac:	85ca                	mv	a1,s2
ffffffffc02029ae:	854e                	mv	a0,s3
ffffffffc02029b0:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc02029b2:	fc65                	bnez	s0,ffffffffc02029aa <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02029b4:	1a02                	slli	s4,s4,0x20
ffffffffc02029b6:	020a5a13          	srli	s4,s4,0x20
ffffffffc02029ba:	00001797          	auipc	a5,0x1
ffffffffc02029be:	6ce78793          	addi	a5,a5,1742 # ffffffffc0204088 <sizes.1225+0x110>
}
ffffffffc02029c2:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02029c4:	9a3e                	add	s4,s4,a5
ffffffffc02029c6:	000a4503          	lbu	a0,0(s4)
}
ffffffffc02029ca:	70a2                	ld	ra,40(sp)
ffffffffc02029cc:	69a2                	ld	s3,8(sp)
ffffffffc02029ce:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02029d0:	85ca                	mv	a1,s2
ffffffffc02029d2:	8326                	mv	t1,s1
}
ffffffffc02029d4:	6942                	ld	s2,16(sp)
ffffffffc02029d6:	64e2                	ld	s1,24(sp)
ffffffffc02029d8:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02029da:	8302                	jr	t1
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc02029dc:	03065633          	divu	a2,a2,a6
ffffffffc02029e0:	8722                	mv	a4,s0
ffffffffc02029e2:	f9bff0ef          	jal	ra,ffffffffc020297c <printnum>
ffffffffc02029e6:	b7f9                	j	ffffffffc02029b4 <printnum+0x38>

ffffffffc02029e8 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc02029e8:	7119                	addi	sp,sp,-128
ffffffffc02029ea:	f4a6                	sd	s1,104(sp)
ffffffffc02029ec:	f0ca                	sd	s2,96(sp)
ffffffffc02029ee:	ecce                	sd	s3,88(sp)
ffffffffc02029f0:	e8d2                	sd	s4,80(sp)
ffffffffc02029f2:	e4d6                	sd	s5,72(sp)
ffffffffc02029f4:	e0da                	sd	s6,64(sp)
ffffffffc02029f6:	fc5e                	sd	s7,56(sp)
ffffffffc02029f8:	f06a                	sd	s10,32(sp)
ffffffffc02029fa:	fc86                	sd	ra,120(sp)
ffffffffc02029fc:	f8a2                	sd	s0,112(sp)
ffffffffc02029fe:	f862                	sd	s8,48(sp)
ffffffffc0202a00:	f466                	sd	s9,40(sp)
ffffffffc0202a02:	ec6e                	sd	s11,24(sp)
ffffffffc0202a04:	892a                	mv	s2,a0
ffffffffc0202a06:	84ae                	mv	s1,a1
ffffffffc0202a08:	8d32                	mv	s10,a2
ffffffffc0202a0a:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0202a0c:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc0202a10:	5b7d                	li	s6,-1
ffffffffc0202a12:	00001a97          	auipc	s5,0x1
ffffffffc0202a16:	6aaa8a93          	addi	s5,s5,1706 # ffffffffc02040bc <sizes.1225+0x144>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0202a1a:	00002b97          	auipc	s7,0x2
ffffffffc0202a1e:	87eb8b93          	addi	s7,s7,-1922 # ffffffffc0204298 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0202a22:	000d4503          	lbu	a0,0(s10)
ffffffffc0202a26:	001d0413          	addi	s0,s10,1
ffffffffc0202a2a:	01350a63          	beq	a0,s3,ffffffffc0202a3e <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc0202a2e:	c121                	beqz	a0,ffffffffc0202a6e <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc0202a30:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0202a32:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc0202a34:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0202a36:	fff44503          	lbu	a0,-1(s0) # fff <kern_entry-0xffffffffc01ff001>
ffffffffc0202a3a:	ff351ae3          	bne	a0,s3,ffffffffc0202a2e <vprintfmt+0x46>
ffffffffc0202a3e:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc0202a42:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc0202a46:	4c81                	li	s9,0
ffffffffc0202a48:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0202a4a:	5c7d                	li	s8,-1
ffffffffc0202a4c:	5dfd                	li	s11,-1
ffffffffc0202a4e:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc0202a52:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202a54:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0202a58:	0ff5f593          	andi	a1,a1,255
ffffffffc0202a5c:	00140d13          	addi	s10,s0,1
ffffffffc0202a60:	04b56263          	bltu	a0,a1,ffffffffc0202aa4 <vprintfmt+0xbc>
ffffffffc0202a64:	058a                	slli	a1,a1,0x2
ffffffffc0202a66:	95d6                	add	a1,a1,s5
ffffffffc0202a68:	4194                	lw	a3,0(a1)
ffffffffc0202a6a:	96d6                	add	a3,a3,s5
ffffffffc0202a6c:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc0202a6e:	70e6                	ld	ra,120(sp)
ffffffffc0202a70:	7446                	ld	s0,112(sp)
ffffffffc0202a72:	74a6                	ld	s1,104(sp)
ffffffffc0202a74:	7906                	ld	s2,96(sp)
ffffffffc0202a76:	69e6                	ld	s3,88(sp)
ffffffffc0202a78:	6a46                	ld	s4,80(sp)
ffffffffc0202a7a:	6aa6                	ld	s5,72(sp)
ffffffffc0202a7c:	6b06                	ld	s6,64(sp)
ffffffffc0202a7e:	7be2                	ld	s7,56(sp)
ffffffffc0202a80:	7c42                	ld	s8,48(sp)
ffffffffc0202a82:	7ca2                	ld	s9,40(sp)
ffffffffc0202a84:	7d02                	ld	s10,32(sp)
ffffffffc0202a86:	6de2                	ld	s11,24(sp)
ffffffffc0202a88:	6109                	addi	sp,sp,128
ffffffffc0202a8a:	8082                	ret
            padc = '0';
ffffffffc0202a8c:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc0202a8e:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202a92:	846a                	mv	s0,s10
ffffffffc0202a94:	00140d13          	addi	s10,s0,1
ffffffffc0202a98:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0202a9c:	0ff5f593          	andi	a1,a1,255
ffffffffc0202aa0:	fcb572e3          	bgeu	a0,a1,ffffffffc0202a64 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc0202aa4:	85a6                	mv	a1,s1
ffffffffc0202aa6:	02500513          	li	a0,37
ffffffffc0202aaa:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc0202aac:	fff44783          	lbu	a5,-1(s0)
ffffffffc0202ab0:	8d22                	mv	s10,s0
ffffffffc0202ab2:	f73788e3          	beq	a5,s3,ffffffffc0202a22 <vprintfmt+0x3a>
ffffffffc0202ab6:	ffed4783          	lbu	a5,-2(s10)
ffffffffc0202aba:	1d7d                	addi	s10,s10,-1
ffffffffc0202abc:	ff379de3          	bne	a5,s3,ffffffffc0202ab6 <vprintfmt+0xce>
ffffffffc0202ac0:	b78d                	j	ffffffffc0202a22 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0202ac2:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc0202ac6:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202aca:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0202acc:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0202ad0:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0202ad4:	02d86463          	bltu	a6,a3,ffffffffc0202afc <vprintfmt+0x114>
                ch = *fmt;
ffffffffc0202ad8:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0202adc:	002c169b          	slliw	a3,s8,0x2
ffffffffc0202ae0:	0186873b          	addw	a4,a3,s8
ffffffffc0202ae4:	0017171b          	slliw	a4,a4,0x1
ffffffffc0202ae8:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0202aea:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0202aee:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0202af0:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc0202af4:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0202af8:	fed870e3          	bgeu	a6,a3,ffffffffc0202ad8 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0202afc:	f40ddce3          	bgez	s11,ffffffffc0202a54 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0202b00:	8de2                	mv	s11,s8
ffffffffc0202b02:	5c7d                	li	s8,-1
ffffffffc0202b04:	bf81                	j	ffffffffc0202a54 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0202b06:	fffdc693          	not	a3,s11
ffffffffc0202b0a:	96fd                	srai	a3,a3,0x3f
ffffffffc0202b0c:	00ddfdb3          	and	s11,s11,a3
ffffffffc0202b10:	00144603          	lbu	a2,1(s0)
ffffffffc0202b14:	2d81                	sext.w	s11,s11
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202b16:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0202b18:	bf35                	j	ffffffffc0202a54 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0202b1a:	000a2c03          	lw	s8,0(s4)
            goto process_precision;
ffffffffc0202b1e:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0202b22:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202b24:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0202b26:	bfd9                	j	ffffffffc0202afc <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0202b28:	4705                	li	a4,1
ffffffffc0202b2a:	008a0593          	addi	a1,s4,8
ffffffffc0202b2e:	01174463          	blt	a4,a7,ffffffffc0202b36 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc0202b32:	1a088e63          	beqz	a7,ffffffffc0202cee <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0202b36:	000a3603          	ld	a2,0(s4)
ffffffffc0202b3a:	46c1                	li	a3,16
ffffffffc0202b3c:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc0202b3e:	2781                	sext.w	a5,a5
ffffffffc0202b40:	876e                	mv	a4,s11
ffffffffc0202b42:	85a6                	mv	a1,s1
ffffffffc0202b44:	854a                	mv	a0,s2
ffffffffc0202b46:	e37ff0ef          	jal	ra,ffffffffc020297c <printnum>
            break;
ffffffffc0202b4a:	bde1                	j	ffffffffc0202a22 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc0202b4c:	000a2503          	lw	a0,0(s4)
ffffffffc0202b50:	85a6                	mv	a1,s1
ffffffffc0202b52:	0a21                	addi	s4,s4,8
ffffffffc0202b54:	9902                	jalr	s2
            break;
ffffffffc0202b56:	b5f1                	j	ffffffffc0202a22 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0202b58:	4705                	li	a4,1
ffffffffc0202b5a:	008a0593          	addi	a1,s4,8
ffffffffc0202b5e:	01174463          	blt	a4,a7,ffffffffc0202b66 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0202b62:	18088163          	beqz	a7,ffffffffc0202ce4 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0202b66:	000a3603          	ld	a2,0(s4)
ffffffffc0202b6a:	46a9                	li	a3,10
ffffffffc0202b6c:	8a2e                	mv	s4,a1
ffffffffc0202b6e:	bfc1                	j	ffffffffc0202b3e <vprintfmt+0x156>
            goto reswitch;
ffffffffc0202b70:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0202b74:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202b76:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0202b78:	bdf1                	j	ffffffffc0202a54 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc0202b7a:	85a6                	mv	a1,s1
ffffffffc0202b7c:	02500513          	li	a0,37
ffffffffc0202b80:	9902                	jalr	s2
            break;
ffffffffc0202b82:	b545                	j	ffffffffc0202a22 <vprintfmt+0x3a>
            lflag ++;
ffffffffc0202b84:	00144603          	lbu	a2,1(s0)
ffffffffc0202b88:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202b8a:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0202b8c:	b5e1                	j	ffffffffc0202a54 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc0202b8e:	4705                	li	a4,1
ffffffffc0202b90:	008a0593          	addi	a1,s4,8
ffffffffc0202b94:	01174463          	blt	a4,a7,ffffffffc0202b9c <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc0202b98:	14088163          	beqz	a7,ffffffffc0202cda <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc0202b9c:	000a3603          	ld	a2,0(s4)
ffffffffc0202ba0:	46a1                	li	a3,8
ffffffffc0202ba2:	8a2e                	mv	s4,a1
ffffffffc0202ba4:	bf69                	j	ffffffffc0202b3e <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc0202ba6:	03000513          	li	a0,48
ffffffffc0202baa:	85a6                	mv	a1,s1
ffffffffc0202bac:	e03e                	sd	a5,0(sp)
ffffffffc0202bae:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0202bb0:	85a6                	mv	a1,s1
ffffffffc0202bb2:	07800513          	li	a0,120
ffffffffc0202bb6:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0202bb8:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc0202bba:	6782                	ld	a5,0(sp)
ffffffffc0202bbc:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0202bbe:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc0202bc2:	bfb5                	j	ffffffffc0202b3e <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0202bc4:	000a3403          	ld	s0,0(s4)
ffffffffc0202bc8:	008a0713          	addi	a4,s4,8
ffffffffc0202bcc:	e03a                	sd	a4,0(sp)
ffffffffc0202bce:	14040263          	beqz	s0,ffffffffc0202d12 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc0202bd2:	0fb05763          	blez	s11,ffffffffc0202cc0 <vprintfmt+0x2d8>
ffffffffc0202bd6:	02d00693          	li	a3,45
ffffffffc0202bda:	0cd79163          	bne	a5,a3,ffffffffc0202c9c <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0202bde:	00044783          	lbu	a5,0(s0)
ffffffffc0202be2:	0007851b          	sext.w	a0,a5
ffffffffc0202be6:	cf85                	beqz	a5,ffffffffc0202c1e <vprintfmt+0x236>
ffffffffc0202be8:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0202bec:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0202bf0:	000c4563          	bltz	s8,ffffffffc0202bfa <vprintfmt+0x212>
ffffffffc0202bf4:	3c7d                	addiw	s8,s8,-1
ffffffffc0202bf6:	036c0263          	beq	s8,s6,ffffffffc0202c1a <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0202bfa:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0202bfc:	0e0c8e63          	beqz	s9,ffffffffc0202cf8 <vprintfmt+0x310>
ffffffffc0202c00:	3781                	addiw	a5,a5,-32
ffffffffc0202c02:	0ef47b63          	bgeu	s0,a5,ffffffffc0202cf8 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0202c06:	03f00513          	li	a0,63
ffffffffc0202c0a:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0202c0c:	000a4783          	lbu	a5,0(s4)
ffffffffc0202c10:	3dfd                	addiw	s11,s11,-1
ffffffffc0202c12:	0a05                	addi	s4,s4,1
ffffffffc0202c14:	0007851b          	sext.w	a0,a5
ffffffffc0202c18:	ffe1                	bnez	a5,ffffffffc0202bf0 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0202c1a:	01b05963          	blez	s11,ffffffffc0202c2c <vprintfmt+0x244>
ffffffffc0202c1e:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0202c20:	85a6                	mv	a1,s1
ffffffffc0202c22:	02000513          	li	a0,32
ffffffffc0202c26:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0202c28:	fe0d9be3          	bnez	s11,ffffffffc0202c1e <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0202c2c:	6a02                	ld	s4,0(sp)
ffffffffc0202c2e:	bbd5                	j	ffffffffc0202a22 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0202c30:	4705                	li	a4,1
ffffffffc0202c32:	008a0c93          	addi	s9,s4,8
ffffffffc0202c36:	01174463          	blt	a4,a7,ffffffffc0202c3e <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0202c3a:	08088d63          	beqz	a7,ffffffffc0202cd4 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc0202c3e:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0202c42:	0a044d63          	bltz	s0,ffffffffc0202cfc <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0202c46:	8622                	mv	a2,s0
ffffffffc0202c48:	8a66                	mv	s4,s9
ffffffffc0202c4a:	46a9                	li	a3,10
ffffffffc0202c4c:	bdcd                	j	ffffffffc0202b3e <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc0202c4e:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0202c52:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0202c54:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0202c56:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0202c5a:	8fb5                	xor	a5,a5,a3
ffffffffc0202c5c:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0202c60:	02d74163          	blt	a4,a3,ffffffffc0202c82 <vprintfmt+0x29a>
ffffffffc0202c64:	00369793          	slli	a5,a3,0x3
ffffffffc0202c68:	97de                	add	a5,a5,s7
ffffffffc0202c6a:	639c                	ld	a5,0(a5)
ffffffffc0202c6c:	cb99                	beqz	a5,ffffffffc0202c82 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc0202c6e:	86be                	mv	a3,a5
ffffffffc0202c70:	00001617          	auipc	a2,0x1
ffffffffc0202c74:	44860613          	addi	a2,a2,1096 # ffffffffc02040b8 <sizes.1225+0x140>
ffffffffc0202c78:	85a6                	mv	a1,s1
ffffffffc0202c7a:	854a                	mv	a0,s2
ffffffffc0202c7c:	0ce000ef          	jal	ra,ffffffffc0202d4a <printfmt>
ffffffffc0202c80:	b34d                	j	ffffffffc0202a22 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0202c82:	00001617          	auipc	a2,0x1
ffffffffc0202c86:	42660613          	addi	a2,a2,1062 # ffffffffc02040a8 <sizes.1225+0x130>
ffffffffc0202c8a:	85a6                	mv	a1,s1
ffffffffc0202c8c:	854a                	mv	a0,s2
ffffffffc0202c8e:	0bc000ef          	jal	ra,ffffffffc0202d4a <printfmt>
ffffffffc0202c92:	bb41                	j	ffffffffc0202a22 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0202c94:	00001417          	auipc	s0,0x1
ffffffffc0202c98:	40c40413          	addi	s0,s0,1036 # ffffffffc02040a0 <sizes.1225+0x128>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0202c9c:	85e2                	mv	a1,s8
ffffffffc0202c9e:	8522                	mv	a0,s0
ffffffffc0202ca0:	e43e                	sd	a5,8(sp)
ffffffffc0202ca2:	c69ff0ef          	jal	ra,ffffffffc020290a <strnlen>
ffffffffc0202ca6:	40ad8dbb          	subw	s11,s11,a0
ffffffffc0202caa:	01b05b63          	blez	s11,ffffffffc0202cc0 <vprintfmt+0x2d8>
ffffffffc0202cae:	67a2                	ld	a5,8(sp)
ffffffffc0202cb0:	00078a1b          	sext.w	s4,a5
ffffffffc0202cb4:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc0202cb6:	85a6                	mv	a1,s1
ffffffffc0202cb8:	8552                	mv	a0,s4
ffffffffc0202cba:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0202cbc:	fe0d9ce3          	bnez	s11,ffffffffc0202cb4 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0202cc0:	00044783          	lbu	a5,0(s0)
ffffffffc0202cc4:	00140a13          	addi	s4,s0,1
ffffffffc0202cc8:	0007851b          	sext.w	a0,a5
ffffffffc0202ccc:	d3a5                	beqz	a5,ffffffffc0202c2c <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0202cce:	05e00413          	li	s0,94
ffffffffc0202cd2:	bf39                	j	ffffffffc0202bf0 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc0202cd4:	000a2403          	lw	s0,0(s4)
ffffffffc0202cd8:	b7ad                	j	ffffffffc0202c42 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc0202cda:	000a6603          	lwu	a2,0(s4)
ffffffffc0202cde:	46a1                	li	a3,8
ffffffffc0202ce0:	8a2e                	mv	s4,a1
ffffffffc0202ce2:	bdb1                	j	ffffffffc0202b3e <vprintfmt+0x156>
ffffffffc0202ce4:	000a6603          	lwu	a2,0(s4)
ffffffffc0202ce8:	46a9                	li	a3,10
ffffffffc0202cea:	8a2e                	mv	s4,a1
ffffffffc0202cec:	bd89                	j	ffffffffc0202b3e <vprintfmt+0x156>
ffffffffc0202cee:	000a6603          	lwu	a2,0(s4)
ffffffffc0202cf2:	46c1                	li	a3,16
ffffffffc0202cf4:	8a2e                	mv	s4,a1
ffffffffc0202cf6:	b5a1                	j	ffffffffc0202b3e <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc0202cf8:	9902                	jalr	s2
ffffffffc0202cfa:	bf09                	j	ffffffffc0202c0c <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc0202cfc:	85a6                	mv	a1,s1
ffffffffc0202cfe:	02d00513          	li	a0,45
ffffffffc0202d02:	e03e                	sd	a5,0(sp)
ffffffffc0202d04:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0202d06:	6782                	ld	a5,0(sp)
ffffffffc0202d08:	8a66                	mv	s4,s9
ffffffffc0202d0a:	40800633          	neg	a2,s0
ffffffffc0202d0e:	46a9                	li	a3,10
ffffffffc0202d10:	b53d                	j	ffffffffc0202b3e <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0202d12:	03b05163          	blez	s11,ffffffffc0202d34 <vprintfmt+0x34c>
ffffffffc0202d16:	02d00693          	li	a3,45
ffffffffc0202d1a:	f6d79de3          	bne	a5,a3,ffffffffc0202c94 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc0202d1e:	00001417          	auipc	s0,0x1
ffffffffc0202d22:	38240413          	addi	s0,s0,898 # ffffffffc02040a0 <sizes.1225+0x128>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0202d26:	02800793          	li	a5,40
ffffffffc0202d2a:	02800513          	li	a0,40
ffffffffc0202d2e:	00140a13          	addi	s4,s0,1
ffffffffc0202d32:	bd6d                	j	ffffffffc0202bec <vprintfmt+0x204>
ffffffffc0202d34:	00001a17          	auipc	s4,0x1
ffffffffc0202d38:	36da0a13          	addi	s4,s4,877 # ffffffffc02040a1 <sizes.1225+0x129>
ffffffffc0202d3c:	02800513          	li	a0,40
ffffffffc0202d40:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0202d44:	05e00413          	li	s0,94
ffffffffc0202d48:	b565                	j	ffffffffc0202bf0 <vprintfmt+0x208>

ffffffffc0202d4a <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0202d4a:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc0202d4c:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0202d50:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0202d52:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0202d54:	ec06                	sd	ra,24(sp)
ffffffffc0202d56:	f83a                	sd	a4,48(sp)
ffffffffc0202d58:	fc3e                	sd	a5,56(sp)
ffffffffc0202d5a:	e0c2                	sd	a6,64(sp)
ffffffffc0202d5c:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc0202d5e:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0202d60:	c89ff0ef          	jal	ra,ffffffffc02029e8 <vprintfmt>
}
ffffffffc0202d64:	60e2                	ld	ra,24(sp)
ffffffffc0202d66:	6161                	addi	sp,sp,80
ffffffffc0202d68:	8082                	ret

ffffffffc0202d6a <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc0202d6a:	4781                	li	a5,0
ffffffffc0202d6c:	00005717          	auipc	a4,0x5
ffffffffc0202d70:	2a473703          	ld	a4,676(a4) # ffffffffc0208010 <SBI_CONSOLE_PUTCHAR>
ffffffffc0202d74:	88ba                	mv	a7,a4
ffffffffc0202d76:	852a                	mv	a0,a0
ffffffffc0202d78:	85be                	mv	a1,a5
ffffffffc0202d7a:	863e                	mv	a2,a5
ffffffffc0202d7c:	00000073          	ecall
ffffffffc0202d80:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0202d82:	8082                	ret
