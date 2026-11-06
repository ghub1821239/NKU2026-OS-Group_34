# 操作系统实验报告

## 实验基本信息

| 项目 | 内容 |
| --- | --- |
| **实验名称** | Lab3：中断与异常处理|
| **小组成员** | 焦宇堃、黄国天、徐夏茗 |
| **完成日期** | 2026 年 11 月 2 日 |

### 小组分工

实现与验证分工：

| 成员 | 负责的练习与模块 |
| --- | --- |
| 焦宇堃 | 功能模块二中断部分：`interrupt_handler` 中断分发、`IRQ_S_TIMER` 时钟事件设置、`ticks` 计数与 `SHUTDOWN_AFTER` 关机逻辑的实现及测试验证|
| 黄国天 | Lab2 物理内存代码迁移；功能模块一：`trapentry.S` 中 `RESTORE_ALL` 宏与 `__alltraps` 参数传递及函数调用的实现|
| 徐夏茗 | 功能模块二异常部分：`exception_handler` 异常处理、非法指令与断点异常捕获、指令长度判断与 `tf->epc` 更新的实现|

报告分工：

| 成员 | 负责的报告部分 |
| --- | --- |
| 焦宇堃 | 功能模块二中断处理部分实现说明、对应 Prompt 与 Bug 记录、测试结果与截图整理 |
| 黄国天 | 功能模块一 Trap 上下文保存与恢复实现说明、对应 Prompt 与 Bug 记录、AI 协作经验总结 |
| 徐夏茗 | 实验整体逻辑分析、功能模块二异常处理部分实现说明与 Bug 记录、实验知识点与 OS 原理对比 |

---

## 一、实验目的

1. 了解 RISC-V 架构下的中断与异常机制，理解触发 Trap 时 `scause`、`sepc`、`sbadaddr` 即 `stval`、`sstatus` 等控制状态寄存器的作用。


2. 理解内核如何通过 `trapentry.S` 中的 `SAVE_ALL` 和 `RESTORE_ALL` 宏在内核栈上保存和恢复 `struct trapframe` 上下文环境。


3. 掌握 C 语言层面的中断与异常分发流程，实现 S 态时钟中断的周期性触发、计数打印与关机退出。


4. 掌握非法指令异常和断点异常的处理方法，结合 RISC-V 压缩指令与标准指令的编码规则正确更新 `tf->epc`。

## 二、实验环境

| 项目 | 配置详情 |
| --- | --- |
| 系统环境 | Ubuntu 22.04.5 LTS，WSL2，x86_64 |
| 目标架构 | RISC-V RV64，QEMU virt，128 MiB RAM |
| 交叉编译器 | riscv64-unknown-elf-gcc 10.2.0 |
| 模拟器与固件 | QEMU 4.1.1，OpenSBI v0.4 |
| 调试器与构建工具 | gdb-multiarch 12.1，GNU Make 4.3 |

小组使用的 AI 工具：

| 成员 | AI 编程工具 | 底层模型 |
| --- | --- | --- |
| 焦宇堃 | Claude Code | DeepSeek-V4-Flash |
| 黄国天 | Claude Code | DeepSeek-V4-Flash |
| 徐夏茗 | Claude Code | DeepSeek-V4-Flash |

---

## 三、实验整体逻辑分析

### 3.1 本章节的逻辑主线

本次实验围绕 uCore 的中断与异常处理流程展开。在前面的实验中，内核完成物理内存初始化后便停留在 `kern_init` 末尾的空循环里，还不具备响应外部设备中断或处理执行异常的能力。本实验沿着 Trap 上下文保存与恢复、Trap 入口与返回、中断与异常处理三条主线，补全了从触发 Trap、保存寄存器现场、进入 C 函数分发处理，到恢复现场并返回原执行流的完整过程。

结合 `kern/init/init.c` 中的 `kern_init` 函数可以看出，整个中断处理机制按以下顺序建立并运行：

首先，内核从 `entry.S` 进入 `kern_init`，清零 BSS 段并初始化控制台，随后调用 `kern/trap/trap.c` 中的 `idt_init` 初始化中断向量表。`idt_init` 先将 `sscratch` 寄存器置为 0，表示当前处于内核态，再将 `trapentry.S` 中汇编入口 `__alltraps` 的地址写入 `stvec` 寄存器，使所有中断和异常都跳转到该统一入口。接着，内核完成物理内存初始化后调用 `kern/driver/clock.c` 中的 `clock_init`，通过设置 `sie` 寄存器的 `MIP_STIP` 位开启 S 态时钟中断，并调用 `clock_set_next_event` 向 OpenSBI 发起调用以设定第一次时钟中断事件，同时将全局计数器 `ticks` 清零。最后，内核调用 `intr_enable` 将 `sstatus` 寄存器的 `SIE` 位置设为 1，开启 S 态全局中断使能，随后进入死循环等待中断触发。

当定时器到期触发时钟中断，或者处理器执行到断点指令、非法指令时，硬件自动将当前指令地址写入 `sepc`，将触发原因写入 `scause`，把异常附加信息写入 `stval`，并将 `sstatus.SIE` 保存到 `sstatus.SPIE` 后清零 `sstatus.SIE` 以关闭中断，再将 `pc` 设置为 `stvec` 指向的 `__alltraps` 入口。

