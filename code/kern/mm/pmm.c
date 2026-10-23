#include <default_pmm.h>
#include <best_fit_pmm.h>
#include <bs_pmm.h>
#include <slub.h>
#include <defs.h>
#include <error.h>
#include <memlayout.h>
#include <mmu.h>
#include <pmm.h>
#include <sbi.h>
#include <stdio.h>
#include <string.h>
#include <riscv.h>
#include <dtb.h>

// virtual address of physical page array
struct Page *pages;
// amount of physical memory (in pages)
size_t npage = 0;
// the kernel image is mapped at VA=KERNBASE and PA=info.base
uint64_t va_pa_offset;
// memory starts at 0x80000000 in RISC-V
// DRAM_BASE defined in riscv.h as 0x80000000
const size_t nbase = DRAM_BASE / PGSIZE;

// virtual address of boot-time page directory
uintptr_t *satp_virtual = NULL;
// physical address of boot-time page directory
uintptr_t satp_physical;

// physical memory management
const struct pmm_manager *pmm_manager;


static void check_alloc_page(void);

// init_pmm_manager - initialize a pmm_manager instance
static void init_pmm_manager(void) {
#ifdef LAB2_GRADE
    pmm_manager = &best_fit_pmm_manager;
#else
    pmm_manager = &bs_pmm_manager;
#endif
    cprintf("memory management: %s\n", pmm_manager->name);
    pmm_manager->init();
}

// init_memmap - call pmm->init_memmap to build Page struct for free memory
static void init_memmap(struct Page *base, size_t n) {
    pmm_manager->init_memmap(base, n);
}

// alloc_pages - allocate a continuous n*PAGESIZE memory block.
// Page allocation goes through SLUB first: requests larger than 2048 bytes
// (every whole-page request, since PGSIZE is 4096) are forwarded by SLUB to
// the current pmm manager unchanged; smaller byte-sized requests can be
// served by slub_alloc() directly.
struct Page *alloc_pages(size_t n) {
    if (n > (size_t)-1 / PGSIZE) {
        return NULL;
    }

    void *ptr = slub_alloc(n * PGSIZE);
    if (ptr == NULL) {
        return NULL;
    }
    return pa2page((uintptr_t)ptr - va_pa_offset);
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
}

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void) {
    return pmm_manager->nr_free_pages();
}

//lab2 function1 2413633

/* page_init - detect physical memory and build the page descriptor array */
static void page_init(void) {
    // 设备树探测到的物理内存范围
    uint64_t mem_base = get_memory_base();
    uint64_t mem_size = get_memory_size();

    // 设备树信息无效：报错并终止初始化，不再继续建立空闲页
    if (mem_base != DRAM_BASE || mem_size == 0 ||
        mem_size > ~(uint64_t)0 - mem_base) {
        panic("page_init: invalid memory info from DTB (base=0x%lx, size=0x%lx)",
              mem_base, mem_size);
    }

    // 虚地址到物理地址的偏移量：vaddr = paddr + va_pa_offset
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;

    // 可管理的物理内存上界取设备树结果与框架上界的较小值
    uint64_t mem_end = mem_base + mem_size;
    if (mem_end > PHYSICAL_MEMORY_END) {
        mem_end = PHYSICAL_MEMORY_END;
    }
    if (PPN(mem_end) <= nbase) {
        panic("page_init: invalid memory end 0x%lx", mem_end);
    }

    // npage 是物理页号的上界，描述符数组需要覆盖 [nbase, npage)
    npage = PPN(mem_end);

    // Page 描述符数组紧接在内核镜像之后，并按页对齐
    extern char end[];
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);

    // 先全部置为 reserved，防止尚未完成布局的页被分配
    size_t nr_pages = npage - nbase;
    uintptr_t pages_pa = PADDR(pages);
    uintptr_t managed_end = ROUNDDOWN(mem_end, PGSIZE);
    if (pages_pa >= managed_end ||
        nr_pages > (managed_end - pages_pa) / sizeof(*pages)) {
        panic("page_init: not enough memory for Page descriptors");
    }
    for (size_t i = 0; i < nr_pages; i++) {
        pages[i].ref = 0;
        pages[i].flags = 0;
        pages[i].property = 0;
        SetPageReserved(&pages[i]);
    }

    cprintf("Physical memory: [0x%016lx, 0x%016lx), npage = 0x%lx\n",
            mem_base, mem_end, npage);

    // 描述符数组之后的第一个完整页作为空闲区起点
    uintptr_t free_start_pa =
        PADDR(ROUNDUP((uintptr_t)(pages + nr_pages), PGSIZE));
    // 内存末端向下按页对齐，末尾不足一页的部分不交给分配器
    uintptr_t free_end_pa = ROUNDDOWN(mem_end, PGSIZE);

    // 剩余部分无法构成完整页时，不调用 init_memmap
    if (free_start_pa >= free_end_pa) {
        cprintf("page_init: no complete free page available\n");
        return;
    }

    // 把完整空闲页交给当前物理内存管理器
    init_memmap(pa2page(free_start_pa), (free_end_pa - free_start_pa) / PGSIZE);
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
    // We need to alloc/free the physical memory (granularity is 4KB or other size).
    // So a framework of physical memory manager (struct pmm_manager)is defined in pmm.h
    // First we should init a physical memory manager(pmm) based on the framework.
    // Then pmm can alloc/free the physical memory.
    // Now the first_fit/best_fit/worst_fit/buddy_system pmm are available.
    init_pmm_manager();

    // Initialize the SLUB object caches; page allocation is dispatched
    // through SLUB from now on.
    slub_init();

    // detect physical memory space, reserve already used memory,
    // then use pmm->init_memmap to create free page list
    page_init();

    // use pmm->check to verify the correctness of the alloc/free function in a pmm
    check_alloc_page();

    extern char boot_page_table_sv39[];
    satp_virtual = (pte_t*)boot_page_table_sv39;
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
    cprintf("check_alloc_page() succeeded!\n");
}
