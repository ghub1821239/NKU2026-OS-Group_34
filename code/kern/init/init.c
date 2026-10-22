#include <console.h>
#include <defs.h>
#include <pmm.h>
#include <stdio.h>
#include <string.h>
#include <dtb.h>

#ifdef ucore_test
#include <bs_test_lab2.h>
#include <slub_test_lab2.h>
#endif

int kern_init(void) __attribute__((noreturn));
void grade_backtrace(void);
void print_kerninfo(void);

/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
    cprintf("  etext  0x%016lx (virtual)\n", etext);
    cprintf("  edata  0x%016lx (virtual)\n", edata);
    cprintf("  end    0x%016lx (virtual)\n", end);
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
}

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
    // 检查 boot_dtb 是否非空且正确
    // 把物理内存的起点和大小取出来，存进全局变量 memory_base 和 memory_size 里
    // 方便通过 get_memory_base & get_memory_size 访问
    dtb_init();
    // OpenSBI 在跳转到我们的 entry.S 之前，早就把串口控制台（Console / UART）的硬件初始化好了。
    // 原因是因为在 x86 中没有 openSBI 这种固件，就需要自己在 cons_init() 里写一堆初始化显卡和串口的代码。
    cons_init();  // init the console
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);

    print_kerninfo();

    // grade_backtrace();
    pmm_init();  // init physical memory management

    #ifdef ucore_test
        test_buddy_system();
        slub_check();
    #endif

    /* do nothing */
    while (1)
        ;
}