进入 `__alltraps` 后，`SAVE_ALL` 宏先在当前内核栈上开辟 36 个寄存器大小的空间，把 32 个通用寄存器以及 `sstatus`、`sepc`、`sbadaddr`、`scause` 四个 CSR 依次保存到栈上，构造出一个 `struct trapframe` 结构体。接着汇编代码将当前栈顶指针 `sp` 放入 `a0` 寄存器作为参数，调用 C 函数 `trap`。

在 `kern/trap/trap.c` 中，`trap` 函数调用 `trap_dispatch`，根据 `tf->cause` 最高位是否为 1 区分中断与异常：若转换为有符号数后小于 0，说明最高位为 1，属于外部异步中断，交由 `interrupt_handler` 处理；若大于等于 0，说明最高位为 0，属于同步异常，交由 `exception_handler` 处理。处理函数执行完毕后逐层返回到 `trapentry.S` 的 `__trapret` 标签，由 `RESTORE_ALL` 宏从栈上的 `trapframe` 恢复被修改的 CSR 和通用寄存器，最后执行 `sret` 指令，将 `sepc` 写回 `pc` 并恢复中断使能状态，回到被打断的位置继续执行。

### 3.2 功能的逐步实现

整个实验的功能实现可以分为四个前后衔接的阶段：

第一阶段是中断入口与时钟初始化，涉及 `trap.c` 的 `idt_init`、`clock.c` 的 `clock_init` 以及 `intr.c` 的 `intr_enable`。这一阶段通过配置 `stvec`、`sie` 和 `sstatus` 寄存器，让硬件知道发生 Trap 时应当跳转到何处执行，并发出第一个时钟中断请求，为后续 Trap 的触发做好硬件准备。

第二阶段是上下文保存与入口跳转，涉及 `trapentry.S` 中的 `SAVE_ALL` 宏与 `__alltraps` 入口。硬件触发 Trap 后只会更新几个特定的控制寄存器，而通用寄存器的值仍保留在处理器中。这一阶段负责在栈上分配空间并保存全部 32 个通用寄存器和 4 个关键 CSR，把零散的寄存器状态组织成 C 语言能够直接访问的 `struct trapframe` 结构体，再通过 `a0` 寄存器把结构体首地址传给 `trap` 函数，搭起从底层汇编到高层 C 代码的桥梁。

第三阶段是中断与异常的分类处理，涉及 `trap.c` 中的 `trap`、`trap_dispatch`、`interrupt_handler` 和 `exception_handler`。这一阶段接收上一阶段传入的 `trapframe` 指针，读取 `tf->cause` 判断事件类型。在时钟中断中完成下一次定时事件设置、计数累加、定时输出和关机控制；在非法指令和断点异常中打印异常地址，并根据指令实际字节长度修改 `tf->epc` 以跳过引发异常的指令。

第四阶段是上下文恢复与 Trap 返回，涉及 `trapentry.S` 中的 `RESTORE_ALL` 宏与 `__trapret`。第三阶段在 C 函数中对 `tf->epc` 所做的修改，此时还只停留在内核栈的内存里。只有在第四阶段通过 `RESTORE_ALL` 将栈上的 `tf->status` 和 `tf->epc` 重新写回硬件的 `sstatus` 和 `sepc` 寄存器，并依次恢复各个通用寄存器和原栈顶指针 `sp`，最后执行 `sret` 指令，修改后的返回地址才能真正生效，使处理器准确回到目标位置继续运行。

---

## 四、实验内容与实现

### 功能模块一：Trap 上下文恢复与 Trap 入口功能

* **负责人**：黄国天
* **涉及文件**：`kern/trap/trapentry.S`



#### 1. 核心函数与功能模块理解

本模块位于 `kern/trap/trapentry.S`，核心任务是实现汇编层的上下文保存、C 函数调用衔接以及上下文恢复，涉及 `SAVE_ALL`、`__alltraps`、`RESTORE_ALL` 和 `__trapret` 四个部分。

框架已经提供的 `SAVE_ALL` 宏定义了上下文保存在内核栈上的布局，与 `kern/trap/trap.h` 中的 `struct trapframe` 结构体完全对应：前 32 个槽位即 `0*REGBYTES(sp)` 至 `31*REGBYTES(sp)` 依次存放通用寄存器 `x0` 到 `x31`，后 4 个槽位即 `32*REGBYTES(sp)` 至 `35*REGBYTES(sp)` 依次存放 `sstatus`、`sepc`、`sbadaddr` 和 `scause`。在 64 位 RISC-V 下每个寄存器占 8 字节，整个 `trapframe` 共占 288 字节。值得注意的是 `SAVE_ALL` 对栈指针 `x2` 即 `sp` 的特殊处理：它先用 `csrw sscratch, sp` 把进入 Trap 前的原 `sp` 暂存到 `sscratch`，随后执行 `addi sp, sp, -36 * REGBYTES` 向下开辟栈帧，在保存完其他通用寄存器后，再借用已经保存过的 `s0` 寄存器通过 `csrrw s0, sscratch, x0` 读出原 `sp` 并存入 `2*REGBYTES(sp)`。

基于这一机制，本模块需要完成两处实现：

