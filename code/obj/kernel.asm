
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

0000000080200000 <kern_entry>:
#include <memlayout.h>

    .section .text,"ax",%progbits
    .globl kern_entry
kern_entry:
    la sp, bootstacktop
    80200000:	00003117          	auipc	sp,0x3
    80200004:	00010113          	mv	sp,sp

    tail kern_init
    80200008:	a009                	j	8020000a <kern_init>

000000008020000a <kern_init>:
#include <sbi.h>
int kern_init(void) __attribute__((noreturn));

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
    8020000a:	00003517          	auipc	a0,0x3
    8020000e:	ffe50513          	addi	a0,a0,-2 # 80203008 <edata>
    80200012:	00003617          	auipc	a2,0x3
    80200016:	ff660613          	addi	a2,a2,-10 # 80203008 <edata>
int kern_init(void) {
    8020001a:	1141                	addi	sp,sp,-16 # 80202ff0 <bootstack+0x1ff0>
    memset(edata, 0, end - edata);
    8020001c:	4581                	li	a1,0
    8020001e:	8e09                	sub	a2,a2,a0
int kern_init(void) {
    80200020:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
    80200022:	48c000ef          	jal	802004ae <memset>

    const char *message = "(THU.CST) os is loading ...\n";
    cprintf("%s\n\n", message);
    80200026:	00000597          	auipc	a1,0x0
    8020002a:	49a58593          	addi	a1,a1,1178 # 802004c0 <memset+0x12>
    8020002e:	00000517          	auipc	a0,0x0
    80200032:	4b250513          	addi	a0,a0,1202 # 802004e0 <memset+0x32>
    80200036:	020000ef          	jal	80200056 <cprintf>
   while (1)
    8020003a:	a001                	j	8020003a <kern_init+0x30>

000000008020003c <cputch>:

/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void cputch(int c, int *cnt) {
    8020003c:	1141                	addi	sp,sp,-16
    8020003e:	e022                	sd	s0,0(sp)
    80200040:	e406                	sd	ra,8(sp)
    80200042:	842e                	mv	s0,a1
    cons_putc(c);
    80200044:	046000ef          	jal	8020008a <cons_putc>
    (*cnt)++;
    80200048:	401c                	lw	a5,0(s0)
}
    8020004a:	60a2                	ld	ra,8(sp)
    (*cnt)++;
    8020004c:	2785                	addiw	a5,a5,1
    8020004e:	c01c                	sw	a5,0(s0)
}
    80200050:	6402                	ld	s0,0(sp)
    80200052:	0141                	addi	sp,sp,16
    80200054:	8082                	ret

0000000080200056 <cprintf>:
 * cprintf - formats a string and writes it to stdout
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int cprintf(const char *fmt, ...) {
    80200056:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
    80200058:	02810313          	addi	t1,sp,40
int cprintf(const char *fmt, ...) {
    8020005c:	f42e                	sd	a1,40(sp)
    8020005e:	f832                	sd	a2,48(sp)
    80200060:	fc36                	sd	a3,56(sp)
    vprintfmt((void *)cputch, &cnt, fmt, ap);
    80200062:	862a                	mv	a2,a0
    80200064:	004c                	addi	a1,sp,4
    80200066:	00000517          	auipc	a0,0x0
    8020006a:	fd650513          	addi	a0,a0,-42 # 8020003c <cputch>
    8020006e:	869a                	mv	a3,t1
int cprintf(const char *fmt, ...) {
    80200070:	ec06                	sd	ra,24(sp)
    80200072:	e0ba                	sd	a4,64(sp)
    80200074:	e4be                	sd	a5,72(sp)
    80200076:	e8c2                	sd	a6,80(sp)
    80200078:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
    8020007a:	e41a                	sd	t1,8(sp)
    int cnt = 0;
    8020007c:	c202                	sw	zero,4(sp)
    vprintfmt((void *)cputch, &cnt, fmt, ap);
    8020007e:	080000ef          	jal	802000fe <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
    80200082:	60e2                	ld	ra,24(sp)
    80200084:	4512                	lw	a0,4(sp)
    80200086:	6125                	addi	sp,sp,96
    80200088:	8082                	ret

000000008020008a <cons_putc>:

/* cons_init - initializes the console devices */
void cons_init(void) {}

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
    8020008a:	0ff57513          	zext.b	a0,a0
    8020008e:	a6ed                	j	80200478 <sbi_console_putchar>

0000000080200090 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
    80200090:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
    80200094:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
    80200096:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
    8020009a:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
    8020009c:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
    802000a0:	f022                	sd	s0,32(sp)
    802000a2:	ec26                	sd	s1,24(sp)
    802000a4:	e84a                	sd	s2,16(sp)
    802000a6:	f406                	sd	ra,40(sp)
    802000a8:	84aa                	mv	s1,a0
    802000aa:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
    802000ac:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
    802000b0:	2a01                	sext.w	s4,s4
    if (num >= base) {
    802000b2:	05067063          	bgeu	a2,a6,802000f2 <printnum+0x62>
    802000b6:	e44e                	sd	s3,8(sp)
    802000b8:	89be                	mv	s3,a5
        while (-- width > 0)
    802000ba:	4785                	li	a5,1
    802000bc:	00e7d763          	bge	a5,a4,802000ca <printnum+0x3a>
            putch(padc, putdat);
    802000c0:	85ca                	mv	a1,s2
    802000c2:	854e                	mv	a0,s3
        while (-- width > 0)
    802000c4:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
    802000c6:	9482                	jalr	s1
        while (-- width > 0)
    802000c8:	fc65                	bnez	s0,802000c0 <printnum+0x30>
    802000ca:	69a2                	ld	s3,8(sp)
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
    802000cc:	1a02                	slli	s4,s4,0x20
    802000ce:	020a5a13          	srli	s4,s4,0x20
    802000d2:	00000797          	auipc	a5,0x0
    802000d6:	41678793          	addi	a5,a5,1046 # 802004e8 <memset+0x3a>
    802000da:	97d2                	add	a5,a5,s4
}
    802000dc:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
    802000de:	0007c503          	lbu	a0,0(a5)
}
    802000e2:	70a2                	ld	ra,40(sp)
    802000e4:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
    802000e6:	85ca                	mv	a1,s2
    802000e8:	87a6                	mv	a5,s1
}
    802000ea:	6942                	ld	s2,16(sp)
    802000ec:	64e2                	ld	s1,24(sp)
    802000ee:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
    802000f0:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
    802000f2:	03065633          	divu	a2,a2,a6
    802000f6:	8722                	mv	a4,s0
    802000f8:	f99ff0ef          	jal	80200090 <printnum>
    802000fc:	bfc1                	j	802000cc <printnum+0x3c>

00000000802000fe <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
    802000fe:	7119                	addi	sp,sp,-128
    80200100:	f4a6                	sd	s1,104(sp)
    80200102:	f0ca                	sd	s2,96(sp)
    80200104:	ecce                	sd	s3,88(sp)
    80200106:	e8d2                	sd	s4,80(sp)
    80200108:	e4d6                	sd	s5,72(sp)
    8020010a:	e0da                	sd	s6,64(sp)
    8020010c:	f862                	sd	s8,48(sp)
    8020010e:	fc86                	sd	ra,120(sp)
    80200110:	f8a2                	sd	s0,112(sp)
    80200112:	fc5e                	sd	s7,56(sp)
    80200114:	f466                	sd	s9,40(sp)
    80200116:	f06a                	sd	s10,32(sp)
    80200118:	ec6e                	sd	s11,24(sp)
    8020011a:	892a                	mv	s2,a0
    8020011c:	84ae                	mv	s1,a1
    8020011e:	8c32                	mv	s8,a2
    80200120:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
    80200122:	02500993          	li	s3,37
        char padc = ' ';
        width = precision = -1;
        lflag = altflag = 0;

    reswitch:
        switch (ch = *(unsigned char *)fmt ++) {
    80200126:	05500b13          	li	s6,85
    8020012a:	00000a97          	auipc	s5,0x0
    8020012e:	472a8a93          	addi	s5,s5,1138 # 8020059c <memset+0xee>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
    80200132:	000c4503          	lbu	a0,0(s8)
    80200136:	001c0413          	addi	s0,s8,1
    8020013a:	01350a63          	beq	a0,s3,8020014e <vprintfmt+0x50>
            if (ch == '\0') {
    8020013e:	cd0d                	beqz	a0,80200178 <vprintfmt+0x7a>
            putch(ch, putdat);
    80200140:	85a6                	mv	a1,s1
    80200142:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
    80200144:	00044503          	lbu	a0,0(s0)
    80200148:	0405                	addi	s0,s0,1
    8020014a:	ff351ae3          	bne	a0,s3,8020013e <vprintfmt+0x40>
        char padc = ' ';
    8020014e:	02000d93          	li	s11,32
        lflag = altflag = 0;
    80200152:	4b81                	li	s7,0
    80200154:	4601                	li	a2,0
        width = precision = -1;
    80200156:	5d7d                	li	s10,-1
    80200158:	5cfd                	li	s9,-1
        switch (ch = *(unsigned char *)fmt ++) {
    8020015a:	00044683          	lbu	a3,0(s0)
    8020015e:	00140c13          	addi	s8,s0,1
    80200162:	fdd6859b          	addiw	a1,a3,-35
    80200166:	0ff5f593          	zext.b	a1,a1
    8020016a:	02bb6663          	bltu	s6,a1,80200196 <vprintfmt+0x98>
    8020016e:	058a                	slli	a1,a1,0x2
    80200170:	95d6                	add	a1,a1,s5
    80200172:	4198                	lw	a4,0(a1)
    80200174:	9756                	add	a4,a4,s5
    80200176:	8702                	jr	a4
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
    80200178:	70e6                	ld	ra,120(sp)
    8020017a:	7446                	ld	s0,112(sp)
    8020017c:	74a6                	ld	s1,104(sp)
    8020017e:	7906                	ld	s2,96(sp)
    80200180:	69e6                	ld	s3,88(sp)
    80200182:	6a46                	ld	s4,80(sp)
    80200184:	6aa6                	ld	s5,72(sp)
    80200186:	6b06                	ld	s6,64(sp)
    80200188:	7be2                	ld	s7,56(sp)
    8020018a:	7c42                	ld	s8,48(sp)
    8020018c:	7ca2                	ld	s9,40(sp)
    8020018e:	7d02                	ld	s10,32(sp)
    80200190:	6de2                	ld	s11,24(sp)
    80200192:	6109                	addi	sp,sp,128
    80200194:	8082                	ret
            putch('%', putdat);
    80200196:	85a6                	mv	a1,s1
    80200198:	02500513          	li	a0,37
    8020019c:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
    8020019e:	fff44703          	lbu	a4,-1(s0)
    802001a2:	02500793          	li	a5,37
    802001a6:	8c22                	mv	s8,s0
    802001a8:	f8f705e3          	beq	a4,a5,80200132 <vprintfmt+0x34>
    802001ac:	02500713          	li	a4,37
    802001b0:	ffec4783          	lbu	a5,-2(s8)
    802001b4:	1c7d                	addi	s8,s8,-1
    802001b6:	fee79de3          	bne	a5,a4,802001b0 <vprintfmt+0xb2>
    802001ba:	bfa5                	j	80200132 <vprintfmt+0x34>
                ch = *fmt;
    802001bc:	00144783          	lbu	a5,1(s0)
                if (ch < '0' || ch > '9') {
    802001c0:	4725                	li	a4,9
                precision = precision * 10 + ch - '0';
    802001c2:	fd068d1b          	addiw	s10,a3,-48
                if (ch < '0' || ch > '9') {
    802001c6:	fd07859b          	addiw	a1,a5,-48
                ch = *fmt;
    802001ca:	0007869b          	sext.w	a3,a5
        switch (ch = *(unsigned char *)fmt ++) {
    802001ce:	8462                	mv	s0,s8
                if (ch < '0' || ch > '9') {
    802001d0:	02b76563          	bltu	a4,a1,802001fa <vprintfmt+0xfc>
    802001d4:	4525                	li	a0,9
                ch = *fmt;
    802001d6:	00144783          	lbu	a5,1(s0)
                precision = precision * 10 + ch - '0';
    802001da:	002d171b          	slliw	a4,s10,0x2
    802001de:	01a7073b          	addw	a4,a4,s10
    802001e2:	0017171b          	slliw	a4,a4,0x1
    802001e6:	9f35                	addw	a4,a4,a3
                if (ch < '0' || ch > '9') {
    802001e8:	fd07859b          	addiw	a1,a5,-48
            for (precision = 0; ; ++ fmt) {
    802001ec:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
    802001ee:	fd070d1b          	addiw	s10,a4,-48
                ch = *fmt;
    802001f2:	0007869b          	sext.w	a3,a5
                if (ch < '0' || ch > '9') {
    802001f6:	feb570e3          	bgeu	a0,a1,802001d6 <vprintfmt+0xd8>
            if (width < 0)
    802001fa:	f60cd0e3          	bgez	s9,8020015a <vprintfmt+0x5c>
                width = precision, precision = -1;
    802001fe:	8cea                	mv	s9,s10
    80200200:	5d7d                	li	s10,-1
    80200202:	bfa1                	j	8020015a <vprintfmt+0x5c>
        switch (ch = *(unsigned char *)fmt ++) {
    80200204:	8db6                	mv	s11,a3
    80200206:	8462                	mv	s0,s8
    80200208:	bf89                	j	8020015a <vprintfmt+0x5c>
    8020020a:	8462                	mv	s0,s8
            altflag = 1;
    8020020c:	4b85                	li	s7,1
            goto reswitch;
    8020020e:	b7b1                	j	8020015a <vprintfmt+0x5c>
    if (lflag >= 2) {
    80200210:	4785                	li	a5,1
            precision = va_arg(ap, int);
    80200212:	008a0713          	addi	a4,s4,8
    if (lflag >= 2) {
    80200216:	00c7c463          	blt	a5,a2,8020021e <vprintfmt+0x120>
    else if (lflag) {
    8020021a:	1a060163          	beqz	a2,802003bc <vprintfmt+0x2be>
        return va_arg(*ap, unsigned long);
    8020021e:	000a3603          	ld	a2,0(s4)
    80200222:	46c1                	li	a3,16
    80200224:	8a3a                	mv	s4,a4
            printnum(putch, putdat, num, base, width, padc);
    80200226:	000d879b          	sext.w	a5,s11
    8020022a:	8766                	mv	a4,s9
    8020022c:	85a6                	mv	a1,s1
    8020022e:	854a                	mv	a0,s2
    80200230:	e61ff0ef          	jal	80200090 <printnum>
            break;
    80200234:	bdfd                	j	80200132 <vprintfmt+0x34>
            putch(va_arg(ap, int), putdat);
    80200236:	000a2503          	lw	a0,0(s4)
    8020023a:	85a6                	mv	a1,s1
    8020023c:	0a21                	addi	s4,s4,8
    8020023e:	9902                	jalr	s2
            break;
    80200240:	bdcd                	j	80200132 <vprintfmt+0x34>
    if (lflag >= 2) {
    80200242:	4785                	li	a5,1
            precision = va_arg(ap, int);
    80200244:	008a0713          	addi	a4,s4,8
    if (lflag >= 2) {
    80200248:	00c7c463          	blt	a5,a2,80200250 <vprintfmt+0x152>
    else if (lflag) {
    8020024c:	16060363          	beqz	a2,802003b2 <vprintfmt+0x2b4>
        return va_arg(*ap, unsigned long);
    80200250:	000a3603          	ld	a2,0(s4)
    80200254:	46a9                	li	a3,10
    80200256:	8a3a                	mv	s4,a4
    80200258:	b7f9                	j	80200226 <vprintfmt+0x128>
            putch('0', putdat);
    8020025a:	85a6                	mv	a1,s1
    8020025c:	03000513          	li	a0,48
    80200260:	9902                	jalr	s2
            putch('x', putdat);
    80200262:	85a6                	mv	a1,s1
    80200264:	07800513          	li	a0,120
    80200268:	9902                	jalr	s2
            num = (unsigned long long)va_arg(ap, void *);
    8020026a:	000a3603          	ld	a2,0(s4)
            goto number;
    8020026e:	46c1                	li	a3,16
            num = (unsigned long long)va_arg(ap, void *);
    80200270:	0a21                	addi	s4,s4,8
            goto number;
    80200272:	bf55                	j	80200226 <vprintfmt+0x128>
            putch(ch, putdat);
    80200274:	85a6                	mv	a1,s1
    80200276:	02500513          	li	a0,37
    8020027a:	9902                	jalr	s2
            break;
    8020027c:	bd5d                	j	80200132 <vprintfmt+0x34>
            precision = va_arg(ap, int);
    8020027e:	000a2d03          	lw	s10,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
    80200282:	8462                	mv	s0,s8
            precision = va_arg(ap, int);
    80200284:	0a21                	addi	s4,s4,8
            goto process_precision;
    80200286:	bf95                	j	802001fa <vprintfmt+0xfc>
    if (lflag >= 2) {
    80200288:	4785                	li	a5,1
            precision = va_arg(ap, int);
    8020028a:	008a0713          	addi	a4,s4,8
    if (lflag >= 2) {
    8020028e:	00c7c463          	blt	a5,a2,80200296 <vprintfmt+0x198>
    else if (lflag) {
    80200292:	10060b63          	beqz	a2,802003a8 <vprintfmt+0x2aa>
        return va_arg(*ap, unsigned long);
    80200296:	000a3603          	ld	a2,0(s4)
    8020029a:	46a1                	li	a3,8
    8020029c:	8a3a                	mv	s4,a4
    8020029e:	b761                	j	80200226 <vprintfmt+0x128>
            if (width < 0)
    802002a0:	fffcc793          	not	a5,s9
    802002a4:	97fd                	srai	a5,a5,0x3f
    802002a6:	00fcf7b3          	and	a5,s9,a5
    802002aa:	00078c9b          	sext.w	s9,a5
        switch (ch = *(unsigned char *)fmt ++) {
    802002ae:	8462                	mv	s0,s8
            goto reswitch;
    802002b0:	b56d                	j	8020015a <vprintfmt+0x5c>
            if ((p = va_arg(ap, char *)) == NULL) {
    802002b2:	000a3403          	ld	s0,0(s4)
    802002b6:	008a0793          	addi	a5,s4,8
    802002ba:	e43e                	sd	a5,8(sp)
    802002bc:	12040063          	beqz	s0,802003dc <vprintfmt+0x2de>
            if (width > 0 && padc != '-') {
    802002c0:	0d905963          	blez	s9,80200392 <vprintfmt+0x294>
    802002c4:	02d00793          	li	a5,45
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    802002c8:	00140a13          	addi	s4,s0,1
            if (width > 0 && padc != '-') {
    802002cc:	12fd9763          	bne	s11,a5,802003fa <vprintfmt+0x2fc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    802002d0:	00044783          	lbu	a5,0(s0)
    802002d4:	0007851b          	sext.w	a0,a5
    802002d8:	cb9d                	beqz	a5,8020030e <vprintfmt+0x210>
    802002da:	547d                	li	s0,-1
                if (altflag && (ch < ' ' || ch > '~')) {
    802002dc:	05e00d93          	li	s11,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    802002e0:	000d4563          	bltz	s10,802002ea <vprintfmt+0x1ec>
    802002e4:	3d7d                	addiw	s10,s10,-1
    802002e6:	028d0263          	beq	s10,s0,8020030a <vprintfmt+0x20c>
                    putch('?', putdat);
    802002ea:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
    802002ec:	0c0b8d63          	beqz	s7,802003c6 <vprintfmt+0x2c8>
    802002f0:	3781                	addiw	a5,a5,-32
    802002f2:	0cfdfa63          	bgeu	s11,a5,802003c6 <vprintfmt+0x2c8>
                    putch('?', putdat);
    802002f6:	03f00513          	li	a0,63
    802002fa:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    802002fc:	000a4783          	lbu	a5,0(s4)
    80200300:	3cfd                	addiw	s9,s9,-1
    80200302:	0a05                	addi	s4,s4,1
    80200304:	0007851b          	sext.w	a0,a5
    80200308:	ffe1                	bnez	a5,802002e0 <vprintfmt+0x1e2>
            for (; width > 0; width --) {
    8020030a:	01905963          	blez	s9,8020031c <vprintfmt+0x21e>
                putch(' ', putdat);
    8020030e:	85a6                	mv	a1,s1
    80200310:	02000513          	li	a0,32
            for (; width > 0; width --) {
    80200314:	3cfd                	addiw	s9,s9,-1
                putch(' ', putdat);
    80200316:	9902                	jalr	s2
            for (; width > 0; width --) {
    80200318:	fe0c9be3          	bnez	s9,8020030e <vprintfmt+0x210>
            if ((p = va_arg(ap, char *)) == NULL) {
    8020031c:	6a22                	ld	s4,8(sp)
    8020031e:	bd11                	j	80200132 <vprintfmt+0x34>
    if (lflag >= 2) {
    80200320:	4785                	li	a5,1
            precision = va_arg(ap, int);
    80200322:	008a0b93          	addi	s7,s4,8
    if (lflag >= 2) {
    80200326:	00c7c363          	blt	a5,a2,8020032c <vprintfmt+0x22e>
    else if (lflag) {
    8020032a:	ce25                	beqz	a2,802003a2 <vprintfmt+0x2a4>
        return va_arg(*ap, long);
    8020032c:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
    80200330:	08044d63          	bltz	s0,802003ca <vprintfmt+0x2cc>
            num = getint(&ap, lflag);
    80200334:	8622                	mv	a2,s0
    80200336:	8a5e                	mv	s4,s7
    80200338:	46a9                	li	a3,10
    8020033a:	b5f5                	j	80200226 <vprintfmt+0x128>
            if (err < 0) {
    8020033c:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
    80200340:	4619                	li	a2,6
            if (err < 0) {
    80200342:	41f7d71b          	sraiw	a4,a5,0x1f
    80200346:	8fb9                	xor	a5,a5,a4
    80200348:	40e786bb          	subw	a3,a5,a4
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
    8020034c:	02d64663          	blt	a2,a3,80200378 <vprintfmt+0x27a>
    80200350:	00369713          	slli	a4,a3,0x3
    80200354:	00000797          	auipc	a5,0x0
    80200358:	3a478793          	addi	a5,a5,932 # 802006f8 <error_string>
    8020035c:	97ba                	add	a5,a5,a4
    8020035e:	639c                	ld	a5,0(a5)
    80200360:	cf81                	beqz	a5,80200378 <vprintfmt+0x27a>
                printfmt(putch, putdat, "%s", p);
    80200362:	86be                	mv	a3,a5
    80200364:	00000617          	auipc	a2,0x0
    80200368:	1b460613          	addi	a2,a2,436 # 80200518 <memset+0x6a>
    8020036c:	85a6                	mv	a1,s1
    8020036e:	854a                	mv	a0,s2
    80200370:	0e8000ef          	jal	80200458 <printfmt>
            err = va_arg(ap, int);
    80200374:	0a21                	addi	s4,s4,8
    80200376:	bb75                	j	80200132 <vprintfmt+0x34>
                printfmt(putch, putdat, "error %d", err);
    80200378:	00000617          	auipc	a2,0x0
    8020037c:	19060613          	addi	a2,a2,400 # 80200508 <memset+0x5a>
    80200380:	85a6                	mv	a1,s1
    80200382:	854a                	mv	a0,s2
    80200384:	0d4000ef          	jal	80200458 <printfmt>
            err = va_arg(ap, int);
    80200388:	0a21                	addi	s4,s4,8
    8020038a:	b365                	j	80200132 <vprintfmt+0x34>
            lflag ++;
    8020038c:	2605                	addiw	a2,a2,1
        switch (ch = *(unsigned char *)fmt ++) {
    8020038e:	8462                	mv	s0,s8
            goto reswitch;
    80200390:	b3e9                	j	8020015a <vprintfmt+0x5c>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    80200392:	00044783          	lbu	a5,0(s0)
    80200396:	0007851b          	sext.w	a0,a5
    8020039a:	d3c9                	beqz	a5,8020031c <vprintfmt+0x21e>
    8020039c:	00140a13          	addi	s4,s0,1
    802003a0:	bf2d                	j	802002da <vprintfmt+0x1dc>
        return va_arg(*ap, int);
    802003a2:	000a2403          	lw	s0,0(s4)
    802003a6:	b769                	j	80200330 <vprintfmt+0x232>
        return va_arg(*ap, unsigned int);
    802003a8:	000a6603          	lwu	a2,0(s4)
    802003ac:	46a1                	li	a3,8
    802003ae:	8a3a                	mv	s4,a4
    802003b0:	bd9d                	j	80200226 <vprintfmt+0x128>
    802003b2:	000a6603          	lwu	a2,0(s4)
    802003b6:	46a9                	li	a3,10
    802003b8:	8a3a                	mv	s4,a4
    802003ba:	b5b5                	j	80200226 <vprintfmt+0x128>
    802003bc:	000a6603          	lwu	a2,0(s4)
    802003c0:	46c1                	li	a3,16
    802003c2:	8a3a                	mv	s4,a4
    802003c4:	b58d                	j	80200226 <vprintfmt+0x128>
                    putch(ch, putdat);
    802003c6:	9902                	jalr	s2
    802003c8:	bf15                	j	802002fc <vprintfmt+0x1fe>
                putch('-', putdat);
    802003ca:	85a6                	mv	a1,s1
    802003cc:	02d00513          	li	a0,45
    802003d0:	9902                	jalr	s2
                num = -(long long)num;
    802003d2:	40800633          	neg	a2,s0
    802003d6:	8a5e                	mv	s4,s7
    802003d8:	46a9                	li	a3,10
    802003da:	b5b1                	j	80200226 <vprintfmt+0x128>
            if (width > 0 && padc != '-') {
    802003dc:	01905663          	blez	s9,802003e8 <vprintfmt+0x2ea>
    802003e0:	02d00793          	li	a5,45
    802003e4:	04fd9263          	bne	s11,a5,80200428 <vprintfmt+0x32a>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    802003e8:	02800793          	li	a5,40
    802003ec:	00000a17          	auipc	s4,0x0
    802003f0:	115a0a13          	addi	s4,s4,277 # 80200501 <memset+0x53>
    802003f4:	02800513          	li	a0,40
    802003f8:	b5cd                	j	802002da <vprintfmt+0x1dc>
                for (width -= strnlen(p, precision); width > 0; width --) {
    802003fa:	85ea                	mv	a1,s10
    802003fc:	8522                	mv	a0,s0
    802003fe:	094000ef          	jal	80200492 <strnlen>
    80200402:	40ac8cbb          	subw	s9,s9,a0
    80200406:	01905963          	blez	s9,80200418 <vprintfmt+0x31a>
                    putch(padc, putdat);
    8020040a:	2d81                	sext.w	s11,s11
    8020040c:	85a6                	mv	a1,s1
    8020040e:	856e                	mv	a0,s11
                for (width -= strnlen(p, precision); width > 0; width --) {
    80200410:	3cfd                	addiw	s9,s9,-1
                    putch(padc, putdat);
    80200412:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
    80200414:	fe0c9ce3          	bnez	s9,8020040c <vprintfmt+0x30e>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    80200418:	00044783          	lbu	a5,0(s0)
    8020041c:	0007851b          	sext.w	a0,a5
    80200420:	ea079de3          	bnez	a5,802002da <vprintfmt+0x1dc>
            if ((p = va_arg(ap, char *)) == NULL) {
    80200424:	6a22                	ld	s4,8(sp)
    80200426:	b331                	j	80200132 <vprintfmt+0x34>
                for (width -= strnlen(p, precision); width > 0; width --) {
    80200428:	85ea                	mv	a1,s10
    8020042a:	00000517          	auipc	a0,0x0
    8020042e:	0d650513          	addi	a0,a0,214 # 80200500 <memset+0x52>
    80200432:	060000ef          	jal	80200492 <strnlen>
    80200436:	40ac8cbb          	subw	s9,s9,a0
                p = "(null)";
    8020043a:	00000417          	auipc	s0,0x0
    8020043e:	0c640413          	addi	s0,s0,198 # 80200500 <memset+0x52>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
    80200442:	00000a17          	auipc	s4,0x0
    80200446:	0bfa0a13          	addi	s4,s4,191 # 80200501 <memset+0x53>
    8020044a:	02800793          	li	a5,40
    8020044e:	02800513          	li	a0,40
                for (width -= strnlen(p, precision); width > 0; width --) {
    80200452:	fb904ce3          	bgtz	s9,8020040a <vprintfmt+0x30c>
    80200456:	b551                	j	802002da <vprintfmt+0x1dc>

0000000080200458 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
    80200458:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
    8020045a:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
    8020045e:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
    80200460:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
    80200462:	ec06                	sd	ra,24(sp)
    80200464:	f83a                	sd	a4,48(sp)
    80200466:	fc3e                	sd	a5,56(sp)
    80200468:	e0c2                	sd	a6,64(sp)
    8020046a:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
    8020046c:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
    8020046e:	c91ff0ef          	jal	802000fe <vprintfmt>
}
    80200472:	60e2                	ld	ra,24(sp)
    80200474:	6161                	addi	sp,sp,80
    80200476:	8082                	ret

0000000080200478 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
    80200478:	4781                	li	a5,0
    8020047a:	00003717          	auipc	a4,0x3
    8020047e:	b8673703          	ld	a4,-1146(a4) # 80203000 <SBI_CONSOLE_PUTCHAR>
    80200482:	88ba                	mv	a7,a4
    80200484:	852a                	mv	a0,a0
    80200486:	85be                	mv	a1,a5
    80200488:	863e                	mv	a2,a5
    8020048a:	00000073          	ecall
    8020048e:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
    80200490:	8082                	ret

0000000080200492 <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
    80200492:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
    80200494:	e589                	bnez	a1,8020049e <strnlen+0xc>
    80200496:	a811                	j	802004aa <strnlen+0x18>
        cnt ++;
    80200498:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
    8020049a:	00f58863          	beq	a1,a5,802004aa <strnlen+0x18>
    8020049e:	00f50733          	add	a4,a0,a5
    802004a2:	00074703          	lbu	a4,0(a4)
    802004a6:	fb6d                	bnez	a4,80200498 <strnlen+0x6>
    802004a8:	85be                	mv	a1,a5
    }
    return cnt;
}
    802004aa:	852e                	mv	a0,a1
    802004ac:	8082                	ret

00000000802004ae <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
    802004ae:	ca01                	beqz	a2,802004be <memset+0x10>
    802004b0:	962a                	add	a2,a2,a0
    char *p = s;
    802004b2:	87aa                	mv	a5,a0
        *p ++ = c;
    802004b4:	0785                	addi	a5,a5,1
    802004b6:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
    802004ba:	fef61de3          	bne	a2,a5,802004b4 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
    802004be:	8082                	ret
