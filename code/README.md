# Lab2 小组合并版

基于[小组仓库 lab2 分支](https://github.com/ghub1821239/NKU2026-OS-Group_34/tree/7281d3bcbd9fd42a6c63c611e436e6e2cc9aa4c4)的 `7281d3b`，合入本机运行与调试支持。

- [完整报告](../report/report.md)
- [小组原始 prompt](../report/prompt.md)
- [实现 spec](../report/specs/)

## 普通运行

在代码目录执行：

```bash
make qemu
```

普通配置使用 Buddy，经 SLUB 大对象路径完成页分配，输出 `check_alloc_page() succeeded!` 后进入循环。QEMU 终端按 Ctrl+A，松开后按 x 退出。

## 小组 Buddy、SLUB 测试

```bash
make test
```

测试配置使用独立的 `obj-test/bin-test`，自动定义 `ucore_test` 并链接小组测试。成功时看到：

```text
[Buddy Test] ALL PASS
[SLUB Test] ALL PASS
```

自动记录结果并结束本次 QEMU：

```bash
python3 scripts/check_group_tests.py
```

## 评分

```bash
make grade
```

在临时副本中定义 `LAB2_GRADE`，选择 Best-Fit 并执行原配检查，本次结果为 `Total Score: 20/20`。评分会清理构建产物，后续运行前执行 `make`。

## 其他验证与调试

```bash
sh scripts/check_allocator.sh
make
python3 scripts/check_boot.py
python3 scripts/check_bootstrap.py
python3 scripts/trace_mmu.py
```

Best-Fit 检查直接编译当前实现，以独立位图模型验证 20000 次操作并启用 ASan、UBSan。启动脚本测试系统 QEMU 的三种 RAM 配置。

双 GDB 使用独立构建的 QEMU 4.1.1，源码路径默认 `/home/huang/OS/tools/qemu-4.1.1`。路径变化时使用：

```bash
python3 scripts/trace_mmu.py --qemu-source /实际路径/qemu-4.1.1
```

脚本从当前内核提取 load 指令与循环位置，从 QEMU 4.1.1 启动记录提取 DTB 地址，保存两侧命令及输出。源码断点按原版 QEMU 4.1.1 配置。

调试版 QEMU 使用官方源码，以 `--target-list=riscv64-softmmu --enable-debug --disable-werror` 配置，关闭文档、图形前端等可选组件，并通过 `/usr/bin/python3` 构建。本机 pixman 开发文件解到独立的 `/home/huang/OS/tools/qemu-deps`。

手动调试内核时，终端一执行 `make debug`，终端二执行 `make gdb`。先在物理入口 `0x80200000` 设置硬件断点，再观察高地址的 `kern_init`。
