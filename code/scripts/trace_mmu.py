#!/usr/bin/env python3
"""Run a host GDB and a guest GDB together against debug QEMU 4.1.1."""
import argparse
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import time

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--qemu-source', type=Path,
                    default=root.parent.parent / 'tools/qemu-4.1.1')
parser.add_argument('--port', type=int, default=2234)
args = parser.parse_args()
source = args.qemu_source.resolve()
qemu = source / 'riscv64-softmmu/qemu-system-riscv64'
version = subprocess.check_output([str(qemu), '--version'], text=True)
assert '4.1.1' in version, 'This source-level trace uses QEMU 4.1.1 locations.'
subprocess.run(['make'], cwd=root, check=True)
boot_log = root / 'logs/boot-qemu4-128M.log'
if not boot_log.exists():
    subprocess.run(['python3', 'scripts/check_boot.py', '--qemu', str(qemu),
                    '--label', 'qemu4', '--memory', '128'], cwd=root, check=True)
dtb_pa = int(re.search(r'DTB Address: 0x([0-9a-fA-F]+)',
                      boot_log.read_text()).group(1), 16)
dtb_va = (dtb_pa + 0xffffffff40000000) & ((1 << 64) - 1)
disassembly = subprocess.check_output([
    'riscv64-unknown-elf-objdump', '-d', 'bin/kernel'], cwd=root, text=True)
dtb_body = disassembly.split('<dtb_init>:', 1)[1].split('\n\n', 1)[0]
load_pc = int(re.search(r'^([0-9a-f]+):.*\blw\s+a5,0\(a4\)',
                        dtb_body, re.M).group(1), 16)
kernel_page = load_pc & ~0xfff
loop_line = next(i for i, line in enumerate(
    (root / 'kern/init/init.c').read_text().splitlines(), 1)
    if re.match(r'\s*while\s*\(1\)', line))
cpu = source / 'target/riscv/cpu_helper.c'
tlb = source / 'accel/tcg/cputlb.c'
logs = root / 'logs'
host_commands = f'''set pagination off
set confirm off
set debuginfod enabled off
set print thread-events off
set startup-with-shell off
handle SIGPIPE nostop noprint pass
set trace-commands on
break get_physical_address if addr == 0x80200000 && mmu_idx == 1 && access_type == 2 && env->satp == 0
run
printf "\\nPHASE: Bare-mode instruction fetch\\n"
bt 5
p/x addr
p/x env->satp
until {cpu}:197
next
p/x *physical
finish
break tlb_set_page if vaddr == 0x80200000 && mmu_idx == 1
continue
printf "\\nPHASE: Software TLB fill also happens in Bare mode\\n"
p/x vaddr
p/x paddr
p mmu_idx
delete breakpoints
break load_helper if addr == {dtb_va:#x}
continue
printf "\\nPHASE: DTB load and software TLB miss\\n"
bt 6
p/x addr
until {tlb}:1271
p/x tlb_addr
p/x entry->addr_read
p/x addr & ~0xfffUL
delete breakpoints
break get_physical_address if addr == {dtb_va:#x} && access_type == 0
continue
printf "\\nPHASE: Sv39 page-table walk\\n"
bt 6
p/x env->satp
p/x addr
p access_type
p mmu_idx
until {cpu}:237
p levels
p ptidxbits
p ptesize
p/x base
p ptshift
until {cpu}:254
p i
p/x idx
p/x pte_addr
p/x pte
next
p/x ppn
until {cpu}:334
p ptshift
next
p/x *physical
finish
p/x pa
delete breakpoints
break tlb_set_page if vaddr == {dtb_va:#x}
continue
printf "\\nPHASE: Fill virtual/physical mapping and host addend\\n"
p/x vaddr
p/x paddr
p prot
p mmu_idx
step
until {tlb}:804
p/x addend
p/x vaddr_page
next
p/x tn.addend
until {tlb}:836
p/x tn.addr_read
p/x tn.addr_code
p/x tn.addend
next
p/x te->addr_read
p/x te->addend
delete breakpoints
break {tlb}:1030 if addr >= {kernel_page:#x} && addr < {kernel_page + 4096:#x} && env->priv == 1
continue
printf "\\nPHASE: Direct-mapped TLB collision and victim-cache recovery\\n"
p/x addr
p/x entry->addr_code
p/x entry->addend
printf "TLB_DIRECT_HIT=%d\\n", entry->addr_code == (addr & ~0xfffUL)
next
next
p/x entry->addr_code
until {tlb}:1051
next
p/x p
delete breakpoints
break {tlb}:1030 if addr >= {kernel_page:#x} && addr < {kernel_page + 4096:#x} && env->priv == 1 && entry->addr_code == (addr & ~0xfffUL)
continue
printf "\\nPHASE: Real instruction TLB hit\\n"
p/x addr
p/x entry->addr_code
printf "TLB_DIRECT_HIT=%d\\n", entry->addr_code == (addr & ~0xfffUL)
next
until {tlb}:1051
next
p/x p
printf "\\nPHASE: Trace complete; return control to guest GDB\\n"
detach
quit
'''
guest_commands = f'''set pagination off
set confirm off
set architecture riscv:rv64
set trace-commands on
file bin/kernel
target remote 127.0.0.1:{args.port}
thbreak *{load_pc:#x}
continue
printf "\\nGUEST: DTB load instruction before execution\\n"
info registers pc a4 satp sp
x/i $pc
thbreak kern/init/init.c:{loop_line}
continue
printf "\\nGUEST: Initialization and allocation checks completed\\n"
info registers pc sp satp
p/x va_pa_offset
p/x pages
p/x npage
p/x nbase
p/d sizeof(struct Page)
p pmm_manager->name
set $free_total = 0
set $order = 0
while $order < 32
  set $free_total = $free_total + 'bs_pmm.c'::free_area[$order].nr_free
  set $order = $order + 1
end
p/d $free_total
detach
quit
'''
(logs / 'mmu-host.gdb').write_text(host_commands)
(logs / 'mmu-guest.gdb').write_text(guest_commands)
with socket.socket() as check:
    check.bind(('127.0.0.1', args.port))
