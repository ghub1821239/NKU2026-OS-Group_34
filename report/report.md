# Lab4 实验报告 进程管理

## 实验基本信息

| 项目 | 内容 |
| --- | --- |
| 小组 | 第 34 组 |
| 小组成员 | 焦宇堃、黄国天、徐夏茗 |
| 实验主题 | 虚拟内存页操作、内核线程创建与调度 |
| 代码版本 | 小组仓库 `lab4` 分支，`07f4fe1c9d3c73667e9c20f11686b144b46c4484` |
| 验证日期 | 2026 年 11 月 20 日 |

### 小组分工

| 成员 | 负责的练习与模块 | 验证工作 |
| --- | --- | --- |
| 黄国天 | 功能模块一：`page_insert`、`page_remove` 页映射维护，结合 `get_pte` 理解页表查找 | 检查同页重映射、异页替换、引用计数和重复删除，验证 PMM 测试 |
| 焦宇堃 | 功能模块二：`alloc_proc`、`proc_init`、`kernel_thread`、`do_fork`、`copy_mm`、`copy_thread` | 核对 idle、init 的状态、内核栈和首次运行现场，验证 Process Create 测试 |
| 徐夏茗 | 功能模块三：`cpu_idle`、`schedule`、`proc_run`、`switch_to` | 核对 Sv39 页表切换和寄存器恢复，验证多线程轮转与 Schedule 测试 |

## 一、实验目标与整体逻辑

Lab2 已经实现物理页分配和启动页表，Lab3 完成了中断与异常的进入、现场保存和返回。我们在 Lab4 中顺着这条主线继续向上搭建线程管理机制，整体分为三个递进阶段，先维护虚拟地址到物理页的映射关系，再分配线程控制块、内核栈并构造首次运行现场，最后通过调度器把 CPU 交给新创建的线程。

本实验围绕三条主线展开。

1. 通过 `page_insert` 和 `page_remove` 维护多级页表项、物理页引用计数以及 TLB 状态，同时借助 `mm_struct` 和 `vma_struct` 描述虚拟地址空间的逻辑布局。
2. 通过 `alloc_proc`、`proc_init`、`kernel_thread` 和 `do_fork` 完成进程控制块初始化与资源组装，创建可运行的内核线程。
3. 通过 `cpu_idle`、`schedule`、`proc_run` 和 `switch_to` 从就绪队列中选出目标线程并完成页表与寄存器现场切换。

系统加电启动后的初始化流程对应 [kern/init/init.c](../code/kern/init/init.c)，整体调用链如下。

```text
entry.S → kern_init
  → 清零 BSS、解析 DTB 并初始化控制台
  → pmm_init 完成物理页管理、页表检查与内核动态分配器初始化
  → pic_init 与 idt_init 准备中断与异常处理入口
  → vmm_init 检查虚拟内存区域管理
  → proc_init 建立 idleproc 并创建 initproc
  → clock_init 与 intr_enable 开启时钟与中断
  → cpu_idle → schedule → proc_run → switch_to
```

当 `initproc` 第一次被调度选中后，CPU 还要经过一段预先构造好的恢复链才能真正进入线程主函数。

```text
switch_to 的 ret
  → forkret → forkrets → __trapret → RESTORE_ALL → sret
  → kernel_thread_entry → init_main
  → do_exit
```

当前阶段所有线程都运行在 S 态，共享同一套内核地址空间 `boot_pgdir_pa`，并各自使用独立的 8 KiB 内核栈。其中 `idleproc` 直接复用启动时已经运行的执行流，`initproc` 则走完完整的线程创建路径。

## 二、实验环境

| 项目 | 配置 |
| --- | --- |
| 系统 | Ubuntu / WSL，x86_64 |
| 目标平台 | QEMU virt，RISC-V RV64，128 MiB RAM |
| 编译器 | riscv64-unknown-elf-gcc 10.2.0 |
| 模拟器与固件 | QEMU 4.1.1，OpenSBI v0.4 |
| 调试器 | gdb-multiarch 12.1 |
| 构建工具 | GNU Make 4.3 |

### AI 工具与使用说明

