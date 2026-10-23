set pagination off
set confirm off
set architecture riscv:rv64
set trace-commands on
file bin/kernel
target remote 127.0.0.1:2235
thbreak *0x80200034
continue
x/gx 0x80205010
set {unsigned long long}0x80205010 = 0
info registers pc satp
si
info registers pc satp
python
try:
    gdb.execute("x/i $pc")
except gdb.error as error:
    print("EXPECTED_UNMAPPED_LOW_PC:", error)
end
set {unsigned long long}0xffffffffc0205010 = 0x200000cf
x/i $pc
thbreak *kern_init
continue
info registers pc scause stval satp
detach
quit
