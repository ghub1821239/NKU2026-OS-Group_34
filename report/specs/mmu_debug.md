# 分支任务：地址翻译调试 spec

使用独立编译、带调试信息的 QEMU 4.1.1；系统 QEMU 保持原安装状态。

1. 宿主 GDB 启动 QEMU 子进程，客体 GDB 通过独立端口控制 RISC-V 内核。该方式允许在普通用户的 ptrace 限制下调试自己启动的子进程。
2. 选择 `dtb_init()` 中读取 DTB magic 的真实 `lw` 指令，在执行前记录客体 PC、地址寄存器与 `satp`。
3. 对该地址设置条件断点，记录 `load_helper`、`tlb_fill`、`riscv_cpu_tlb_fill`、`get_physical_address` 和 `tlb_set_page` 的调用关系。
4. 在页表查询过程中单步查看模式、根表物理地址、级数、索引、PTE 地址、PTE 内容和翻译结果。
5. 分别记录 Bare 模式下的软件 TLB 回填、Sv39 下的缺失回填、victim TLB 恢复和主表命中。
6. 记录主表 `addend`，区分客体物理地址与宿主访问 RAM 的指针。
7. 保存两侧 GDB 命令、输出和 QEMU 串口日志。结束时回收本次启动的进程。

脚本使用原版 QEMU 4.1.1 的源码行号；其他版本需要重新对照源码调整断点。
