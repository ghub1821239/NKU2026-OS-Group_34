#include <assert.h>
#include <defs.h>
#include <memlayout.h>
#include <mmu.h>
#include <pmm.h>
#include <slub.h>
#include <stdio.h>
#include <slub_test_lab2.h>

/*
 * SLUB allocator tests.
 *
 * slub_check() is meant to run while the SLUB caches are idle (the usual
 * boot-time call site).  Every test object is released before the end, so
 * the number of free physical pages must return to its starting value.
 *
 * slub_alloc(0) is rejected by an assertion in the allocator itself.  Calling
 * it here would terminate the kernel and hide the remaining results, so the
 * zero-size panic is exercised in a separate run; this routine covers
 * oversized requests and free(NULL).
 */

#define SLUB_TEST_MAX_OBJS 256

/* Size class used by the SLUB allocator for a small request. */
static size_t
test_small_class(size_t size) {
    size_t rounded = 8;
    while (rounded < size) {
        rounded <<= 1;
    }
    return rounded;
}

/* Write a deterministic, object-specific pattern over the usable bytes. */
static void
test_fill(void *ptr, size_t size, uint8_t seed) {
    volatile uint8_t *p = (volatile uint8_t *)ptr;
    for (size_t i = 0; i < size; i ++) {
        p[i] = (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8));
    }
}

static void
test_verify(const void *ptr, size_t size, uint8_t seed) {
    const volatile uint8_t *p = (const volatile uint8_t *)ptr;
    for (size_t i = 0; i < size; i ++) {
        assert(p[i] == (uint8_t)(seed + (uint8_t)i * 31 + (uint8_t)(i >> 8)));
    }
}

/* Usable size and required alignment for a request. */
static void
test_expect(size_t size, size_t *writable, size_t *alignment) {
    if (size <= 2048) {
        *writable = test_small_class(size);
        *alignment = *writable;
    } else {
        *writable = size;
        *alignment = PGSIZE;
    }
}

/* 1. Size-class boundaries, non power-of-two rounding, small and large. */
static void
test_boundaries(void) {
    static const size_t sizes[] = {
        1, 7, 8, 9, 15, 16, 17, 31, 32, 33,
        63, 64, 65, 70, 127, 128, 129,
        255, 256, 257, 511, 512, 513,
        1023, 1024, 1025, 2047, 2048, 2049,
        3000, 4096, 4097, 5000, 8192,
    };

    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i ++) {
        size_t size = sizes[i];
        size_t writable, alignment;
        test_expect(size, &writable, &alignment);

        void *p = slub_alloc(size);
        assert(p != NULL);
        assert(((uintptr_t)p & (alignment - 1)) == 0);

        test_fill(p, writable, (uint8_t)(i + 1));
        test_verify(p, writable, (uint8_t)(i + 1));

        slub_free(p);
    }

    cprintf("[SLUB Test] size boundaries and rounding: PASS\n");
}

/* 2. Many live objects of mixed sizes must not overwrite each other. */
static void
test_isolation(void) {
    static const size_t mix[] = {
        8, 16, 32, 64, 70, 128, 256, 512, 1024, 2048,
        2049, 4096, 4097, 5000,
    };
    void *objs[SLUB_TEST_MAX_OBJS];
    size_t sizes[SLUB_TEST_MAX_OBJS];
    size_t nmix = sizeof(mix) / sizeof(mix[0]);

    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
        size_t size = mix[i % nmix];
        size_t writable, alignment;
        test_expect(size, &writable, &alignment);

        objs[i] = slub_alloc(size);
        assert(objs[i] != NULL);
        assert(((uintptr_t)objs[i] & (alignment - 1)) == 0);
        sizes[i] = size;
    }

    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
        size_t writable, alignment;
        test_expect(sizes[i], &writable, &alignment);
        test_fill(objs[i], writable, (uint8_t)(i + 1));
    }

    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
        size_t writable, alignment;
        test_expect(sizes[i], &writable, &alignment);
        test_verify(objs[i], writable, (uint8_t)(i + 1));
    }

    /* Free in a permutation of 0..255 (gcd(37, 256) == 1). */
    for (size_t i = 0; i < SLUB_TEST_MAX_OBJS; i ++) {
        size_t j = (i * 37) % SLUB_TEST_MAX_OBJS;
        assert(objs[j] != NULL);
        slub_free(objs[j]);
        objs[j] = NULL;
    }

    cprintf("[SLUB Test] %d mixed live objects stay isolated: PASS\n",
            SLUB_TEST_MAX_OBJS);
}

