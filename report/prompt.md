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
