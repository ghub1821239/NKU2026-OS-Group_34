/* Exercise the real allocator with an independent bitmap model. */
#include <pmm.h>
#include "../kern/mm/best_fit_pmm.c"

extern int printf(const char *, ...);
extern void exit(int) __attribute__((noreturn));

#define TEST_PAGES 256
static struct Page descriptors[TEST_PAGES];
struct Page *pages = descriptors;
size_t npage = DRAM_BASE / PGSIZE + TEST_PAGES;
const size_t nbase = DRAM_BASE / PGSIZE;
uint64_t va_pa_offset;
const struct pmm_manager *pmm_manager = &best_fit_pmm_manager;

void __panic(const char *file, int line, const char *fmt, ...) {
    printf("FAIL: %s:%d: %s\n", file, line, fmt);
    exit(1);
}

int cprintf(const char *fmt, ...) { return 0; }
struct Page *alloc_pages(size_t n) { return pmm_manager->alloc_pages(n); }
void free_pages(struct Page *p, size_t n) { pmm_manager->free_pages(p, n); }
size_t nr_free_pages(void) { return pmm_manager->nr_free_pages(); }

static void reset(void) {
    pmm_manager->init();
    for (size_t i = 0; i < TEST_PAGES; i++) {
        descriptors[i].flags = 1UL << PG_reserved;
        descriptors[i].property = descriptors[i].ref = 0;
        list_init(&descriptors[i].page_link);
    }
    pmm_manager->init_memmap(pages, TEST_PAGES);
}

static unsigned int seed = 2411557;
static unsigned int random_number(void) {
    seed = seed * 1664525U + 1013904223U;
    return seed;
}

static void check_list(const unsigned char *used) {
    size_t total = 0;
    struct Page *previous = NULL;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p) && p->property > 0);
        assert(previous == NULL || previous + previous->property < p);
        for (size_t i = 0; i < p->property; i++) {
            assert(!used[p - pages + i]);
            assert(!PageReserved(p + i));
        }
        total += p->property;
        previous = p;
    }
    size_t expected = 0;
    for (size_t i = 0; i < TEST_PAGES; i++) expected += !used[i];
    assert(total == expected && total == nr_free_pages());
}

int main(void) {
    reset();
    pmm_manager->check();
    printf("Original best_fit_check: PASS\n");

    reset();
    unsigned char used[TEST_PAGES] = {0};
    size_t starts[TEST_PAGES], lengths[TEST_PAGES], active = 0;
    for (size_t step = 0; step < 20000; step++) {
        if (active != 0 && random_number() % 3 == 0) {
            size_t slot = random_number() % active;
            size_t begin = starts[slot], count = lengths[slot];
            free_pages(pages + begin, count);
            for (size_t i = begin; i < begin + count; i++) used[i] = 0;
            active--;
            starts[slot] = starts[active];
            lengths[slot] = lengths[active];
        } else {
            size_t count = 1 + random_number() % 20;
            size_t best = TEST_PAGES, best_length = TEST_PAGES + 1;
            for (size_t i = 0; i < TEST_PAGES;) {
                if (used[i]) { i++; continue; }
                size_t begin = i;
                while (i < TEST_PAGES && !used[i]) i++;
                if (i - begin >= count && i - begin < best_length) {
                    best = begin;
                    best_length = i - begin;
                }
            }
            struct Page *p = alloc_pages(count);
            assert(p == (best == TEST_PAGES ? NULL : pages + best));
            if (p != NULL) {
                starts[active] = best;
                lengths[active++] = count;
                for (size_t i = best; i < best + count; i++) used[i] = 1;
            }
        }
        check_list(used);
    }
    while (active != 0) {
        active--;
        free_pages(pages + starts[active], lengths[active]);
    }
    assert(nr_free_pages() == TEST_PAGES);
    assert(list_next(&free_list) == list_prev(&free_list));
    assert(le2page(list_next(&free_list), page_link) == pages);
    assert(pages->property == TEST_PAGES);
    printf("20000 bitmap-model operations and complete coalescing: PASS\n");
    return 0;
}