第一处是 `__alltraps` 中 `SAVE_ALL` 之后的代码。当 `SAVE_ALL` 执行完毕时，当前栈指针 `sp` 恰好指向栈上新建的 `struct trapframe` 首地址。按照 RISC-V 函数调用约定，函数的第一个参数通过 `a0` 寄存器传递，因此只需执行 `mv a0, sp` 将 `sp` 的值赋给 `a0`，再使用 `jal trap` 调用 C 函数 `trap` 即可。当 `trap` 函数处理完毕返回时，程序会顺着指令流自然进入下方的 `__trapret`。

第二处是 `RESTORE_ALL` 宏，负责在 `__trapret` 中把栈上的 `trapframe` 恢复回各个寄存器。在理解该宏时，需要重点把握两个恢复顺序约束：
首先是先恢复 CSR，再恢复通用寄存器。在 4 个 CSR 中，`sbadaddr` 和 `scause` 仅用于在进入 Trap 时向内核传递异常信息，返回前无需写回硬件；而 `sstatus` 和 `sepc` 在 C 处理函数中可能被修改，例如异常处理会更新 `tf->epc`，因此必须从栈上读出并写回硬件寄存器。由于 RISC-V 不支持直接从内存向 CSR 写入数据，必须先用 `LOAD` 指令将栈上的值读到通用寄存器中，再执行 `csrw` 写入 CSR。如果先恢复了全部通用寄存器，再去借用 `s1` 或 `s2` 中转 CSR，就会把刚刚恢复好的通用寄存器原值冲掉。
其次是必须在最后一条指令恢复 `x2` 即 `sp`。因为整个恢复过程的所有 `LOAD` 指令都依赖当前 `sp` 作为基地址去寻址栈上的 `trapframe`。栈槽 `2*REGBYTES(sp)` 中保存的是进入 Trap 前的旧栈顶地址，一旦提前执行 `LOAD x2, 2*REGBYTES(sp)`，`sp` 就会立刻跳回分配栈帧前的位置，既完成了栈空间的释放，也会导致后续所有基于 `sp` 的偏移寻址全部错位。因此必须先恢复 `x1` 以及 `x3` 到 `x31`，最后再恢复 `x2`。

#### 2. Spec 与 Prompt 设计说明

在设计本模块的 Prompt 和 Spec 时，我们将任务拆分为 `__alltraps` 和 `RESTORE_ALL` 两个独立提示词，确保每次只让 AI 修改一处代码：

* 对于 `__alltraps` 的 Spec 设计：我们在 `rely` 部分指明了 `SAVE_ALL` 执行后 `sp` 指向 `struct trapframe` 首地址这一前提，同时给出了 `void trap(struct trapframe *tf)` 的函数原型和 RISC-V 用 `a0` 传递第一个参数的约定。在 `specification` 的前后置条件中，限制 AI 只做参数传递与函数调用，不要额外调整 `sp`，保证 `trap` 返回后能直接落入 `__trapret`。


* 对于 `RESTORE_ALL` 的 Spec 设计：我们在 `rely` 中完整列出了 `0*REGBYTES(sp)` 到 `35*REGBYTES(sp)` 与各个寄存器的对应关系。为了防止 AI 按寄存器编号机械生成代码，我们在 `specification` 的 Post-Condition 中分三步写明了严格的执行顺序：第一步借用 `s1`、`s2` 恢复 `sstatus` 和 `sepc`；第二步恢复除 `x0` 和 `x2` 以外的通用寄存器；第三步单独执行 `LOAD x2, 2*REGBYTES(sp)` 恢复栈指针。



##### `__alltraps` 的提示词

```text
【prompt】
补全 code/kern/trap/trapentry.S 中 __alltraps 标签下 SAVE_ALL 之后的代码，将栈上的 trapframe 传给 C 函数 trap 并调用，只补全这一处。
【rely】
SAVE_ALL 宏执行完后，当前栈顶指针 sp 指向栈上刚保存好的 struct trapframe 结构体首地址；
C 语言中断处理入口声明为 void trap(struct trapframe *tf)（见 kern/trap/trap.h）；
遵循 RISC-V 函数调用约定（第一个参数通过 a0 寄存器传递）。
【guarantee】
只在 __alltraps 的 #lab3 function1 YOUR CODE 处补全汇编指令，不修改其他代码。
【specification】
Pre-Condition：SAVE_ALL 已在当前栈顶构造好 trapframe，sp 指向该 trapframe 起始位置。
Post-Condition：将 sp 作为第一个参数传给 a0 并调用 trap 函数；trap 返回后 sp 保持不变，顺序落入下方的 __trapret。

```

##### `RESTORE_ALL` 的提示词

