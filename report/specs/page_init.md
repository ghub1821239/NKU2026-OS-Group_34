# 练习一：物理页初始化 spec

实现位置：`kern/mm/pmm.c` 的 `lab2 function1`，保留小组代码的作者标记。基准为小组 lab2 分支 `7281d3b`。

输入来自 `get_memory_base()`、`get_memory_size()`、链接符号 `end` 和内核地址布局常量。输出为 `va_pa_offset`、`npage`、`pages` 及当前分配器的初始空闲区。

## 行为

1. 设置 `va_pa_offset = PHYSICAL_MEMORY_OFFSET`，验证 DTB 的内存基址、长度及加法溢出。
2. 将设备树内存末端限制在 `PHYSICAL_MEMORY_END` 以内，再向下按页对齐，得到可管理的物理地址上界。
3. `npage` 为该上界的物理页号；描述符数量为 `npage - nbase`。
4. `pages` 放在 `ROUNDUP(end, PGSIZE)`，使用虚拟地址访问描述符。写入描述符前检查整个数组能放入可管理内存。
5. 清理每个描述符的引用数、属性与标志，再标记为保留页。分配器登记块头时设置其链表链接。
6. 用 `PADDR(pages + count)` 得到描述符数组末端的物理地址，向上按页对齐，作为空闲区起点。
7. 只将该起点到可管理末端之间的完整页面交给 `init_memmap()`。

## 不变量与验收

- 固件、内核、描述符数组及对齐空隙保持保留状态。
- `page2pa(pa2page(pa))` 得到所在物理页的起始地址。
- 初始空闲页数等于空闲物理区间长度除以 `PGSIZE`。
- 无效 DTB 范围或描述符放不下时触发 `panic`；描述符放置完成后没有完整空闲页时直接返回，不调用 `init_memmap()`。
- 通过原配 `test_page_init()`；在 64、128、256 MiB RAM 下均能启动，管理范围受当前 128 MiB 上界限制。