host = None
guest = None
qemu_pid = None
try:
    with (logs / 'mmu-host.log').open('w') as host_out, \
         (logs / 'mmu-guest.log').open('w') as guest_out:
        host = subprocess.Popen([
            'gdb', '-q', '-nx', '-batch', '-x', str(logs / 'mmu-host.gdb'),
            '--args', str(qemu), '-machine', 'virt', '-m', '128',
            '-nographic', '-bios', 'default', '-kernel', str(root / 'bin/ucore.img'),
            '-serial', 'file:' + str(logs / 'mmu-qemu.log'), '-monitor', 'none',
            '-S', '-gdb', 'tcp:127.0.0.1:' + str(args.port),
        ], cwd=root, stdout=host_out, stderr=subprocess.STDOUT,
            start_new_session=True)
        deadline = time.monotonic() + 15
        while True:
            if host.poll() is not None:
                raise RuntimeError((logs / 'mmu-host.log').read_text())
            try:
                with socket.create_connection(('127.0.0.1', args.port), .1):
                    break
            except OSError:
                if time.monotonic() > deadline:
                    raise TimeoutError('QEMU debug port did not open')
                time.sleep(.05)
        child_pids = subprocess.check_output([
            'ps', '--ppid', str(host.pid), '-o', 'pid='], text=True).split()
        for child in child_pids:
            if (Path('/proc') / child / 'exe').resolve() == qemu:
                qemu_pid = int(child)
                break
        if qemu_pid is None:
            raise RuntimeError('Could not identify the owned QEMU child')
        guest = subprocess.Popen([
            'gdb-multiarch', '-q', '-nx', '-batch', '-x',
            str(logs / 'mmu-guest.gdb'),
        ], cwd=root, stdout=guest_out, stderr=subprocess.STDOUT,
            start_new_session=True)
        host.wait(timeout=45)
        if host.returncode != 0:
            raise RuntimeError((logs / 'mmu-host.log').read_text())
        guest.wait(timeout=15)
        if guest.returncode != 0:
            raise RuntimeError((logs / 'mmu-guest.log').read_text())
finally:
    if qemu_pid is not None:
        try:
            os.kill(qemu_pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    for process in (guest, host):
        if process is not None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            if process.poll() is None:
                process.wait(timeout=5)
host_text = (logs / 'mmu-host.log').read_text()
guest_text = (logs / 'mmu-guest.log').read_text()
assert 'PHASE: Trace complete' in host_text
assert '\nTLB_DIRECT_HIT=0\n' in host_text
assert '\nTLB_DIRECT_HIT=1\n' in host_text
assert 'Initialization and allocation checks completed' in guest_text
assert 'check_alloc_page() succeeded!' in (logs / 'mmu-qemu.log').read_text()
print('Dual GDB trace: PASS')
print('DTB instruction PC=%#x, VA=%#x -> PA=%#x' % (load_pc, dtb_va, dtb_pa))
print('Logs: logs/mmu-host.log, logs/mmu-guest.log, logs/mmu-qemu.log')