```text
【prompt】
补全 code/kern/trap/trapentry.S 中 .macro RESTORE_ALL 内的汇编代码，使其与上方的 SAVE_ALL 对称，从栈上的 trapframe 恢复上下文，只补全这一处。
【rely】
参考同文件上方的 SAVE_ALL 宏以及 kern/trap/trap.h 中的 struct trapframe 布局：
0*REGBYTES(sp) ~ 31*REGBYTES(sp) 对应 x0 ~ x31（其中 2*REGBYTES(sp) 存放的是进入中断前的原 sp）；
32*REGBYTES(sp) 为 sstatus，33*REGBYTES(sp) 为 sepc，34*REGBYTES(sp) 为 sbadaddr，35*REGBYTES(sp) 为 scause。
【guarantee】
只在 .macro RESTORE_ALL 的 #lab3 function1 YOUR CODE 处补全汇编指令，不修改其他代码。
【specification】
Pre-Condition：trap(tf) 已返回，sp 指向栈上的 trapframe 起始地址。
Post-Condition：
1. 先借用通用寄存器（如 s1、s2）通过 LOAD 读取 32*REGBYTES(sp) 和 33*REGBYTES(sp) 并用 csrw 恢复 sstatus 和 sepc（sbadaddr 与 scause 无需恢复）；
2. 用 LOAD 依次恢复 x1 以及 x3 ~ x31 通用寄存器（x0 无需恢复）；
3. 最后一条指令执行 LOAD x2, 2*REGBYTES(sp) 恢复栈指针 sp（因前面的 LOAD 均依赖 sp 寻址，x2 必须在最后恢复）。

```

#### 3. 生成代码过程中的 Bug 与解决

在让 AI 生成 `RESTORE_ALL` 汇编代码的迭代过程中，遇到了两个与恢复顺序相关的 Bug：

* **Bug 1：恢复 CSR 时覆盖了已恢复的通用寄存器**
* **现象**：最初编写提示词时，只要求参照 `SAVE_ALL` 恢复通用寄存器和 CSR，没有规定先后顺序。AI 照搬了 `SAVE_ALL` 先写通用寄存器、后写 CSR 的顺序，先执行了 `x1` 到 `x31` 的 `LOAD`，随后又用 `LOAD s1, 32*REGBYTES(sp)` 和 `csrw sstatus, s1` 去恢复 CSR。运行 `make grade` 时，上下文寄存器检查测试报错失败。
* **原因**：评测脚本会在触发 `ebreak` 前向 `t0` 至 `t6`、`s0` 至 `s11`、`a1` 至 `a7` 写入固定测试值，并在中断返回后逐一比对。AI 先恢复了 `x9` 即 `s1`，紧接着又借用 `s1` 中转 `sstatus` 和 `sepc` 的值，导致返回测试代码时 `s1` 中保存的变成了 `sepc` 的值，破坏了原有的寄存器状态。
* **解决**：修改提示词的 Specification，明确要求先借用 `s1` 恢复 `sstatus` 和 `sepc`，再恢复 `x1` 和 `x3` 至 `x31`，使借用过的 `s1` 在后续步骤中被栈上保存的 `x9` 原值重新覆盖回来。


* **Bug 2：`x2` 按编号顺序提前恢复导致后续访存地址错乱**
* **现象**：初版 AI 生成 `x1` 到 `x31` 的恢复指令时，直接按编号从 `x1` 连续写到了 `x31`，中间包含了 `LOAD x2, 2*REGBYTES(sp)`。编译运行后，第一次进入中断返回时便发生异常卡死。
* **原因**：`x2` 即栈指针 `sp`。`2*REGBYTES(sp)` 存放的是分配栈帧之前的原 `sp` 值。在恢复完 `x1` 后立刻执行 `LOAD x2, 2*REGBYTES(sp)`，会导致 `sp` 马上增加了 `36 * REGBYTES`，后续从 `LOAD x3, 3*REGBYTES(sp)` 到 `LOAD x31, 31*REGBYTES(sp)` 的所有指令都会基于错误的基地址读取内存，读出的全部是越界垃圾数据。


* **解决**：在 Specification 中明确要求跳过 `x2`，等 `x1` 和 `x3` 至 `x31` 全部恢复完毕后，最后一条指令再执行 `LOAD x2, 2*REGBYTES(sp)`。





最终在 `kern/trap/trapentry.S` 中实现的代码如下：

```asm
.macro RESTORE_ALL

    #lab3 function1 2413633
    LOAD s1, 32*REGBYTES(sp)
    csrw sstatus, s1
    LOAD s1, 33*REGBYTES(sp)
    csrw sepc, s1

    LOAD x1, 1*REGBYTES(sp)
    LOAD x3, 3*REGBYTES(sp)
    LOAD x4, 4*REGBYTES(sp)
    LOAD x5, 5*REGBYTES(sp)
    LOAD x6, 6*REGBYTES(sp)
    LOAD x7, 7*REGBYTES(sp)
    LOAD x8, 8*REGBYTES(sp)
    LOAD x9, 9*REGBYTES(sp)
    LOAD x10, 10*REGBYTES(sp)
    LOAD x11, 11*REGBYTES(sp)
    LOAD x12, 12*REGBYTES(sp)
    LOAD x13, 13*REGBYTES(sp)
    LOAD x14, 14*REGBYTES(sp)
    LOAD x15, 15*REGBYTES(sp)
    LOAD x16, 16*REGBYTES(sp)
    LOAD x17, 17*REGBYTES(sp)
    LOAD x18, 18*REGBYTES(sp)
    LOAD x19, 19*REGBYTES(sp)
    LOAD x20, 20*REGBYTES(sp)
    LOAD x21, 21*REGBYTES(sp)
    LOAD x22, 22*REGBYTES(sp)
    LOAD x23, 23*REGBYTES(sp)
    LOAD x24, 24*REGBYTES(sp)
    LOAD x25, 25*REGBYTES(sp)
    LOAD x26, 26*REGBYTES(sp)
    LOAD x27, 27*REGBYTES(sp)
    LOAD x28, 28*REGBYTES(sp)
    LOAD x29, 29*REGBYTES(sp)
    LOAD x30, 30*REGBYTES(sp)
    LOAD x31, 31*REGBYTES(sp)

    LOAD x2, 2*REGBYTES(sp)

    .endm

    .globl __alltraps
    .align(2)
__alltraps:
    SAVE_ALL

    #lab3 function1 2413633
    mv a0, sp          # 将 trapframe 首地址作为第一个参数传给 trap
    jal trap           # 调用 C 函数 trap(struct trapframe *tf)

    .globl __trapret
__trapret:
    RESTORE_ALL
    sret

```

