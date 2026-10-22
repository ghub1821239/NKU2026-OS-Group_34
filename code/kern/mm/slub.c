#include <assert.h>
#include <defs.h>
#include <list.h>
#include <memlayout.h>
#include <mmu.h>
#include <pmm.h>
#include <slub.h>

/*
 * A simple SLUB allocator for small objects.
 *
 * Objects whose size is not larger than SLUB_MAX_OBJ_SIZE are rounded up to
 * 8, 16, ..., 2048 bytes.  Every physical page used as a slab is split into
 * PGSIZE / object_size objects, and the free objects of that page are kept in
 * a singly linked list.  Allocation pops the head, freeing pushes onto the
 * head, so no list traversal is needed.
 *
 * Larger requests are forwarded to the page allocator unchanged.
 *
 * The per-slab bookkeeping lives in the page descriptor itself, so a 4 KiB
 * page can hold exactly PGSIZE / object_size objects:
 *   page->flags    : PG_slub marker + size class
 *   page->ref      : number of free objects in this slab
 *   page->property : index of the free-list head (valid when ref > 0)
 *   page->page_link: node in the cache's partial-slab list
 *
 * A large allocation records its page count in page->property so that
 * slub_free(ptr) can recover the size from the address alone.
 */

#define SLUB_MIN_OBJ_SIZE   8UL
#define SLUB_MAX_OBJ_SIZE   2048UL
#define SLUB_NR_CLASSES     9          /* 8, 16, 32, ..., 2048 */

/* Bits used in page->flags; PG_reserved / PG_property remain untouched. */
#define PG_slub             2
#define SLUB_CLASS_SHIFT    8
#define SLUB_CLASS_MASK     0xffUL

#define PageSlub(page)      (((page)->flags >> PG_slub) & 1)
#define SetPageSlub(page, k) \
    ((page)->flags = (1UL << PG_slub) | ((uint64_t)(k) << SLUB_CLASS_SHIFT))
#define ClearPageSlub(page) ((page)->flags = 0)
#define SlubClass(page)     (((page)->flags >> SLUB_CLASS_SHIFT) & SLUB_CLASS_MASK)

typedef struct {
    list_entry_t slabs;        /* slabs that still have free objects */
    size_t obj_size;
    size_t objs_per_slab;
} slub_cache_t;

static slub_cache_t slub_caches[SLUB_NR_CLASSES];

/* Kernel virtual address of the page described by @page. */
static inline void *
slub_page_kva(struct Page *page) {
    return (void *)(page2pa(page) + va_pa_offset);
}

/* Kernel virtual address -> page descriptor.  Do not use PADDR(): early
 * physical pages may live below KERNBASE even though they are mapped. */
static inline struct Page *
slub_kva_to_page(void *ptr) {
    return pa2page((uintptr_t)ptr - va_pa_offset);
}

/* Return the 2^k size class for @size, or -1 if it must use whole pages. */
static int
slub_class_of(size_t size) {
    size_t rounded = size < SLUB_MIN_OBJ_SIZE ? SLUB_MIN_OBJ_SIZE : size;
    if (rounded > SLUB_MAX_OBJ_SIZE) {
        return -1;
    }
    int k = 0;
    while ((SLUB_MIN_OBJ_SIZE << k) < rounded) {
        k ++;
    }
    return k;
}

/* Allocate one page and turn it into a slab of class @k. */
static struct Page *
slub_new_slab(int k) {
    slub_cache_t *cache = &slub_caches[k];
    struct Page *page = pmm_manager->alloc_pages(1);
    if (page == NULL) {
        return NULL;
    }

    SetPageSlub(page, k);
    page->ref = (int)cache->objs_per_slab;
    page->property = 0;

    char *base = (char *)slub_page_kva(page);
    for (size_t i = 0; i < cache->objs_per_slab; i ++) {
        void *obj = base + i * cache->obj_size;
        *(void **)obj = (i + 1 < cache->objs_per_slab)
                            ? (void *)(base + (i + 1) * cache->obj_size)
                            : NULL;
    }

    list_add(&(cache->slabs), &(page->page_link));
    return page;
}