| 成员 | AI 编程工具 | 底层模型 |
| --- | --- | --- |
| 焦宇堃 | Claude Code | DeepSeek-V4-Flash |
| 黄国天 | Claude Code | DeepSeek-V4-Flash |
| 徐夏茗 | Claude Code | DeepSeek-V4-Flash |

AI 主要用于依据 Spec 生成目标函数、梳理线程首次运行链路，以及分析测试输出和调试报错。协作时先提供已有接口与修改范围，再结合源码检查引用计数、栈布局和寄存器约定，最后通过普通启动与官方评分验证结果。

小组各模块的完整 Spec 和 Prompt 保存在 [prompt.md](prompt.md) 中，下文结合源码实现说明这些设计约束如何落地。

## 三、核心功能与实现

### 3.1 虚拟内存页操作与地址空间描述

本部分涉及 [kern/mm/pmm.c](../code/kern/mm/pmm.c)、[kern/mm/pmm.h](../code/kern/mm/pmm.h)、[kern/mm/mmu.h](../code/kern/mm/mmu.h)、[kern/mm/vmm.h](../code/kern/mm/vmm.h) 和 [kern/mm/vmm.c](../code/kern/mm/vmm.c)。

在 Sv39 三级分页机制下，`get_pte` 依次提取线性地址中的三级索引 `PDX1`、`PDX0` 和 `PTX` 来定位末级页表项。当前两级目录不存在时，如果传入参数 `create` 为 1，函数会申请并清零新的页表页以补全路径，如果 `create` 为 0 则只执行查找并在缺少目录时直接返回 `NULL`。`page_insert` 和 `page_remove` 都在这个接口之上维护普通 4 KiB 页面的映射。

实现 `page_insert` 时，我们首先调用 `get_pte` 并传入创建标志 1。若返回 `NULL`，说明中间页表分配失败，函数直接返回 `-E_NO_MEM`，不会改动目标数据页的引用计数或已有末级映射。定位到目标表项后，读取旧表项并按三种情况处理。

| 原映射情况 | 引用计数处理 | 页表处理 |
| --- | --- | --- |
| 没有有效映射 | 新页引用计数加一 | 建立新映射 |
| 已映射到同一物理页 | 引用计数保持不变 | 更新权限位 |
| 已映射到其他物理页 | 新页加一，旧页减一 | 替换为新映射 |

在代码细节上，我们先通过 `pte_create` 构造包含新物理页号与权限位的表项并写入内存，覆盖原有的权限标志。写入完成后，使用编译器内存屏障和 `tlb_invalidate` 保证内存写入与快表刷新的先后顺序，最后再减少旧页引用计数并在计数降为零时调用 `free_page` 回收物理页。这样处理后，同一物理页重复插入时不会被误释放，替换映射时也能避免旧 TLB 缓存继续指向已经回收的物理页。

实现 `page_remove` 时，我们以 `create` 为 0 调用 `get_pte` 查找页表项。如果找不到页表项或者表项有效位未置位，函数直接返回，保证重复删除同一地址的安全性。若映射有效，则先通过 `pte2page` 取得原物理页，清空页表项并调用 `tlb_invalidate` 失效对应快表项，最后递减引用计数并在计数归零时释放物理页。由于只减少当前映射对应的引用计数，同一物理页被多个虚拟地址共享映射时，删除其中一处不会影响其他映射。中间级页表由调用者或测试代码统一清理，`page_remove` 保留这些页表页。

`get_pte` 当前还存在部分分配失败的边界：上一级页表创建成功而下一级分配失败时，已经创建的中间页表不会自动回收。因此，`page_insert` 的失败返回能保持数据页引用计数和原有末级映射不变，完整的中间页表回滚还需要在遍历层补充。

在虚拟地址空间描述方面，`vma_struct` 用半开区间 `[vm_start, vm_end)` 表示一段连续虚拟内存及其读写执行权限，`mm_struct` 则通过按起始地址排序的双向链表 `mmap_list` 和最近命中的缓存指针 `mmap_cache` 组织多个 VMA。`mm_create` 初始化管理结构，`vma_create` 申请区域节点，`insert_vma_struct` 按地址顺序插入并检查相邻区域是否存在重叠，`find_vma` 先检查缓存再遍历链表确认地址是否落在区间内，`mm_destroy` 负责释放全部区域与管理结构。

