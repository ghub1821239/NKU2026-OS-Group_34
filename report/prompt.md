# Lab2 提示词汇总

## 功能模块一 任务一：实现物理内存探测与页描述符初始化功能（page_init）

```text
【prompt】
在code/kern/mm/pmm.c 中的pmm_init 会调用page_init，请实现这个传参为空，返回为空的初始化函数。只实现这个函数即可，不要修改其他文件，参考 rely 给定的接口。要求完成后说明实际验证结果和未验证项
【rely】
需要调用static void init_memmap(struct Page *base, size_t n)函数；
Page 定义见 kern/mm/memlayout.h；
npage是物理页号的上界；
nbase 是 DRAM 起始页号;
va_pa_offset是虚地址到物理地址的偏移量, vaddr = paddr + va_pa_offset
应该不需要使用链表相关函数，但提醒一下：链表是循环双向链表；
结构大概是 0x80000000->0x88000000
openSBI core page 数组 可调配的空页（也是 page_init 的核心）
【gurantee】
本次只需要实现在code/kern/mm/pmm.cpage_init即可，把目标接口明确写成 static void page_init(void)，除此之外不需要新增其他任何新接口
【specification】
Post-Condition：Page数组，npage和va_pa_offset均完成赋值；然后 openSBI 内核和 page 数组占的页需要锁死，reserved，其他作为空页可以分配
case:
1. 如果设备树有问题，无效那么就停止，报错并终止
2. 如果扣掉 page 数组等之后，剩余部分无法构成完整页，那么就不调用init_memmap
【caution】
实现过程中有任何不明确的接口，变量等先查看声明定义，如果无法推断含义请询问我，确定后再执行。
```

## 功能模块二 任务二：实现 Best-Fit 连续物理内存分配算法

```text
【prompt】
在code/kern/mm/best_fit_pmm.c 中实现Best-Fit 连续物理内存分配算法，即在>=  n 的块中遍历一遍链表找到最接近 n 的块分配出去，初始化等操作可以参考code/kern/mm/default_pmm.c的实现方式，尽可能复用逻辑;
修改kern/mm/pmm.c 中的 init_pmm_manager()，将 pmm_manager 切换为 &best_fit_pmm_manager
【RELY】
Page 的定义在code/kern/mm/memlayout.h；
pmm_manager的定义在code/kern/mm/pmm.h;
【guarantee】
完成Best-Fit 连续物理内存分配算法:
// 必须定义的内部状态：
static free_area_t free_area;
#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)
// 必须实现的接口函数与导出的管理器结构体：
static void best_fit_init(void);
static void best_fit_init_memmap(struct Page *base, size_t n);
static struct Page *best_fit_alloc_pages(size_t n);
static void best_fit_free_pages(struct Page *base, size_t n);
static size_t best_fit_nr_free_pages(void);
const struct pmm_manager best_fit_pmm_manager; // .name = "best_fit_pmm_manager", .check = best_fit_check

保留 best_fit_pmm.c 中已有的 basic_check 和 best_fit_check 测试函数，严禁修改它们。
【specification】
best_fit_init_memmap(base, n)和best_fit_free_pages(base, n)注意使用 break 防止死循环；
best_fit_alloc_pages(n)：
1. 当 n > nr_free 或链表中没有 property >= n 的块时，返回 NULL
2. 如果能找到就从链表中删除，并清除PG_property，nr_free同步减去空闲页数量
```

## 功能模块二 任务三：Buddy System（伙伴系统）分配算法

```text
【prompt】
更改目前的空页管理，不同于default_pmm.c 中只采用一个free_area_t创建单条链表进行管理，并且空闲页的定义更加严苛——存储块的大小必须是2的n次幂。
参考 pmm.c 和 pmm.h 的接口生成对应的buddy system 的 bs_pmm.c bs_pmm.h 即可，其他文件不要进行接口的修改。
生成后记得同步更改 pmm.c 中的调用
pmm_manager = &best_fit_pmm_manager;->pmm_manager = &bs_pmm_manager;
并同步更改头文件；
【rely】
page 的定义在memlayout.h中；
参考typedef struct {
    list_entry_t free_list;         // the list header
    unsigned int nr_free;           // number of free pages in this free list
} free_area_t;
pmm_manager的定义在code/kern/mm/pmm.h;
【guarantee】
可以使用分层管理，第一层管理 2 的幂次的首页 base 地址，然后每一个 base 地址第二层管理和原 default_pmm.c 逻辑类似。
// 在 kern/mm/bs_pmm.h 中声明并在 kern/mm/bs_pmm.c 中定义：
extern const struct pmm_manager bs_pmm_manager;

// 在 kern/mm/bs_pmm.c 中实现的内部接口：
static void bs_init(void);
static void bs_init_memmap(struct Page *base, size_t n);
static struct Page *bs_alloc_pages(size_t n);
static void bs_free_pages(struct Page *base, size_t n);
static size_t bs_nr_free_pages(void);
static void bs_check(void);
【specification】
buddy system 实现要求如下：
实现一个 free_area_t 类型的数组free_area，free_area[k]管理的是 2^k 大小的页；
    1. 注意要实现对页的划分，贪心从基地放入每个存储块最大能发下的 2^k 的页，然后循环多次，存储块内存空间就会得到充分利用：
        示例：7页大小的空闲块，先尝试放入 k=2 ，剩余 3，之后放入  k=1 ，剩余 1，再把这部分放入 k=0 即可完成利用
    2. 释放的时候需要检查临近的同大小的块是否空闲，如果空闲可以合并成 2^k+1 的空闲页
```

## 功能模块二 任务三：Buddy System 测试（bs_test_lab2）

```text
【prompt】
新增 bs_test_lab2.c bs_test_lab2.h 两个测试文件供 buddy system 的测试；
【rely】
类似 test_lab2.c 中的test_best_fit写一个 test_buddy_system 用来检测当前测试的是否是 bs 算法，如果不是panic 返回；
【gurantee】
确保只生成bs_test_lab2.c bs_test_lab2.h，其他的文件均不进行修改，也不新增其他的文件
【specification】
case:
    1. 测试算法对空闲页的分配情况，首先测试幂次能否正确对应，如 8 页对应 k=3；其次测试非 2 幂次的页会如何分配，比如 7 能否依次拆分分配到 k=2 k=1 k=0;
    2. 测试算法释放页时能否合并相邻页，比如相邻存储块隶属于 k=2 目前为空，本存储块释放后应该和相邻存储块合并成一个大块，然后继续检测能否合并，如果不行就挂载到 k=3，否则继续迭代；
    3. 测试对申请空间超出最大分配/不满足>0 的情况能否正常 panic报错
生成后请运行检测并报告测试情况
```
