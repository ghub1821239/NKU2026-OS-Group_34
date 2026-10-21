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
