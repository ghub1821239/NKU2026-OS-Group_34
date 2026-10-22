#include <defs.h>
#include <stdio.h>
#include <pmm.h>
#include <memlayout.h>
#include <bs_pmm.h>
#include <bs_test_lab2.h>

// 2 的幂次请求应按对应阶数分配：8 页 -> k=3，返回块按 8 页对齐
static void
test_buddy_pow2(void) {
    size_t before = nr_free_pages();

    struct Page *p = alloc_pages(8);
    assert(p != NULL);
    assert((page2ppn(p) & 7) == 0);
    assert(nr_free_pages() == before - 8);

    free_pages(p, 8);
    assert(nr_free_pages() == before);

    cprintf("[Buddy Test] power-of-two allocation (8 pages -> k=3): PASS\n");
}

// 非 2 的幂次请求向上取整到 2^k：7 页应占用一个 8 页块
static void
test_buddy_non_pow2(void) {
    size_t before = nr_free_pages();

    struct Page *p = alloc_pages(7);
    assert(p != NULL);
    assert((page2ppn(p) & 7) == 0);
    assert(nr_free_pages() == before - 8);

    free_pages(p, 7);
    assert(nr_free_pages() == before);

    cprintf("[Buddy Test] non-power-of-two allocation (7 pages -> 8 pages): PASS\n");
}

// 7 页空闲区应被拆成 4 + 2 + 1，即 k=2、k=1、k=0 三个块
static void
test_buddy_decompose_seven(void) {
    size_t before = nr_free_pages();

    // 先取得一个按 8 页对齐的块，再把前 7 页模拟成一个待管理的空闲区
    struct Page *p = alloc_pages(8);
    assert(p != NULL);
    assert((page2ppn(p) & 7) == 0);

    for (int i = 0; i < 7; i ++) {
        SetPageReserved(p + i);
    }
    pmm_manager->init_memmap(p, 7);
    assert(nr_free_pages() == before - 8 + 7);

    // 贪心划分后应得到 p(4 页) + p+4(2 页) + p+6(1 页)
    struct Page *k2 = alloc_pages(4);
    struct Page *k1 = alloc_pages(2);
    struct Page *k0 = alloc_page();
    assert(k2 == p);
    assert(k1 == p + 4);
    assert(k0 == p + 6);
    assert((page2ppn(k2) & 3) == 0);
    assert((page2ppn(k1) & 1) == 0);

    free_page(k0);
    free_pages(k1, 2);
    free_pages(k2, 4);
    assert(nr_free_pages() == before - 8 + 7);

    // 重新取回 4 + 2 + 1 三个块，再整体释放 8 页，恢复测试前状态
    assert(alloc_pages(4) == p);
    assert(alloc_pages(2) == p + 4);
    assert(alloc_page() == p + 6);
    free_pages(p, 8);
    assert(nr_free_pages() == before);

    cprintf("[Buddy Test] 7-page decomposition (4 + 2 + 1): PASS\n");
}

// 释放时与相邻同大小空闲块合并：两个 k=3 块应合并成 k=4 块
static void
test_buddy_merge(void) {
    size_t before = nr_free_pages();

    struct Page *p = alloc_pages(16);
    assert(p != NULL);
    assert((page2ppn(p) & 15) == 0);
    assert(nr_free_pages() == before - 16);

    free_pages(p, 8);
    free_pages(p + 8, 8);
    assert(nr_free_pages() == before);

    // 只有两个 k=3 块合并成一个 k=4 块后，才能再次按 16 页分配并返回 p
    assert(alloc_pages(16) == p);
    free_pages(p, 16);
    assert(nr_free_pages() == before);

    cprintf("[Buddy Test] adjacent free block merge (k=3 + k=3 -> k=4): PASS\n");
}

// 申请页数超过当前空闲页总数时应失败，且不改变空闲页数量
static void
test_buddy_oversize(void) {
    size_t before = nr_free_pages();

    assert(alloc_pages(before + 1) == NULL);
    assert(nr_free_pages() == before);

    cprintf("[Buddy Test] oversize request returns NULL: PASS\n");
}

void
test_buddy_system(void) {
    // 当前物理内存管理器必须是 Buddy System
    if (pmm_manager != &bs_pmm_manager) {
        panic("test_buddy_system: current pmm_manager is %s, not bs_pmm_manager",
              pmm_manager->name);
    }
    cprintf("[Buddy Test] current algorithm is bs_pmm_manager: PASS\n");

    test_buddy_pow2();
    test_buddy_non_pow2();
    test_buddy_decompose_seven();
    test_buddy_merge();
    test_buddy_oversize();

    cprintf("[Buddy Test] ALL PASS\n");
}

// 单独运行异常路径，避免 panic 影响正常测试：
// mode 0: alloc_pages(0) 应触发 panic
// mode 1: 超过空闲页总数的申请应返回 NULL
void
test_buddy_system_panic(int mode) {
    if (mode == 0) {
        cprintf("[Buddy Test] alloc_pages(0): expecting panic\n");
        alloc_pages(0);
    } else if (mode == 1) {
        size_t before = nr_free_pages();
        cprintf("[Buddy Test] oversize allocation: expecting NULL\n");
        assert(alloc_pages(before + 1) == NULL);
        assert(alloc_pages((size_t)-1) == NULL);
        assert(nr_free_pages() == before);
        cprintf("[Buddy Test] oversize allocation: PASS (returned NULL, no panic)\n");
    } else {
        panic("test_buddy_system_panic: unknown mode %d", mode);
    }
}
