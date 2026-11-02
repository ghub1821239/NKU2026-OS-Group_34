#ifndef __KERN_SYNC_SYNC_H__
#define __KERN_SYNC_SYNC_H__

#include <defs.h>
#include <intr.h>
#include <riscv.h>

static inline bool __intr_save(void) {
    if (read_csr(sstatus) & SSTATUS_SIE) {
        intr_disable();
        return 1;
    }
    return 0;
}

static inline void __intr_restore(bool flag) {
    if (flag) {
        intr_enable();
    }
}
// 只有一句为什么要写成这种 while(0)?
// 因为调用的时候是local_intr_save(x);调用如果只写一句就会变成
// x = __intr_save();;
// 当然写成单句x = __intr_save()也可以但是如果多句的话就必须用{}套起来，因为有的可能会用 if() ocal_intr_save(x);调用
// 所以在这里就不能在{}加;会截断 else，因此才写的do while 这种构成完整的单句格式
#define local_intr_save(x) \
    do {                   \
        x = __intr_save(); \
    } while (0)
#define local_intr_restore(x) __intr_restore(x);

#endif /* !__KERN_SYNC_SYNC_H__ */
