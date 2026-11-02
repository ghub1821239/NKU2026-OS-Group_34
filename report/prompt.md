# 1. trapentry.S下的提示词：
## 1.1 __alltraps的调用：
```markdown
【prompt】
补全 code/kern/trap/trapentry.S 中 __alltraps 标签下 SAVE_ALL 之后的代码，将栈上的 trapframe 传给 C 函数 trap 并调用，除此之外不要修改任何其他文件，也不允许新增文件&接口，只实现这里的汇编，很简单只要给一个 a0 值然后jal 一下就好
【rely】
SAVE_ALL 宏执行完后，当前栈顶指针 sp 指向栈上刚保存好的 struct trapframe 结构体首地址；
void trap(struct trapframe *tf)（见 kern/trap/trap.h）的调用遵循 RISC-V 函数调用约定
【guarantee】
只在 __alltraps 的 #lab3 function1 YOUR CODE 处补全汇编指令，不修改其他代码。
【specification】
Pre-Condition：SAVE_ALL 已在当前栈顶构造好 trapframe，sp 指向该 trapframe 起始位置。
Post-Condition：将 sp 作为第一个参数传给 a0 并调用 trap 函数；trap 返回后 sp 保持不变，顺序落入下方的 __trapret。
```

## 1.2 RESTORE_ALL:
```markdown
【prompt】
补全trapentry.S中 .macro RESTORE_ALL 内的汇编代码，使其与上方的SAVE_ALL 对称，只不过是反过来，把栈上的 trapframe恢复成原态，同样除此之外不要修改任何其他文件，也不要新增文件/接口。
【rely】
参考同文件上方的 SAVE_ALL 宏以及 kern/trap/trap.h 中的 struct trapframe 布局
【guarantee】
只在 .macro RESTORE_ALL 的 #lab3 function1 YOUR CODE 处补全汇编指令，不修改其他代码。
【specification】
Pre-Condition：trap(tf) 已返回，sp 指向栈上的 trapframe 起始地址。
Post-Condition：
1. 先借用通用寄存器（如 s1、s2）通过 LOAD 读取 32*REGBYTES(sp) 和 33*REGBYTES(sp) 并用 csrw 恢复 sstatus 和 sepc（sbadaddr 与 scause 无需恢复）；
2. 用 LOAD 依次恢复除了 x2 之外的其他寄存器；
3. 最后一条指令执行 LOAD 把 x2 从内存中拿回来
```

# 2. 中断与异常处理：
## 2.1 interrupt_handler：
```markdown
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

## 2.2 exception:
```markdown
【PROMPT】
在 trap.c 的 //lab3 function2 YOUR CODE 处实现异常处理函数 exception_handler，不要修改文件中已有的其他函数，同样除此之外不要修改任何其他文件，也不要新增文件
【RELY】
可能会用到的结构体与接口在 trap.h、trap.c、riscv.h 中：
1. trap 帧：struct trapframe *tf
2. trap 帧打印：void print_trapframe
3. 异常宏：CAUSE_ILLEGAL_INSTRUCTION(2), CAUSE_BREAKPOINT(3) 等（定义见 libs/riscv.h）
【GUARANTEE】
在 trap.c 中实现：void exception_handler(struct trapframe *tf);
【SPECIFICATION】
Pre-Condition：trap_dispatch 判定 (intptr_t)tf->cause >= 0 后调用本函数。
Post-Condition：根据 tf->cause 进行 switch 分支处理：
case:
1. 非法指令异常：用 cprintf 输出 "Illegal instruction at 0x%016lx\n", tf->epc；随后根据 RISC-V 指令编码规则判断 tf->epc 处指令长度看之后处理返回的时候 pc 是+几（肯定不能跳回原 PC，要不然就卡死在这里了）
2. 断点异常：用 cprintf 输出 "Breakpoint at 0x%016lx\n", tf->epc；同样按上述指令编码规则将 tf->epc进行+几，参考RISC-V 指令编码规则
3. 其他未要求特殊处理的异常：直接调用 print_trapframe(tf) 进行输出。
```
