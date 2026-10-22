#include <pmm.h>
#include <list.h>
#include <string.h>
#include <bs_pmm.h>
#include <stdio.h>

// 伙伴系统最多管理 2^BS_MAX_ORDER 个物理页的空闲块
#define BS_MAX_ORDER 32

// free_area[k] 管理大小为 2^k 页的空闲块，nr_free 记录该级空闲页总数
static free_area_t free_area[BS_MAX_ORDER];

// 返回不小于 n 的最小 2 的幂次对应的阶数
static size_t
bs_order(size_t n) {
    size_t order = 0;
    while (order + 1 < BS_MAX_ORDER && (1UL << order) < n) {
        order ++;
    }
    return order;
}

static void
bs_init(void) {
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
        list_init(&(free_area[k].free_list));
        free_area[k].nr_free = 0;
    }
}

static void
bs_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);

    struct Page *p = base;
    for (; p != base + n; p ++) {
        assert(PageReserved(p));
        p->flags = p->property = 0;
        set_page_ref(p, 0);
    }

    // 贪心地把 [base, base + n) 划分成若干按大小对齐的 2^k 页块
    size_t ppn = page2ppn(base);
    size_t done = 0;
    while (done < n) {
        size_t avail = n - done;
        size_t order = 0;
        while (order + 1 < BS_MAX_ORDER
               && (1UL << (order + 1)) <= avail
               && (((ppn + done) & ((1UL << (order + 1)) - 1)) == 0)) {
            order ++;
        }

        struct Page *block = base + done;
        size_t size = 1UL << order;
        block->property = size;
        SetPageProperty(block);
        list_add(&(free_area[order].free_list), &(block->page_link));
        free_area[order].nr_free += size;

        done += size;
    }
}

static struct Page *
bs_alloc_pages(size_t n) {
    assert(n > 0);

    size_t order = bs_order(n);
    size_t k = order;

    // 找到能满足要求的最小空闲块
    while (k < BS_MAX_ORDER && list_empty(&(free_area[k].free_list))) {
        k ++;
    }
    if (k == BS_MAX_ORDER) {
        return NULL;
    }

    struct Page *page = le2page(list_next(&(free_area[k].free_list)), page_link);
    list_del(&(page->page_link));
    free_area[k].nr_free -= (1UL << k);
    ClearPageProperty(page);

    // 逐层分裂：低半块继续用于分配，高半块放回对应阶数的空闲链表
    while (k > order) {
        k --;
        struct Page *buddy = page + (1UL << k);
        buddy->property = (1UL << k);
        SetPageProperty(buddy);
        list_add(&(free_area[k].free_list), &(buddy->page_link));
        free_area[k].nr_free += (1UL << k);
    }

    page->property = (1UL << order);
    return page;
}

static void
bs_free_pages(struct Page *base, size_t n) {
    assert(n > 0);

    size_t order = bs_order(n);
    size_t size = 1UL << order;

    struct Page *p = base;
    for (; p != base + size; p ++) {
        assert(!PageReserved(p) && !PageProperty(p));
        p->flags = p->property = 0;
        set_page_ref(p, 0);
    }

    // 伙伴块必须按自身大小对齐
    assert((page2ppn(base) & (size - 1)) == 0);

    base->property = size;
    SetPageProperty(base);

    // 反复检查伙伴块：空闲且大小相同则合并成更高一阶的块
    while (order + 1 < BS_MAX_ORDER) {
        size_t buddy_ppn = page2ppn(base) ^ size;
        if (buddy_ppn < nbase || buddy_ppn >= npage) {
            break;
        }

        struct Page *buddy = pages + (buddy_ppn - nbase);
        if (!PageProperty(buddy) || buddy->property != size) {
            break;
        }

        list_del(&(buddy->page_link));
        free_area[order].nr_free -= size;

        struct Page *lo = base < buddy ? base : buddy;
        struct Page *hi = base < buddy ? buddy : base;
        ClearPageProperty(hi);
        hi->property = 0;
        lo->property = size << 1;
        SetPageProperty(lo);

        base = lo;
        order ++;
        size <<= 1;
    }

    list_add(&(free_area[order].free_list), &(base->page_link));
    free_area[order].nr_free += size;
}

static size_t
bs_nr_free_pages(void) {
    size_t total = 0;
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
        total += free_area[k].nr_free;
    }
    return total;
}

static void
bs_check(void) {
    size_t total = 0;
    size_t block_count[BS_MAX_ORDER];

    // 检查每级链表：块首页带有 PG_property，大小为 2^k 且按大小对齐
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
        list_entry_t *head = &(free_area[k].free_list);
        list_entry_t *le = head;
        size_t cnt = 0, pages = 0;
        while ((le = list_next(le)) != head) {
            struct Page *block = le2page(le, page_link);
            assert(PageProperty(block));
            assert(block->property == (1UL << k));
            assert((page2ppn(block) & ((1UL << k) - 1)) == 0);
            cnt ++;
            pages += (1UL << k);
        }
        assert(pages == free_area[k].nr_free);
        block_count[k] = cnt;
        total += pages;
    }
    assert(total > 0);
    assert(total == bs_nr_free_pages());

    // 分配 8、4、1 页并释放，检查页数统计与伙伴合并
    struct Page *p0 = alloc_pages(5);
    assert(p0 != NULL);
    assert(!PageProperty(p0));
    assert((page2ppn(p0) & 7) == 0);
    assert(bs_nr_free_pages() + 8 == total);

    struct Page *p1 = alloc_pages(3);
    struct Page *p2 = alloc_page();
    assert(p1 != NULL && p2 != NULL);
    assert(p0 != p1 && p0 != p2 && p1 != p2);
    assert(bs_nr_free_pages() + 13 == total);

    free_page(p2);
    free_pages(p1, 3);
    free_pages(p0, 5);
    assert(bs_nr_free_pages() == total);

    // 释放后应与分配前的分级块结构完全一致，说明伙伴块已正确合并
    for (size_t k = 0; k < BS_MAX_ORDER; k ++) {
        list_entry_t *head = &(free_area[k].free_list);
        list_entry_t *le = head;
        size_t cnt = 0;
        while ((le = list_next(le)) != head) {
            struct Page *block = le2page(le, page_link);
            assert(PageProperty(block));
            assert(block->property == (1UL << k));
            assert((page2ppn(block) & ((1UL << k) - 1)) == 0);
            cnt ++;
        }
        assert(cnt == block_count[k]);
        assert(free_area[k].nr_free == (cnt << k));
    }

    // 不同大小请求的往返分配/释放
    for (size_t n = 1; n <= 16; n ++) {
        struct Page *q = alloc_pages(n);
        assert(q != NULL);
        assert(!PageProperty(q));
        free_pages(q, n);
        assert(bs_nr_free_pages() == total);
    }

    // 多个单页块同时分配后再释放，检查相邻块回收
    struct Page *q[4];
    for (int i = 0; i < 4; i ++) {
        assert((q[i] = alloc_page()) != NULL);
    }
    assert(bs_nr_free_pages() + 4 == total);
    for (int i = 0; i < 4; i ++) {
        free_page(q[i]);
    }
    assert(bs_nr_free_pages() == total);
}

const struct pmm_manager bs_pmm_manager = {
    .name = "bs_pmm_manager",
    .init = bs_init,
    .init_memmap = bs_init_memmap,
    .alloc_pages = bs_alloc_pages,
    .free_pages = bs_free_pages,
    .nr_free_pages = bs_nr_free_pages,
    .check = bs_check,
};