从分工上看，VMA 负责刻画地址空间的逻辑划分与访问属性，PTE 则决定硬件 MMU 实际如何完成地址翻译。当前 `vmm_init` 已经验证了区域创建、有序插入和边界查找逻辑，内核线程的 `mm` 指针仍为 `NULL`。内核启动阶段继续复用 `entry.S` 建立的高地址映射，页表操作测试则在低地址建立并清理临时映射。

### 3.2 线程创建与初始化

本部分涉及 [kern/process/proc.h](../code/kern/process/proc.h) 和 [kern/process/proc.c](../code/kern/process/proc.c)。`proc_struct` 将线程运行状态与所占资源集中管理，主要字段如下。

| 字段 | 作用 |
| --- | --- |
| `state`、`pid`、`name` | 生命周期状态、进程编号与名称 |
| `kstack` | 线程内核栈起始虚拟地址 |
| `parent` | 父线程控制块指针 |
| `mm` | 用户地址空间描述，当前为 `NULL` |
| `pgdir` | 根页表物理地址，用于设置 `satp` |
| `tf` | Trap 帧，用于首次运行恢复寄存器 |
| `context` | 普通切换时保存的寄存器现场 |
| `need_resched`、`runs` | 调度需求标志与被选中次数 |
| `list_link`、`hash_link` | 全局链表与 PID 哈希表节点 |

在状态定义中，`PROC_RUNNABLE` 同时涵盖等待调度和正在运行两种状态，当前实际占用 CPU 的线程由全局指针 `current` 标识。

初始化阶段分为两步。首先是 `alloc_proc`，该函数通过 `kmalloc` 申请一块 `proc_struct` 内存，将 `state` 设为 `PROC_UNINIT`、`pid` 设为 `-1`，清零运行计数、上下文、标志位与名称，将 `mm`、`tf`、`parent` 等指针置为空，并把 `pgdir` 设为 `boot_pgdir_pa`。其次是 `proc_init`，它先初始化全局链表 `proc_list` 和哈希表 `hash_list`，再把当前正在执行的启动流包装为第 0 号线程 `idleproc`，设置其 PID 为 0、状态为 `PROC_RUNNABLE`、内核栈为 `bootstack`，并将 `need_resched` 置为 1，使调度器能够尽快触发切换。随后令 `current` 指向 `idleproc`，调用 `kernel_thread` 创建 PID 为 1 的 `initproc`。`idleproc` 作为空闲回退对象单独维护，普通线程则挂入全局链表与哈希表，初始总线程数 `nr_process` 统计了这两个线程。

创建新线程时，`kernel_thread` 在栈上准备一个清零的临时 `trapframe`，将线程入口函数地址存入 `s0`、参数存入 `s1`，把 `epc` 指向汇编入口 `kernel_thread_entry`。在 `sstatus` 字段中设置 `SPP` 和 `SPIE` 位并清除 `SIE` 位，保证首次通过 `sret` 恢复时进入 S 态并开启中断，随后以 `clone_flags | CLONE_VM` 调用 `do_fork`。

`do_fork` 依次完成检查总线程数上限、调用 `alloc_proc` 分配控制块、记录 `parent` 指针、调用 `setup_kstack` 分配 8 KiB 内核栈、调用 `copy_mm` 处理地址空间、调用 `copy_thread` 设置首次运行现场。在这些资源全部准备就绪后，进入关中断临界区分配唯一 PID，将新线程加入 `hash_list` 与 `proc_list` 并递增 `nr_process`，最后调用 `wakeup_proc` 将状态设为 `PROC_RUNNABLE` 并返回新 PID。如果中途任意一步分配失败，函数按资源申请的逆序执行清理，先释放已分配的内核栈，再释放控制块，确保尚未就绪的线程不会残留到全局链表中。

