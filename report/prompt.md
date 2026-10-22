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

## 功能模块三：SLUB 分配器（任意大小的内存单元）

```text
【prompt】
现在的链路是 pmm.c 直接去调用Buddy System/first-fit /best-fit 的算法去分配页面，目前需要你新增一层，使用SLUB 作为中转来控制页面分配，新建 kern/mm/slub.h 和 kern/mm/slub.c
【rely】
目前分配页面调用的是pmm.c 中pmm_manager对应的地址下的alloc_pages、free_pages；
分配完页面切分的时候以及回收会用到page2pa、pa2page，在 pmm.h 中
【guarantee】
只新增文件以实现实现 SLUB 算法，并同步更改 pmm.c 中调用的逻辑，加上 SLUB 一层分支判定。其他文件不应修改。
新建slub_init(void)、void *slub_alloc(size_t size)、void slub_free(void *ptr)、void slub_check(void) 四个接口
【specification】
post-condition:
进行分配块大小分流，pmm.c 中调用的页面分配先经过SLUB判断，如果分配的块超过了 2048B 那么直接走原来的算法，以页为单位分配即可，如果<2048B 那么内部维护一个 2 的幂次的对应页进行分配。
数据结构：采用链表，只对头进行操作，从而不需要遍历，分配的时候拿出链表头进行使用，释放的时候压栈到链表头即可。
case:
1. 如果对应大小的页分配完了/之前没分配相关页：申请一页进行划分，串联成链表，按照对链表头 push/pop 的形式进行分配；比如需要 64B 的那么如果现在没有 64B 对应的页，就调用alloc_pages(n)申请一页用于 64B 的块，可以拆分成 64 个 64B 的块进行分配。
2. 如果分配的大小非 2 的整数幂次，那就向上取整进行分配；比如 70B 向上取整到 128B，寻找 128B 对应的页块分配
3. 释放内存时：通过paddr反查所属的页,若为>2048B直接调用底层 free_pages 归还;若是SLUB 小块，将其 push 回所属页的链表头。如果该页中所有划分出的小块已全部归还，则调用 free_pages整页释放
【补充】
分配的最小块最小是8B ，因为指针在挂取的时候都会占用 32 位
```

## 功能模块三 任务四：SLUB 测试（slub_test_lab2）

```text
【prompt】
新建测试 slub 算法的测试 slub_test_lab2.c slub_test_lab2.h 不要改动分配器已有核心逻辑，也不要更改其他无关的已存在的文件接口
【rely】
SLUB 接口、数据结构及分流规则见 kern/mm/slub.h、kern/mm/slub.c；
物理页管理接口见 kern/mm/pmm.h；
【guarantee】
实现并声明：
void slub_check(void);
【specification】
Pre-Condition：
底层物理页分配器和 SLUB 已初始化，具备执行正常分配测试的可用内存。
Post-Condition：
使用 assert 校验以下行为：
1. 不同尺寸及分档边界的分配、读写和释放正确，各对象互不干扰；
2. 小对象与大对象的分配符合要求
3. 跨页分配与整页回收正确，释放全部测试对象后，空闲物理页数恢复测试前水平
4. 能正确处理零大小/超大申请、释放 NULL
完成后执行可用的测试，报告结果及未验证项。
```

## 评分构建配置：make grade 选择 Best-Fit

模型整理的需求规格：修复默认使用 Buddy 时 `make grade` 的 Best-Fit 检查失败的问题。评分在现有临时副本中选择 Best-Fit，普通构建仍使用 Buddy，保留 SLUB 调用链及原有评分测试。修改真实文件后，在课程容器中运行评分并验证普通构建仍可启动；报告实际结果及未验证项。
