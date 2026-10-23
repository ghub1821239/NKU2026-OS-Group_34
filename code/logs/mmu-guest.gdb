set pagination off
set confirm off
set architecture riscv:rv64
set trace-commands on
file bin/kernel
target remote 127.0.0.1:2234
thbreak *0xffffffffc020028a
continue
printf "\nGUEST: DTB load instruction before execution\n"
info registers pc a4 satp sp
x/i $pc
thbreak kern/init/init.c:58
continue
printf "\nGUEST: Initialization and allocation checks completed\n"
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