由于当前创建的均为内核线程，`copy_mm` 直接保持 `proc->mm` 为 `NULL` 并返回 0，各线程通过共同的 `boot_pgdir_pa` 访问内核地址空间。`copy_thread` 则在新线程 8 KiB 内核栈顶部向下划出 `trapframe` 空间，把临时帧复制过去并将子线程返回值寄存器 `tf->gpr.a0` 设为 0。当传入栈参数为 0 时，将恢复后的 `sp` 指向该 `trapframe` 起始处，同时设置上下文切换入口。

```c
proc->context.ra = (uintptr_t)forkret;
proc->context.sp = (uintptr_t)proc->tf;
```

通过这两项赋值，新线程第一次被 `switch_to` 选中后就会直接跳转到 `forkret` 开始执行。

### 3.3 调度与上下文切换

本部分涉及 [kern/schedule/sched.c](../code/kern/schedule/sched.c)、[kern/process/switch.S](../code/kern/process/switch.S)、[kern/process/entry.S](../code/kern/process/entry.S) 和 [kern/trap/trapentry.S](../code/kern/trap/trapentry.S)。

启动流程末尾进入 `cpu_idle` 循环，持续检查 `current->need_resched`。检测到标志为真时调用 `schedule`。调度器首先关闭本地中断并清除当前线程的 `need_resched`，然后从 `current` 之后沿 `proc_list` 环形扫描下一个处于 `PROC_RUNNABLE` 状态的线程，如果当前线程是 `idleproc` 则从链表头开始查找。若遍历一圈未找到其他可运行线程，则回退选择 `idleproc`。选中目标线程后递增 `next->runs`，仅当目标线程与 `current` 不同时才调用 `proc_run`，因此 `runs` 统计的是被调度器选中的次数，不等同于实际发生上下文切换的次数。

`proc_run` 在关中断的临界区内将 `current` 更新为目标线程，按 Sv39 格式将目标线程页表物理地址转换为 `satp` 寄存器值，刷新 TLB 后再调用 `switch_to`。

```c
satp = ((uintptr_t)SATP_MODE_SV39 << 60)
     | (next->pgdir >> RISCV_PGSHIFT);
```

汇编函数 `switch_to` 按照 `struct context` 的字段偏移保存旧线程的 `ra`、`sp` 以及 `s0` 到 `s11` 共 14 个寄存器，再加载新线程的对应值，总计 112 字节。由于线程切换发生在普通 C 函数调用边界，编译器会按照 RISC-V 调用约定处理跨调用仍需保留的临时值，汇编代码只需额外保存返回地址、栈指针以及被调用者保存的 `s0` 到 `s11`。这与 Lab3 中硬件中断或异常在任意指令边界触发、必须保存 288 字节完整 `trapframe` 的场景不同。

对于首次运行的新线程，`switch_to` 末尾的 `ret` 指令会读取刚刚恢复的 `ra` 并进入 `forkret`，后者调用 `forkrets` 把栈指针 `sp` 切换到当前线程的 `trapframe` 并跳转到 `__trapret`。`__trapret` 复用 Lab3 的 `RESTORE_ALL` 恢复通用寄存器以及 `sstatus`、`sepc` 后执行 `sret`，硬件根据 `sepc` 跳转到 `kernel_thread_entry`。该汇编入口把参数寄存器 `s1` 移入 `a0`，再通过 `jalr s0` 调用目标函数 `init_main`，函数返回后继续调用 `do_exit`。

## 四、Spec 与 Prompt 设计

我们在编写提示词生成各模块代码前，先针对三个核心模块梳理了输入输出规格与边界不变量，并将其写入 [prompt.md](prompt.md) 约束生成结果。