---

### 功能模块二：中断与异常处理功能

* **负责人**：焦宇堃负责 `interrupt_handler` 中断处理部分，徐夏茗负责 `exception_handler` 异常处理部分
* **涉及文件**：`kern/trap/trap.c`



#### 1. 核心函数与功能模块理解

本模块位于 `kern/trap/trap.c`，负责在 `trap_dispatch` 完成中断与异常的初步判断后，分别在 `interrupt_handler` 和 `exception_handler` 中执行具体的分支处理逻辑。

首先是中断处理函数 `interrupt_handler`。当 `trap_dispatch` 判定 `(intptr_t)tf->cause < 0` 时调用该函数。根据 RISC-V 规范，当 Trap 由中断引起时，`scause` 寄存器的最高位即第 63 位被置为 1，其余低位存放具体的异常编码。由于 `libs/riscv.h` 中定义的 `IRQ_S_TIMER` 等中断宏只是纯粹的低位编码数值，例如 `IRQ_S_TIMER` 为 5，因此进入函数后必须先通过 `(tf->cause << 1) >> 1` 将最高位的 1 抹去，得到无符号的中断号 `cause` 后再进入 `switch` 分支。
在 `IRQ_S_TIMER` 分支中，需要配合 `kern/driver/clock.c` 完成三件事：
一是调用 `clock_set_next_event`，通过 `rdtime` 获取当前时间并加上 `timebase`，调用 `sbi_set_timer` 向 OpenSBI 设定下一次时钟中断的触发时刻，因为 OpenSBI 每次调用只设置单次定时事件，如果不重新设置，系统就只能收到一次时钟中断；
二是将全局计数器 `ticks` 加 1，每当 `ticks` 达到 `TICK_NUM` 即 100 的整数倍时，调用 `print_ticks` 输出一行 `100 ticks`；
三是统计打印次数，当累计输出达到 `SHUTDOWN_AFTER` 即 20 次时，调用 `sbi_shutdown` 关机退出。对于其他已知中断类型，按分支输出对应的中断名称；对于无法识别的中断编号，输出未知中断提示并调用 `print_trapframe(tf)` 打印完整的中断帧辅助调试。

其次是异常处理函数 `exception_handler`。当 `(intptr_t)tf->cause >= 0` 时进入该函数，此时 `scause` 最高位为 0，`tf->cause` 本身就是异常编码，可以直接用于 `switch` 判断。本实验要求重点处理非法指令异常 `CAUSE_ILLEGAL_INSTRUCTION` 和断点异常 `CAUSE_BREAKPOINT`。
这两类异常都由当前执行的指令直接触发，硬件保存在 `sepc` 即 `tf->epc` 中的地址正是引发异常的那条指令本身的地址。如果处理函数只打印提示信息而不修改 `tf->epc`，那么 `RESTORE_ALL` 和 `sret` 执行后，处理器会跳回原地址再次执行同一条异常指令，从而陷入无限触发同一异常的死循环。因此，处理完输出后必须将 `tf->epc` 加上当前异常指令的字节长度，使返回地址指向下一条正常指令。由于 RISC-V 支持 RVC 压缩指令集，指令长度可能是 2 字节，例如压缩断点指令 `c.ebreak`，也可能是 4 字节，例如 32 位非法指令。按照 RISC-V 指令编码规则，读取 `tf->epc` 地址处的低 16 位半字，若其最低两位二进制为 `11` 即等于 `0x3`，则为 4 字节标准指令，应当令 `tf->epc += 4`；否则为 2 字节压缩指令，应当令 `tf->epc += 2`。对于其他未要求特殊处理的异常，则在 `default` 分支中直接调用 `print_trapframe(tf)`。

#### 2. Spec 与 Prompt 设计说明

在设计本模块的 Prompt 和 Spec 时，我们同样将 `interrupt_handler` 和 `exception_handler` 拆分为两个独立的提示词：

* 对于 `interrupt_handler` 的 Spec 设计：我们在 `RELY` 中列出了 `clock_set_next_event`、`print_ticks`、`print_trapframe`、`sbi_shutdown` 等已有接口，以及从 `IRQ_U_SOFT` 到 `IRQ_M_EXT` 的全部 12 个中断宏定义。在 `guarantee` 中明确要求定义宏 `#define SHUTDOWN_AFTER 20`。在 `specification` 的 Post-Condition 中，首先强调必须先剥离 `tf->cause` 最高位的中断标志位，随后详细规定了 `IRQ_S_TIMER` 分支中设置下次时钟、累加 `ticks`、每满 `TICK_NUM` 打印以及满 `SHUTDOWN_AFTER` 次关机的完整流程，并给出了其他分支和 `default` 分支的精确输出格式。