/* Requests larger than SLUB_MAX_OBJ_SIZE use the page allocator directly. */
static void *
slub_alloc_large(size_t size) {
    if (size > (size_t)-1 - (PGSIZE - 1)) {
        return NULL;
    }

    size_t npages = ROUNDUP(size, PGSIZE) / PGSIZE;
    if (npages == 0 || npages > 0xffffffffUL) {
        return NULL;
    }

    struct Page *page = pmm_manager->alloc_pages(npages);
    if (page == NULL) {
        return NULL;
    }

    /* Remember the size so slub_free() can recover it from the address. */
    page->property = (unsigned int)npages;
    return slub_page_kva(page);
}

void
slub_init(void) {
    for (int k = 0; k < SLUB_NR_CLASSES; k ++) {
        list_init(&(slub_caches[k].slabs));
        slub_caches[k].obj_size = SLUB_MIN_OBJ_SIZE << k;
        slub_caches[k].objs_per_slab = PGSIZE / slub_caches[k].obj_size;
    }
}

void *
slub_alloc(size_t size) {
    assert(size > 0);

    int k = slub_class_of(size);
    if (k < 0) {
        return slub_alloc_large(size);
    }

    slub_cache_t *cache = &slub_caches[k];
    struct Page *page;

    if (list_empty(&(cache->slabs))) {
        page = slub_new_slab(k);
        if (page == NULL) {
            return NULL;
        }
    } else {
        page = le2page(list_next(&(cache->slabs)), page_link);
    }

    assert(PageSlub(page));
    assert(page->ref > 0);
    assert(page->property < cache->objs_per_slab);

    char *base = (char *)slub_page_kva(page);
    void *obj = base + (size_t)page->property * cache->obj_size;
    void *next = *(void **)obj;

    if (next == NULL) {
        page->property = 0;     /* meaningless once the slab becomes full */
    } else {
        assert((uintptr_t)next >= (uintptr_t)base
               && (uintptr_t)next < (uintptr_t)base + PGSIZE);
        page->property =
            (unsigned int)(((uintptr_t)next - (uintptr_t)base) / cache->obj_size);
    }

    page->ref --;
    if (page->ref == 0) {
        /* The slab is full: it has nothing to offer other allocations. */
        list_del(&(page->page_link));
    }
    return obj;
}

/* Return a small object to its slab, freeing the page when it becomes empty. */
static void
slub_free_small(void *ptr, struct Page *page) {
    unsigned int k = (unsigned int)SlubClass(page);
    assert(k < SLUB_NR_CLASSES);

    slub_cache_t *cache = &slub_caches[k];
    char *base = (char *)slub_page_kva(page);
    uintptr_t offset = (uintptr_t)ptr - (uintptr_t)base;

    assert(offset < PGSIZE);
    assert(cache->obj_size != 0 && offset % cache->obj_size == 0);
    assert(page->ref < (int)cache->objs_per_slab);  /* catch double free */

    size_t idx = offset / cache->obj_size;
    assert(idx < cache->objs_per_slab);

    bool was_full = (page->ref == 0);
    void *old_head = NULL;
    if (!was_full) {
        assert(page->property < cache->objs_per_slab);
        old_head = base + (size_t)page->property * cache->obj_size;
    }

    *(void **)ptr = old_head;       /* push onto this slab's free list */
    page->property = (unsigned int)idx;
    page->ref ++;

    if (was_full) {
        /* A full slab was not on the list; it can serve allocations again. */
        list_add(&(cache->slabs), &(page->page_link));
    }

    if (page->ref == (int)cache->objs_per_slab) {
        /* Every object of this page is free: give the whole page back. */
        list_del(&(page->page_link));
        ClearPageSlub(page);
        page->property = 0;
        page->ref = 0;
        pmm_manager->free_pages(page, 1);
    }
}

void
slub_free(void *ptr) {
    if (ptr == NULL) {
        return;
    }

    uintptr_t va = (uintptr_t)ptr;
    if (va < va_pa_offset) {
        panic("slub_free: invalid pointer 0x%lx", va);
    }

    struct Page *page = slub_kva_to_page(ptr);
    if (PageSlub(page)) {
        slub_free_small(ptr, page);
        return;
    }

    /* Large allocation: page->property records how many pages it owns. */
    size_t npages = page->property;
    if (npages == 0) {
        panic("slub_free: 0x%lx is not a valid slub allocation", va);
    }
    pmm_manager->free_pages(page, npages);
}
