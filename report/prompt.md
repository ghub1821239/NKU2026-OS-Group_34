# Lab4 功能模块一：虚拟内存页操作提示词


# 1. 虚拟内存页操作

## 1.1 page_insert：建立和更新物理页映射

```markdown
【prompt】
补全老师提供的 Lab4 工程 kern/mm/pmm.c 中 //LAB4 function1 YOUR CODE 位置的
int page_insert(pde_t *pgdir, struct Page *page, uintptr_t la, uint32_t perm);
使给定线性地址 la 映射到指定物理页 page，并按 perm 更新页表项权限。
要求正确处理首次映射、同一物理页重复映射、用不同物理页替换旧映射和页表分配失败。
本项目使用 RISC-V Sv39 三级页表，必须以当前工程的函数和宏定义为准，不能直接套用其他版本 uCore 的代码。
若目标函数已存在，不得重复定义；除当前目标函数外，不修改其他已有函数、文件或接口，不实现其他组员负责的进程和调度模块。

【rely】
可依赖 kern/mm/pmm.c、kern/mm/pmm.h、kern/mm/mmu.h 和相关头文件中已有的接口：
1. pde_t、pte_t、struct Page、PTE_V、PTE_U、PTE_W、PTE_R；
2. pte_t *get_pte(pde_t *pgdir, uintptr_t la, bool create)：create=1 时按需建立中间级页表，失败返回 NULL；
3. struct Page *pte2page(pte_t pte)：从有效页表项取得对应的物理页描述符；
4. page2ppn(page) 与 pte_create(ppn, perm)：使用物理页号创建带有效位的 PTE；
5. page_ref_inc(page)、page_ref_dec(page)：返回修改后的引用计数，不会自动释放物理页；
6. free_page(page)：物理页释放宏，由调用者保证引用计数降为 0 后再调用；
7. tlb_invalidate(pgdir, la)：执行本 hart 的 sfence.vma la，未使用 pgdir 判断当前地址空间，不提供跨 hart 同步；
8. -E_NO_MEM：页表分配失败时的错误返回值。

【guarantee】
仅在 kern/mm/pmm.c 的 //LAB4 function1 YOUR CODE 区域实现 page_insert()。
保留原有 Lab2/3 迁移实现、get_pte()、page_init()、物理页分配器、老师的检查代码和其余 Lab4 占位。
不新增接口，不修改 Makefile 和测试脚本，不自动执行 git commit。
成功时返回 0；get_pte() 返回 NULL 时返回 -E_NO_MEM。
不擅自把调用者传入的 perm 改写为额外权限位。

【specification】
Pre-Condition：
1. pgdir 指向有效 Sv39 根页表的内核虚拟地址，page 指向已分配且可管理的物理页；
2. la 指向普通 4 KiB 页映射区域，中间级页表项不是大页叶项；la 不要求页对齐；
3. 已有映射的物理页引用计数正确；调用者保证当前页表修改不发生并发冲突。

Post-Condition：
1. 首先调用 get_pte(pgdir, la, 1)；如果返回 NULL，则返回 -E_NO_MEM，且不修改目标数据页的引用计数和原有末级映射。
2. 若原地址没有有效映射：目标物理页引用计数加 1，在目标 PTE 建立映射。
3. 若原地址已映射同一物理页：引用计数保持不变，不释放该页；更新权限和 TLB。
4. 若原地址已映射不同物理页：目标物理页引用计数加 1；覆盖旧 PTE；失效对应 TLB 翻译；旧页引用计数减 1，仅在降为 0 时释放旧页。
5. 使用 pte_create(page2ppn(page), perm) 整体更新 PTE，避免旧权限残留；所有成功映射更新均须处理 TLB 失效，并保证 PTE 写入、TLB 失效、物理页回收之间的编译器顺序。
6. 更新成功后返回 0；不得留下仍指向已释放物理页的有效末级映射。
7. 注意：当前 get_pte() 若首次创建中间页表成功而下一级分配失败，可能残留中间页表页。请明确报告这一依赖问题，不得声称已实现完整失败回滚，也不要未经允许扩大修改范围。
```

## 1.2 page_remove：安全撤销物理页映射