* 对于 `exception_handler` 的 Spec 设计：我们在 `RELY` 中给出了 `struct trapframe` 的 `cause` 与 `epc` 字段，以及 `CAUSE_ILLEGAL_INSTRUCTION` 和 `CAUSE_BREAKPOINT` 宏。在 `specification` 的 Post-Condition 中，重点规定了两点：一是精确的十六进制地址打印格式 `0x%016lx`；二是明确写出通过检查 `tf->epc` 处指令机器码最低两位是否为 `11` 即 `0x3` 来决定 `tf->epc` 加 4 还是加 2 的计算规则，避免 AI 直接写死 `+4`。



##### `interrupt_handler` 的提示词

```text
【prompt】
在trap.c的 //lab3 function2 YOUR CODE 处实现中断处理函数 interrupt_handler，不要修改文件中已有的其他函数，同样除此之外不要修改任何其他文件，也不要新增文件，接口
【RELY】
可能会用到的结构体与接口在trap.h、trap.c、clock.h、sbi.h中：
1. trap 帧：struct trapframe *tf
2. 时钟中断打印：static void print_ticks(void)
3. trap 帧打印：void print_trapframe(struct trapframe *tf)
4. 时钟下次中断：void clock_set_next_event(void)
5. 关闭：void sbi_shutdown(void)
6. 中断宏：IRQ_U_SOFT(0), IRQ_S_SOFT(1), IRQ_H_SOFT(2), IRQ_M_SOFT(3), IRQ_U_TIMER(4), IRQ_S_TIMER(5), IRQ_H_TIMER(6), IRQ_M_TIMER(7), IRQ_U_EXT(8), IRQ_S_EXT(9), IRQ_H_EXT(10), IRQ_M_EXT(11)
【guarantee】
在trap.c 中定义宏 #define SHUTDOWN_AFTER 20，并实现：
void interrupt_handler(struct trapframe *tf);
【specification】
Pre-Condition：trap_dispatch 判定 (intptr_t)tf->cause < 0 后调用本函数。
Post-Condition：先拿到tf->cause最高位的中断标志位，再进行分支处理：
case:
1. S 态时钟中断：调用 clock_set_next_event() 设置下一次时钟事件，ticks 加 1；每当 ticks % TICK_NUM == 0 时调用 print_ticks() 输出统计信息，当累计输出次数达到 SHUTDOWN_AFTER时调用 sbi_shutdown() 关机
2. 其他已知中断类型：分别用 cprintf 输出对应中断名称（其中 IRQ_S_SOFT 必须输出 "Supervisor software interrupt\n"）。
3. default（无法识别的中断）：输出 "Unknown interrupt: cause %d\n", (int)cause，并调用 print_trapframe(tf)。

```

##### `exception_handler` 的提示词

```text
【prompt】
在 trap.c 的 //lab3 function2 YOUR CODE 处实现异常处理函数 exception_handler，不要修改文件中已有的其他函数，同样除此之外不要修改任何其他文件，也不要新增文件。
【RELY】
可能会用到的结构体与接口在 trap.h、trap.c、riscv.h 中：
1. trap 帧：struct trapframe *tf（含异常原因 tf->cause、异常指令地址 tf->epc）
2. trap 帧打印：void print_trapframe(struct trapframe *tf)
3. 异常宏：CAUSE_ILLEGAL_INSTRUCTION(2), CAUSE_BREAKPOINT(3) 等（定义见 libs/riscv.h）
【guarantee】
在 trap.c 中实现：
void exception_handler(struct trapframe *tf);
【specification】
Pre-Condition：trap_dispatch 判定 (intptr_t)tf->cause >= 0 后调用本函数。
Post-Condition：根据 tf->cause 进行 switch 分支处理：
case:
1. 非法指令异常（CAUSE_ILLEGAL_INSTRUCTION）：用 cprintf 输出 "Illegal instruction at 0x%016lx\n", tf->epc；随后读取 tf->epc 地址处的指令机器码，若最低两位二进制为 11（即 0x3）则为 4 字节指令（tf->epc += 4），否则为 2 字节压缩指令（tf->epc += 2），跳过该异常指令。
2. 断点异常（CAUSE_BREAKPOINT）：用 cprintf 输出 "Breakpoint at 0x%016lx\n", tf->epc；同样按上述规则将 tf->epc 加 2 或加 4 跳过断点指令。
3. default（其他未要求特殊处理的异常）：直接调用 print_trapframe(tf) 进行兜底输出。

```

最终在 `kern/trap/trap.c` 中实现的代码如下：