1. **虚拟内存页操作模块** Spec 定义了 `page_insert` 与 `page_remove` 的参数语义、返回码以及页表项、引用计数、TLB 三者同步的不变量。Prompt 要求明确区分首次映射、同页重映射、异页替换三种分支，禁止同页重映射时误释放物理页，禁止覆盖权限时残留旧权限位，同时要求 `page_remove` 在目标地址无映射时直接返回且禁止创建中间级页表。
2. **线程创建与初始化模块** Spec 规定了 `alloc_proc` 各字段的确定初值、`proc_init` 中 `idleproc` 与 `initproc` 的建立顺序以及 `do_fork` 在失败路径上的资源清理原则。Prompt 要求保持 `copy_mm`、`copy_thread` 与 `do_fork` 的函数边界独立，明确将 `trapframe` 放置在 8 KiB 内核栈顶部，并将 `s0`、`s1`、`epc` 和 `context.ra` 与 `forkret` 及 `kernel_thread_entry` 的汇编约定严格对齐。
3. **线程调度与上下文切换模块** Spec 将调度策略与底层切换解耦，`schedule` 只负责挑选就绪线程，`proc_run` 负责在临界区内更新 `current` 与地址空间，`switch_to` 只按结构体偏移读写寄存器。Prompt 明确规定了关中断保护、无就绪线程时回退 `idleproc`、目标等于当前线程时跳过切换，同时提示不要使用 `riscv.h` 中遗留的 Sv32 `lsatp` 宏，而是按 Sv39 格式构造 `satp` 并刷新 TLB，并在 `switch.S` 中按顺序处理 14 个寄存器槽位。

## 五、调试问题与处理

在生成代码与本地验证过程中，我们遇到了以下四类问题并通过逐项排查完成修复。

1. **评分脚本的 GDB 架构识别异常** 最初在本地运行 `make grade GDB=gdb-multiarch` 时得分为 0，串口输出文件为空。单独复现脚本生成的 GDB 连接命令后，终端提示目标架构描述被拒绝且远程寄存器数据包截断，导致调试器在内核启动前就断开连接。我们编写了本地 GDB 启动脚本，在连接前显式设置 `riscv:rv64` 架构并加载 `bin/kernel`，调整后三组自动测试全部通过，实验源码和官方评分脚本均保持原样。
2. **`page_insert` 同页重映射与 TLB 刷新顺序问题** 初版代码在更新映射时先递减旧页引用计数再递增新页引用计数，当对同一物理页修改权限时，引用计数会短暂降为零并触发 `free_page` 造成页面误回收。此外，写入新表项与调用 `tlb_invalidate` 之间缺少内存屏障，存在编译器重排风险。修改后先比较旧表项对应的物理页与传入参数 `page`，相同时仅覆写权限位，不相同时先增加新页引用并写入新表项，随后通过内存屏障与 `tlb_invalidate` 处理刷新顺序，最后再减少旧页引用计数。
3. **`proc_run` 写入 `satp` 缺少 Sv39 模式位** 早期生成的 `proc_run` 直接调用了头文件中的 `lsatp`，该接口使用 32 位参数和 Sv32 的模式位，未按 RV64 的 Sv39 格式设置 `satp` 高 4 位，切换线程后导致分页翻译失效。参照 `pmm.c` 中 `enable_paging` 的实现，改为把 `SATP_MODE_SV39` 左移 60 位后与页表物理页号按位或，写入 `satp` 后再执行 `flush_tlb`。
4. **`copy_thread` 内核栈顶位置与返回值寄存器遗漏** 初版 `copy_thread` 计算 `trapframe` 地址时直接使用了 `kstack` 起始低地址而非从 `kstack + KSTACKSIZE` 向下偏移，且遗漏将子线程 `tf->gpr.a0` 清零。修正后从内核栈顶部预留 `sizeof(struct trapframe)` 空间，并将 `a0` 置为 0，确保新线程启动后拥有完整的栈空间与正确的返回状态。

## 六、扩展练习 Challenge

### 6.1 `local_intr_save` 与 `local_intr_restore` 开关中断机制

这两个宏定义在 [kern/sync/sync.h](../code/kern/sync/sync.h) 中。进入临界区时，`local_intr_save` 先读取 `sstatus` 寄存器的 `SIE` 位。如果进入前中断处于开启状态，则清除 `SIE` 位关闭中断并把标志变量 `intr_flag` 置为 1，如果进入前本就处于关闭状态，则保持关闭并把 `intr_flag` 记为 0。离开临界区时，`local_intr_restore` 判断 `intr_flag` 是否为 1，仅当进入前原本开中断时才重新开启中断。