```markdown
【prompt】
补全老师提供的 Lab4 工程 kern/mm/pmm.c 中 //LAB4 function1 YOUR CODE 位置的
void page_remove(pde_t *pgdir, uintptr_t la);
使其安全撤销 la 对应的末级物理页映射，正确维护物理页引用计数并处理 TLB 失效。
删除不存在的映射时必须安静返回，重复删除不得导致重复释放。
若目标函数已存在，不得重复定义；只实现当前函数，不修改其他函数或文件，不新增文件或接口。

【rely】
1. pde_t、pte_t、struct Page 和 PTE_V；
2. get_pte(pgdir, la, 0)：只查找末级页表项，不创建页表；
3. pte2page(*ptep)：通过有效 PTE 获取原物理页；
4. page_ref_dec(page)：减少引用计数并返回修改后的值，不会自动释放物理页；
5. free_page(page)：物理页释放宏，由调用者保证引用计数降为 0 后再调用；
6. tlb_invalidate(pgdir, la)：执行本 hart 的 sfence.vma la，未使用 pgdir 判断当前地址空间，不提供跨 hart 同步；
7. 当前 check_pgdir() 的清理约定：删除数据页映射后，中间级页表仍保留供测试自行回收。

【guarantee】
仅在 kern/mm/pmm.c 的 //LAB4 function1 YOUR CODE 区域实现 page_remove()。
绝对不能使用 get_pte(pgdir, la, 1) 删除映射，也不能为不存在的映射分配新的页表。
不修改 Lab2/3 已迁移代码、老师的测试函数、其他 Lab4 模块、Makefile 和已有接口。
不自动回收空中间级页表，不自动执行 git commit。

【specification】
Pre-Condition：
1. pgdir 指向有效 Sv39 根页表的内核虚拟地址；
2. la 位于普通 4 KiB 页映射区域，中间级页表项不是大页叶项，la 无须页对齐；已有映射的物理页引用计数正确；
3. 调用者保证页表操作期间没有未受保护的并发修改。

Post-Condition：
1. 调用 get_pte(pgdir, la, 0) 查找末级 PTE。
2. 若 PTE 不存在或其 PTE_V 位未设置，则直接返回，不改变引用计数、物理页分配状态或其他映射。
3. 若存在有效映射，先取得旧物理页，再清空对应 PTE，使该地址不再指向旧物理页。
4. 对 la 执行必要的 TLB 失效操作，保证旧翻译结果失效后再允许回收物理页，并保证 PTE 写入、TLB 失效、物理页回收之间的编译器顺序。
5. 原物理页引用计数减 1；仅当计数变为 0 时调用 free_page(page)。若同一页还有其他虚拟地址别名，这些别名应继续有效。
6. 对同一地址再次调用 page_remove() 必须安全、无异常、无重复释放。
7. 保留中间级页表，避免改变现有页表检查对页表页的管理约定。
```