```c
//lab3 function2 2413633
#define SHUTDOWN_AFTER 20

void interrupt_handler(struct trapframe *tf) {
    uintptr_t cause = (tf->cause << 1) >> 1;

    switch (cause) {
    case IRQ_U_SOFT:
        cprintf("User software interrupt\n");
        break;
    case IRQ_S_SOFT:
        cprintf("Supervisor software interrupt\n");
        break;
    case IRQ_H_SOFT:
        cprintf("Hypervisor software interrupt\n");
        break;
    case IRQ_M_SOFT:
        cprintf("Machine software interrupt\n");
        break;
    case IRQ_U_TIMER:
        cprintf("User timer interrupt\n");
        break;
    case IRQ_S_TIMER: {
        clock_set_next_event();
        ticks++;
        if (ticks % TICK_NUM == 0) {
            static size_t print_count = 0;
            print_ticks();
            print_count++;
            if (print_count >= SHUTDOWN_AFTER) {
                sbi_shutdown();
            }
        }
        break;
    }
    case IRQ_H_TIMER:
        cprintf("Hypervisor timer interrupt\n");
        break;
    case IRQ_M_TIMER:
        cprintf("Machine timer interrupt\n");
        break;
    case IRQ_U_EXT:
        cprintf("User external interrupt\n");
        break;
    case IRQ_S_EXT:
        cprintf("Supervisor external interrupt\n");
        break;
    case IRQ_H_EXT:
        cprintf("Hypervisor external interrupt\n");
        break;
    case IRQ_M_EXT:
        cprintf("Machine external interrupt\n");
        break;
    default:
        cprintf("Unknown interrupt: cause %d\n", (int)cause);
        print_trapframe(tf);
        break;
    }
}

void exception_handler(struct trapframe *tf) {
    switch (tf->cause) {
    case CAUSE_ILLEGAL_INSTRUCTION: {
        cprintf("Illegal instruction at 0x%016lx\n", tf->epc);
        uint16_t insn = *(volatile uint16_t *)tf->epc;
        tf->epc += (insn & 0x3) == 0x3 ? 4 : 2;
        break;
    }
    case CAUSE_BREAKPOINT: {
        cprintf("Breakpoint at 0x%016lx\n", tf->epc);
        uint16_t insn = *(volatile uint16_t *)tf->epc;
        tf->epc += (insn & 0x3) == 0x3 ? 4 : 2;
        break;
    }
    default:
        print_trapframe(tf);
        break;
    }
}

```

---

## 五、测试与验证

### 5.1 测试方法与评分脚本说明

`tools/grade.sh` 与 `tools/inject.py` 从三个维度对实验代码进行测试：

1. `trap entry, register restore, and breakpoint EPC` 占 35 分：调用 `tools/test_lab3_context.S` 中的 `test_lab3_register_context`，在触发 `ebreak` 前向 `t0` 至 `t6`、`s0` 至 `s11`、`a1` 至 `a7` 写入预设数值，从断点异常返回后逐个检查这些寄存器是否与陷入前完全一致，并验证断点地址输出和 `epc` 更新是否正确。
2. `illegal instruction EPC advance and return` 占 25 分：执行一条 4 字节非法指令 `.word 0x0000007b`，检查内核能否输出预期格式的非法指令地址并将 `epc` 加 4 跳过该指令继续执行，同时验证 `IRQ_S_SOFT`、未知中断和其他异常分支的输出。
3. `re-armed supervisor timer and repeated trap return` 占 40 分：开启中断前检查 `ticks` 为 0，开启中断后等待 `ticks` 持续累加超过 200，验证定时器重装、连续时钟中断响应以及多次 Trap 返回的正确性。

### 5.2 运行结果与截图

在工程目录下依次执行 `make qemu` 和 `make grade` 进行测试验证：

```bash
cd code
make qemu
make grade

```

执行 `make qemu` 的运行结果如下图所示：

可以看到，内核完成物理内存初始化与分配检查后，输出 `++ setup timer interrupts` 开启时钟中断。随后每隔 100 次时钟中断输出一行 `100 ticks`，累计输出 20 次后调用 `sbi_shutdown` 正常关机退出 QEMU。

执行 `make grade` 的终端评分输出如下：

```text
lab3 injection complete
Building trap entry, register restore, and breakpoint EPC...
Running trap entry, register restore, and breakpoint EPC...
  - trap entry, register restore, and breakpoint EPC: PASS (35/35)
Building illegal instruction EPC advance and return...
Running illegal instruction EPC advance and return...
  - illegal instruction EPC advance and return: PASS (25/25)
Building re-armed supervisor timer and repeated trap return...
Running re-armed supervisor timer and repeated trap return...
  - re-armed supervisor timer and repeated trap return: PASS (40/40)
Total Score: 100/100

```

对应运行截图如下：

三个测试项全部通过，总分为 100/100。

此外，我们还通过 GDB 在 `__alltraps`、`trap`、`__trapret` 和 `sret` 处打断点跟踪了一次完整的时钟中断过程：进入 `__alltraps` 前栈顶 `sp` 为 `0xffffffffc0205ff0`，`scause` 为 `0x8000000000000005`，`sepc` 为 `0xffffffffc020009c`；执行完 `SAVE_ALL` 进入 `trap` 时，参数 `tf` 为 `0xffffffffc0205ed0`，与原栈顶恰好相差 288 字节，且 `tf->gpr.sp` 记录的值正是 `0xffffffffc0205ff0`；执行完 `RESTORE_ALL` 到达 `sret` 前，`sp` 恢复为 `0xffffffffc0205ff0`，执行 `sret` 后 `pc` 准确回到 `0xffffffffc020009c`，验证了栈帧保存与恢复的正确性。