这种设计能够保证临界区嵌套时不会破坏外层的中断屏蔽状态。例如 `schedule` 关闭中断后调用 `proc_run`，内层 `local_intr_save` 记录到的 `intr_flag` 为 0，因此 `proc_run` 返回前执行 `local_intr_restore` 不会提前打开外层临界区的中断。需要注意的是，该机制仅控制当前硬件线程的本地中断，多核并发访问共享数据时仍需配合自旋锁等同步原语。

### 6.2 Sv32、Sv39、Sv48 对比与 `get_pte` 的重复结构

三种分页模式的核心参数对比如下。

| 分页模式 | 页表层数 | 虚拟页号索引 | 页内偏移 | PTE 大小 | 每页表项数 |
| --- | --- | --- | --- | --- | --- |
| Sv32 | 2 | 10 + 10 位 | 12 位 | 4 字节 | 1024 |
| Sv39 | 3 | 9 + 9 + 9 位 | 12 位 | 8 字节 | 512 |
| Sv48 | 4 | 9 + 9 + 9 + 9 位 | 12 位 | 8 字节 | 512 |

三种模式的基本页大小均为 4 KiB，每一级地址翻译的操作逻辑一致，都是根据当前层级的虚拟页号索引找到对应表项，检查有效位并在需要创建时分配下一级页表页，随后取出物理页号进入下一级目录。Sv39 采用三级页表结构，`get_pte` 需要先从根页表定位第二级目录，再从第二级目录定位末级页表，这两段逐级索引与按需分配的处理过程遵循相同的规则，因此代码结构呈现出高度的对称性。

### 6.3 查找与分配是否应该拆开

当前实现通过 `create` 参数将页表查找与中间页表分配合并在 `get_pte` 中，插入映射时允许补建缺失的中间级页表，查询和删除时只执行遍历查找。这种写法在单次遍历中就能完成目标表项定位，对外接口数量少，调用逻辑直观。

当后续需要支持多级页表分配失败后的自动回滚、更细粒度的权限检查或独立只读查询测试时，把两个职责拆开会更加合理。具体做法是在内部保留共用的逐级索引辅助逻辑，对外提供只读查找接口与带失败回收能力的页表创建接口，这样在第二级页表分配失败时能够顺畅回收第一级刚分配的中间页表页。

## 七、测试方法与结果

### 7.1 普通启动

进入 `code` 目录配置 QEMU 路径并启动内核。

```bash
cd /home/huang/OS/lab4/code
export PATH=/home/huang/OS/tools/qemu-4.1.1/riscv64-softmmu:$PATH
make qemu
```

内核启动后依次通过物理页分配、多级页表、动态内存分配器以及 VMA 管理自检，随后 `idleproc` 主动让出 CPU，调度器切换到 `initproc` 并打印出线程信息与输出字符串。

```text
this initproc, pid = 1, name = "init"
To U: "Hello world!!".
To U: "en.., Bye, Bye. :)"
kernel panic at kern/process/proc.c:208:
    process exit!!.
```

上述输出说明 `initproc` 已经在独立的内核栈和执行现场上正常运行。`init_main` 返回后，`kernel_thread_entry` 调用当前仅包含 `panic` 的 `do_exit` 并进入内核监视器。按下 `Ctrl+A` 后再按 `X` 即可退出 QEMU。

### 7.2 官方评分

使用 QEMU 4.1.1，并显式指定 GDB 的 RV64 架构与内核符号。先创建临时 GDB 启动器，再执行官方评分：

```bash
cd /home/huang/OS/lab4/code
export PATH=/home/huang/OS/tools/qemu-4.1.1/riscv64-softmmu:$PATH
cat > /tmp/lab4-gdb-rv64 <<'SH'
#!/bin/sh
exec gdb-multiarch -ex "set architecture riscv:rv64" -ex "file bin/kernel" "$@"
SH
chmod +x /tmp/lab4-gdb-rv64
make grade GDB=/tmp/lab4-gdb-rv64
```

[tools/inject.py](../code/tools/inject.py) 会将 [tools/test_lab4.c](../code/tools/test_lab4.c) 注入临时副本中，分别在 `pmm_init` 末尾、`proc_init` 末尾以及 `init_main` 入口运行三组检查，原始实验源码保持不变。