/* 3. Whole-page reclaim and cross-page allocations. */
static void
test_page_reclaim(void) {
    size_t before = nr_free_pages();

    /* A 4 KiB page holds exactly 64 objects of 64 bytes; the page must only
     * be returned after the 64th object is freed. */
    void *objs64[64];
    for (int i = 0; i < 64; i ++) {
        objs64[i] = slub_alloc(64);
        assert(objs64[i] != NULL);
    }
    assert(nr_free_pages() == before - 1);

    uintptr_t slab = (uintptr_t)objs64[0] & ~(uintptr_t)(PGSIZE - 1);
    for (int i = 0; i < 64; i ++) {
        assert(((uintptr_t)objs64[i] & ~(uintptr_t)(PGSIZE - 1)) == slab);
        test_fill(objs64[i], 64, (uint8_t)i);
    }
    for (int i = 0; i < 64; i ++) {
        test_verify(objs64[i], 64, (uint8_t)i);
    }

    void *extra64 = slub_alloc(64);
    assert(extra64 != NULL);
    assert(((uintptr_t)extra64 & ~(uintptr_t)(PGSIZE - 1)) != slab);
    assert(nr_free_pages() == before - 2);

    slub_free(extra64);
    assert(nr_free_pages() == before - 1);
    for (int i = 0; i < 64; i ++) {
        slub_free(objs64[i]);
    }
    assert(nr_free_pages() == before);
    cprintf("[SLUB Test] 64B slab whole-page reclaim: PASS\n");

    /* 2048-byte objects: two per page. */
    before = nr_free_pages();
    void *objs2048[2];
    for (int i = 0; i < 2; i ++) {
        objs2048[i] = slub_alloc(2048);
        assert(objs2048[i] != NULL);
    }
    assert(nr_free_pages() == before - 1);

    slab = (uintptr_t)objs2048[0] & ~(uintptr_t)(PGSIZE - 1);
    for (int i = 0; i < 2; i ++) {
        assert(((uintptr_t)objs2048[i] & ~(uintptr_t)(PGSIZE - 1)) == slab);
        test_fill(objs2048[i], 2048, (uint8_t)(0x40 + i));
    }
    for (int i = 0; i < 2; i ++) {
        test_verify(objs2048[i], 2048, (uint8_t)(0x40 + i));
    }

    void *extra2048 = slub_alloc(2048);
    assert(extra2048 != NULL);
    assert(((uintptr_t)extra2048 & ~(uintptr_t)(PGSIZE - 1)) != slab);
    assert(nr_free_pages() == before - 2);

    slub_free(extra2048);
    assert(nr_free_pages() == before - 1);
    for (int i = 0; i < 2; i ++) {
        slub_free(objs2048[i]);
    }
    assert(nr_free_pages() == before);
    cprintf("[SLUB Test] 2048B slab whole-page reclaim: PASS\n");

    /* 4097 bytes needs two pages; bytes on both sides of the boundary must
     * be usable. */
    before = nr_free_pages();
    uint8_t *big = (uint8_t *)slub_alloc(4097);
    assert(big != NULL);
    assert(((uintptr_t)big & (PGSIZE - 1)) == 0);
    assert(nr_free_pages() == before - 2);

    big[0] = 0x11;
    big[PGSIZE - 1] = 0x22;
    big[PGSIZE] = 0x33;
    assert(big[0] == 0x11);
    assert(big[PGSIZE - 1] == 0x22);
    assert(big[PGSIZE] == 0x33);

    /* The remaining bytes across both pages must also be usable. */
    test_fill(big, 4097, 0x77);
    test_verify(big, 4097, 0x77);

    slub_free(big);
    assert(nr_free_pages() == before);
    cprintf("[SLUB Test] 4097B cross-page allocation: PASS\n");
}

/* 4. Oversized requests fail cleanly, free(NULL) is a no-op. */
static void
test_invalid_requests(void) {
    size_t before = nr_free_pages();

    slub_free(NULL);
    assert(nr_free_pages() == before);

    assert(slub_alloc((size_t)-1) == NULL);
    assert(nr_free_pages() == before);

    assert(slub_alloc((size_t)1 << 40) == NULL);
    assert(nr_free_pages() == before);

    assert(slub_alloc((nr_free_pages() + 1) * PGSIZE) == NULL);
    assert(nr_free_pages() == before);

    cprintf("[SLUB Test] oversized allocation and free(NULL): PASS\n");
}

/* 5. The page API still allocates/frees through the SLUB dispatch. */
static void
test_page_api(void) {
    size_t before = nr_free_pages();

    struct Page *page = alloc_pages(2);
    assert(page != NULL);
    assert(nr_free_pages() == before - 2);

    uint8_t *kva = (uint8_t *)(page2pa(page) + va_pa_offset);
    kva[0] = 0x5a;
    kva[PGSIZE] = 0xa5;
    assert(kva[0] == 0x5a);
    assert(kva[PGSIZE] == 0xa5);

    free_pages(page, 2);
    assert(nr_free_pages() == before);
    cprintf("[SLUB Test] alloc_pages/free_pages page path: PASS\n");
}

void
slub_check(void) {
    cprintf("[SLUB Test] begin\n");
    size_t baseline = nr_free_pages();

    test_boundaries();
    test_isolation();
    test_page_reclaim();
    test_invalid_requests();
    test_page_api();

    assert(nr_free_pages() == baseline);
    cprintf("[SLUB Test] ALL PASS\n");
}