---

## 六、实验总结与收获

### 6.1 本实验中重要的知识点及其与 OS 原理的联系与差异

1. **中断与异常的软硬件协同机制**
* **含义与关系**：OS 原理中，中断与异常是指处理器在遇到外部设备请求或内部指令异常时，暂停当前执行流、转入内核处理程序并在处理结束后返回原程序继续执行的机制。本实验完整实现了这一过程：硬件负责发现中断与异常，自动保存 `sepc`、`scause`、`stval`，更新 `sstatus` 的中断使能位和先前特权级位，并跳转到 `stvec` 入口；软件则负责保存通用寄存器现场、按原因分发处理并恢复现场返回。

* **差异**：传统 x86 架构在触发中断时硬件会自动向栈中压入多个状态寄存器，而 RISC-V 硬件只修改控制寄存器，在栈上开辟空间并保存 32 个通用寄存器的工作完全交由操作系统的汇编代码完成。

2. **处理器上下文保存与中断帧 `struct trapframe`**
* **含义与关系**：OS 原理中的上下文指程序在被打断时刻的寄存器状态集合，保存与恢复上下文是中断处理后能够回到原程序继续执行的基础。本实验中，这一抽象概念具体落实为内核栈上大小为 288 字节的 `struct trapframe` 结构体，以及 `SAVE_ALL` 和 `RESTORE_ALL` 两段汇编宏。
* **差异**：C 语言处理函数拿到的指针 `tf` 直接指向汇编在内核栈上压入的数据块，修改 `tf->epc` 就是修改栈内存，必须依靠后续 `RESTORE_ALL` 将栈上的值写回 `sepc` 寄存器才能改变 `sret` 的返回地址。

3. **异步中断与同步异常的返回地址处理**
* **含义与关系**：OS 原理将事件分为与当前指令无关的异步外部中断和由当前指令触发的同步内部异常。本实验在 `trap_dispatch` 中通过 `scause` 最高位是 1 还是 0 来区分这两类事件。

* **差异**：在实验中可以看到，时钟中断处理完毕后直接返回被打断的指令地址 `sepc` 即可；而断点异常和非法指令异常发生时，`sepc` 指向触发异常的指令本身，必须根据 RISC-V 指令最低两位是否为 `11` 判断该指令占 2 字节还是 4 字节，相应增加 `tf->epc` 才能避免死循环。

### 6.2 OS 原理中重要但本实验尚未涉及的知识点

1. **用户态到内核态的特权级切换与栈切换**：OS 原理中，用户进程运行在用户态并使用用户栈，发生中断或系统调用陷入内核态时，硬件或软件需要将栈指针从用户栈切换到该进程专属的内核栈以保障内核安全。本实验虽然在 `idt_init` 的注释中提到了利用 `sscratch` 区分内核态与用户态的约定，但目前所有代码均运行在 S 态，尚未建立用户态进程，因此还没有实现从 U 态到 S 态的栈切换过程。
2. **基于时钟中断的抢占式进程调度**：OS 原理中，时钟中断处理程序会更新当前运行进程的时间片，并在时间片耗尽时触发调度器切换进程上下文。本实验的时钟中断仅完成了 `ticks` 累加、打印与关机，尚未引入进程控制块与调度队列。
3. **缺页异常处理与按需分页**：OS 原理中，当程序访问未映射的虚拟地址触发缺页异常时，内核应当在异常处理函数中分配物理页、填写页表项并重新执行原访存指令。本实验的 `exception_handler` 对缺页异常仅调用 `print_trapframe` 打印信息，还没有结合虚拟内存管理实现页面分配与恢复。

### 6.3 AI 协作开发的经验总结

1. **汇编代码的寄存器依赖与顺序约束必须在 Specification 中写明**：在生成 `trapentry.S` 的 `RESTORE_ALL` 时，如果只笼统要求恢复上下文，AI 很容易按照 `x1` 到 `x31` 的顺序依次加载，或者在恢复完通用寄存器后再借用 `s1` 写回 CSR。将先恢复 CSR、再恢复除 `x2` 外的通用寄存器、最后恢复 `x2` 的三步顺序明确写入 Post-Condition 后，就能有效避免寄存器覆盖和栈指针提前跳变的问题。


2. **体系结构相关的编码规则需要在提示词中直接给出**：在生成 `exception_handler` 时，如果不说明 RISC-V 存在 2 字节压缩指令，AI 默认会按照定长 4 字节指令编写 `tf->epc += 4`，导致遇到 `c.ebreak` 时跳错地址。把通过指令最低两位是否为 `11` 判断指令长度的规则写进提示词后，生成的代码就能同时兼容压缩指令与标准指令。


3. **先梳理已有接口与评测要求再编写 Prompt**：在动笔写提示词前，先阅读 `trap.h`、`riscv.h` 中的结构体与宏定义，并核对测试脚本对打印字符串格式和 `SHUTDOWN_AFTER` 关机次数的要求，将这些约束整理到 `rely` 和 `specification` 中，能够大幅减少因格式不匹配或漏调接口导致的返工。