# 2. 进程创建及初始化功能
## 2.1 static struct proc_struct *alloc_proc(void);(kern/process/proc.c)
```markdown
【prompt】
我们要实现static struct proc_struct *alloc_proc(void);(kern/process/proc.c)这个函数，括号内为函数所在的文件路径。目的是调用的时候可以分配一个新的进程，函数返回进程结构体指针
【rely】
proc.h 中的结构体proc_struct；proc.h 中的proc_state；kmalloc.h 中的 kmalloc 申请内存；pmm.h 中的 boot_pgdir_pa；
【guarantee】
必须实现static struct proc_struct *alloc_proc(void);函数，完成process的分配操作，除此之外不要修改任何其他文件或本文件的其他函数接口
【specification】
post-condition:返回非空 struct proc_struct *proc，且成员变量均已初始化为确定值，比如 pid=-1 runs=0等
如果失败，那么就返回 NULL
```
## 2.2 void proc_init(void);(kern/process/proc.c)
```markdown
【prompt】
实现 kern/process/proc.c 中的 void proc_init(void); 函数，首先初始化进程链表和哈希表等全局管理结构，然后将当前正在启动的执行流初始化为 0 号内核线程 idleproc，完成设置 pid 为 0、状态设为 PROC_RUNNABLE、need_resched 置为 1等工作；之后通过 kernel_thread 创建 1 号内核线程 initproc，完成初始化后正常返回即可
【rely】
proc.h 中的结构体proc_struct；proc.h 中的proc_state、kernel_thread； proc.c 中已有的全局状态（proc_list、hash_list、nr_process）；pmm.h 中的 list.h、assert.h（panic）等
RV64 0&1 号进程官方的状态转换约束
【guarantee】
必须实现 kern/process/proc.c 中的 void proc_init(void); 函数，除此之外不要修改任何其他文件或本文件的其他函数接口
【specification】
post-condition:
1. 全局进程链表和哈希表均已初始化，0 号线程 idleproc 与 1 号线程 initproc 均已创建而且状态正确
2. 异常分支：如果分配或创建 idleproc / initproc 失败，直接调用 panic 报错停机。
```
## 2.3 int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);(kern/process/proc.c)
```markdown
【prompt】
实现 kern/process/proc.c 中的 int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags); 函数。构造一个临时中断帧（struct trapframe），清零后配好入口函数 fn、参数 arg、首次进入的汇编入口以及内核态运行状态，然后在传入的 clone_flags 上补齐共享虚拟内存空间对应的标志位，调用 do_fork 创建内核线程并返回结果
【rely】
proc.h 中的 kernel_thread、do_fork 声明；trap.h 中的 struct trapframe；proc.c 已声明的 kernel_thread_entry 及 entry.S 里的传参约定；
【guarantee】
必须实现 int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags); 函数，除此之外不要修改任何其他文件或本文件的其他函数接口
【specification】
post-condition: 临时中断帧已清零并配置妥当，新建内核线程启动后能从汇编入口跳去执行 fn(arg)；传给 do_fork 的栈参数为 0（使用各自独立的内核栈）且带有共享虚拟内存标志，直接返回 do_fork 的返回值（成功为新线程 pid，失败为错误码）
```
## 2.4 int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf);(kern/process/proc.c) & static void copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf);(kern/process/proc.c) & static int copy_mm(uint32_t clone_flags, struct proc_struct *proc);(kern/process/proc.c)
```markdown
【prompt】
在 kern/process/proc.c 实现 copy_mm、copy_thread 和 do_fork 三个函数。copy_mm 只需保持内核线程 proc->mm 为空并返回 0；copy_thread 把传入的 tf 拷贝到子进程内核栈顶，并配置好首次进入 forkret 的上下文；do_fork 依次完成上限检查、申请 PCB 与内核栈、调用上述两函数、关中断下分配 pid 并挂入全局哈希表和进程链表，最后唤醒并返回新 pid
【rely】
proc.h 的 proc_struct、current、do_fork；trap.h 的 trapframe；proc.c 已有的 alloc_proc、setup_kstack、put_kstack、get_pid、nr_process等；sched.h 的 wakeup_proc；sync.h 中的 panic；
【guarantee】
保留三个独立函数签名与分工，不要揉成一个函数；不要改动已有的函数和接口
【specification】
post-condition:
1. copy_mm 保持 proc->mm == NULL 返回 0；copy_thread 使 proc->tf 位于栈顶（a0 为 0，sp 按 esp 或栈顶配置）且 context.ra == forkret、context.sp == proc->tf；
2. do_fork 正常时在关中断保护下更新链表与 nr_process，唤醒新线程并返回正整数 pid；
3. 异常分支：达上限或任一步分配失败时，逆序释放已申请的内核栈与 PCB，不写入链表并返回负错误码
```