| 测试 | 核心检查 | 得分 |
| --- | --- | --- |
| PMM | 映射建立、替换、权限更新与引用计数 | 10/10 |
| Process Create | 线程控制块、内核栈与初始上下文 | 10/10 |
| Schedule | 多线程创建与主动让出轮转调度 | 10/10 |
| 合计 | 三组检查全部通过 | **30/30** |

终端实际评分输出如下。

```text
  -check PMM:                                OK
  -check Process Create:                     OK
  -check Schedule:                           OK
Total Score: 30/30
```

普通启动和评分的关键输出已列在本节。未显式指定目标架构时，GDB 原始报错为：

```text
warning: Architecture rejected target-supplied description
Truncated register 37 in remote 'g' packet
```

## 八、重要知识点与 OS 原理的联系

1. **虚拟地址空间与硬件页表映射** 操作系统原理中将进程地址空间的逻辑布局与底层页表的物理映射区分开来。本实验通过 `mm_struct` 和 `vma_struct` 管理虚拟内存区间的起止范围与访问属性，通过 `get_pte`、`page_insert` 和 `page_remove` 维护硬件页表项与 TLB 一致性，体现了逻辑描述层与硬件翻译层的配合。差异在于当前仅完成了内核线程共享内核页表的框架，用户进程的独立页表与缺页按需分配尚未接入。
2. **进程控制块与执行上下文** 原理中的进程控制块用于集中描述执行实体的状态、标识与资源，上下文切换则负责保存和恢复处理器现场。实验中 `proc_struct` 承担控制块功能，同时把执行现场细分为两类结构，服务于函数调用边界主动切换的 112 字节 `context`，以及服务于硬件中断、异常和线程首次启动的 288 字节 `trapframe`，体现了不同切换时机下的现场保存开销差异。
3. **调度策略与切换机制分离** 原理中通常把决定下一个运行者的调度策略与执行寄存器替换的切换机制解耦。实验中 `schedule` 负责扫描 `proc_list` 选出就绪线程，`proc_run` 与 `switch_to` 则专注于更新 `current`、切换 `satp` 与替换寄存器状态。差异在于当前仅实现了基于链表顺序的协作式轮转调度，尚未引入时钟时间片计数。

## 九、OS 原理中重要但本实验尚未实现的内容

1. **用户进程与独立地址空间隔离** 当前所有线程都运行在 S 态并共享同一份内核页表 `boot_pgdir_pa`。要支持完整的用户进程，后续还需要实现用户程序镜像加载、独立用户页表创建、用户态栈分配以及 U 态与 S 态之间的系统调用切换机制。
2. **基于时间片的抢占式调度** 本实验中的线程切换依赖 `cpu_idle` 或测试线程主动调用 `schedule` 让出 CPU。在实际操作系统中，还需要在时钟中断处理流程里统计时间片消耗，并在中断返回前安全触发重调度，避免单个计算密集型线程长期占用处理器。
3. **完整的进程退出与资源回收** 目前 `init_main` 执行结束后进入 `do_exit`，触发 `panic` 并进入内核监视器。完整的进程生命周期管理还需要实现 `PROC_ZOMBIE` 僵尸状态转换、父进程通过 `wait` 系列接口等待并回收子进程退出状态，以及内核栈、地址空间和进程控制块内存的安全释放。

## 十、AI 协作开发的经验总结

1. **先写清状态不变量，再生成实现。** 页映射要同步维护 PTE、引用计数和 TLB；线程创建要在资源准备完成后再登记到全局链表。把这些条件写进 Spec，便于逐项检查生成结果。
2. **跨模块的约定要一起提供。** `context` 的字段顺序、Trap 帧位置和 `s0`、`s1`、`epc` 的用途共同决定首次运行链路。Prompt 需要给出 C 结构体和汇编入口约定，让生成代码保持一致。
3. **结合具体测试判断问题所在。** PMM、线程创建和调度测试分别检查对应模块；出现零分时还要检查 QEMU 是否启动、GDB 是否连接。借助日志定位到具体环节，再调整实现或环境参数。