# 3.
## 3.1 void cpu_idle(void);(kern/process/proc.c)
```markdown
【prompt】
生成void cpu_idle(void);(kern/process/proc.c)函数的 body，它起的作用就是去盯着need_resched，然后如果变成 1 就说明其他的线程要跑了，idleproc 就给需要跑的让出来，然后调用 schedule()去选择要跑的线程是谁
【rely】
sched.h 的 schedule；list.h 的 list_next；
【guarantee】 
只实现void cpu_idle(void);(kern/process/proc.c)函数，其他文件和函数接口不要做修改
【specification】 
内部用一个 while(1)轮询盯着 need_resched就可以
```
## 3.2 void schedule(void);(kern/schedule/sched.c)
```markdown
【prompt】
生成 void schedule(void)函数的 body，它先关闭中断保护，然后将 current的need_resched 清 0，再从current 往下取遍历链表找 Runnable 的线程，然后将选中的 runs+1，如果没有的话就默认选择 idleproc 0 号线程
【rely】
sched.h 的 schedule；proc.h 的 struct proc_struct、proc_list、idleproc、current；list.h 的 list_next；
【guarantee】 
只实现 kern/schedule/sched.c 中的 void schedule(void) 函数，其他文件和函数接口不要做修改
【specification】 
post-condition:
调度前清除 current->need_resched，且整个选路过程受关中断保护；
无其他可运行进程时回退到 idleproc；
被选中的 next->runs 加 1，且仅当 next != current 时调用 proc_run(next)。
```
## 3.3 void proc_run(struct proc_struct *proc);(kern/process/proc.c)
```markdown
【prompt】
生成 void proc_run(struct proc_struct *proc)函数的 body，他的目的就是完成线程、页表和执行现场切换，也就是将 current 更新为 proc，然后把 satp 切换为新线程的页表基址，之后调用 switch_to 去保存 callee的那几个寄存器
【rely】
proc.h 的 struct proc_struct、current、cpu_idle、proc_run；proc.c 已声明的 switch_to；sched.h 的 schedule；
【guarantee】 
只实现 kern/process/proc.c 中的proc_run函数，其他文件和函数接口不要做修改
【specification】 
post-condition:
proc_run 在 proc == current 时直接剪枝返回；
当 proc != current 时在关中断保护下去更新 current 后保证 RV64 Sv39 模式下的 satp 页表基址与 TLB 正确切换，再通过 switch_to 切换上下文。
```
## 3.4 void switch_to(struct context *from, struct context *to);(kern/process/switch.s)
```markdown
【prompt】
生成switch_to(kern/process/switch.S)汇编部分，写清楚.text .globl switch_to等部分，他的目的在被proc_run调用之后完成寄存器的管理，因为函数调用的时候 sp ra 这些会受到编译器的改动，所以这里只能采用汇编的形式保存 callee的那几个寄存器
【rely】
参考void proc_run(struct proc_struct *proc)调用的形式；proc.h 中的struct context这个结构体； RV64 中 callee 方需要保存的 14 个寄存器分别是啥
【guarantee】 
只实现kern/process/switch.S中的switch_to汇编形式，其他文件和函数接口不要做修改
【specification】 
post-condition:
14 个寄存器可以按需保存下来，方便之后切换的时候的恢复以及方便转换进程之后的新 proc 的使用
```
## challenge 1:说明语句 local_intr_save(intr_flag); ... local_intr_restore(intr_flag); 是如何实现开关中断的。
```markdown
local_intr_save(intr_flag)先读取状态寄存器 sstatus 中的中断使能位 SSTATUS_SIE：若原本开中断，就调用 intr_disable() 关中断并将 intr_flag 记为 1；若原本就已经关中断，则直接把 intr_flag 记为 0。
local_intr_restore(intr_flag) 在退出保护区时只检查 intr_flag：只有当 intr_flag 为 1（说明进入前原本开着中断、是本次操作关掉的）时，才调用 intr_enable() 重新开启中断；若为 0 则保持关中断不动。
```
## Challenge 2:深入理解不同分页模式的工作原理（思考题）:
### 题目：
```markdown
get_pte() 函数位于 kern/mm/pmm.c，用于在页表中查找或创建页表项，从而实现对指定线性地址对应的物理页的访问和映射操作。这在操作系统的分页机制下，是虚拟内存与物理内存建立映射关系的关键基础。

get_pte() 函数中有两段形式类似的代码，结合 sv32、sv39、sv48 的异同，解释这两段代码为什么如此相像。
目前 get_pte() 函数将页表项查找和页表页分配合并在一个函数里，你认为这种写法好吗？有没有必要把两个功能拆开？
```
### 答案：
```markdown
相似是因为无论是sv32（2 级页表，10+10+12）、sv39（3 级页表，9+9+9+12）还是 sv48（4 级页表，9+9+9+9+12）。三种模式的区别主要在于虚拟地址位宽、每级索引位数与总级数不同，但是三种模式每一层执行的本质逻辑完全一致，都是在嵌套索引这个页表项，每一层干的事其实是一样的。
我认为当前合在一起的写法是合理的，现阶段没有必要拆开。因为查找定位和缺表时就直接补上发生在一条逐级遍历的路径上，通过 create 参数复用同一份代码，既能一趟遍历完成工作、避免重复查表，当然如果为了追求函数的职责单一化也可以拆分，方便 debug。
```