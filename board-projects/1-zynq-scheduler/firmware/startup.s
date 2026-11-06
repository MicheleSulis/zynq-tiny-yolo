@ startup.s: startup code for the ARM Cortex-A9 CPU in the AMD (Xilinx) Zynq-7020 SoC
@
@ Copyright © 2025 Giorgio Biagetti <g.biagetti@staff.univpm.it>
@ Department of Information Engineering
@ Università Politecnica delle Marche (ITALY)
@
@ SPDX-License-Identifier: BSD-3-Clause
@

@ This startup code re-programs the on-chip-memory to high-memory
@ so that the entire DRAM is accessible from the ARM cores.

.section .text
.global _start
.type   _start, "function"
_start:
	@ Configure OCM mapping to high-memory (0xFFFC0000)
	@ To do so, we need to enable I-Cache before,
	@ so that the code memory can be moved around
	@ while executing from cache!
	mov   r0, #0
	mcr   p15, 0, r0, c8, c7, 0    @ Invalidate TLBs
	mcr   p15, 0, r0, c7, c5, 0    @ Invalidate I-Cache
	mcr   p15, 0, r0, c7, c5, 6    @ Invalidate Branch Predictor Array
	mrc   p15, 0, r2, c1, c0, 0    @ SCTLR -> r2
	orr   r2, #0x3000              @ Enable I-Cache and sets V=1 (HiVecs)
	mcr   p15, 0, r2, c1, c0, 0    @ SCTLR <- r2
	dsb
	isb
	@ prepare SLCR
	mov   r3, #0xF8000000   @ SLCR base address
	tst   pc, #0xFF000000   @ chech if we are already running in high mem
	bne   setup_stack
	movw  r1, #0xDF0D       @ unlock code
	str   r1, [r3, #0x008]  @ SLCR->UNLOCK
	mov   r1, #0xF          @ bitmask of 64-KiB banks to map to high mem
	dsb
	isb
	pli   newpos            @ try to ensure it's in L1 before reconfiguring
	isb
	str   r1, [r3, #0x910]  @ SLCR->OCM_CFG
	dsb
newpos:
	add   pc, #0xFFFC0000
	movw  r1, #0x767B       @ lock code
	str   r1, [r3, #0x004]  @ SLCR->LOCK
	@ remapping done!

	@ complete the SCU setup and re-enable branch prediction:
	add   r3, #0x00F00000   @ SCU base address
	str   r0, [r3, #0x040]  @ SCU->FILTER_START_ADDRESS
	orr   r2, #0x0800              @ Enable Branch Predictor
	mcr   p15, 0, r2, c1, c0, 0    @ SCTLR <- r2

setup_stack:
	@ configure stacks:
	movt  r3, #0xFFFE
	cps   #0x16             @ MON
	mov   sp, r3
	sub   r3, #0x1000
	cps   #0x1B             @ UND
	mov   sp, r3
	sub   r3, #0x1000
	cps   #0x17             @ ABT
	mov   sp, r3
	sub   r3, #0x1000
	cps   #0x11             @ FIQ
	mov   sp, r3
	sub   r3, #0x1000
	cps   #0x12             @ IRQ
	mov   sp, r3
	sub   r3, #0x2000
	sub   r3, #0x2000       @ reserved (HYP)
	cps   #0x13             @ SVC
	mov   sp, r3
	sub   r3, #0x8000
	cps   #0x1F             @ SYS
	mov   sp, r3
	sub   sl, r3, #0x10000

enable_fpu:
	mrc   p15, 0, r2, c1, c0, 2       @ reads CP access control register
	orr   r2, #(0x300000 + 0xC00000)  @ enable CP10 and CP11 (2 bits each)
	mcr   p15, 0, r2, c1, c0, 2       @ write CP access control register
	mov   r2, #0x40000000             @ bit to enable VFP
	mcr   p10, 7, r2, c8, c0, 0       @ write it to CP10

setup_system:
	@ initialize hardware resources (e.g. DRAM, PLLs, ...) now
	bl    ps7_init
	@ and zero out the .bss segment by calling memset:
	@ (requires linking with libc!)
.macro adrx reg label
	movw  \reg, :lower16:\label
	movt  \reg, :upper16:\label
.endm
	adrx  r0, __bss_start
	mov   r1, #0
	adrx  r2, __bss_length
	adrx  r3, memset
	blx   r3

enter_main:
	mov   r0, #0
	mov   r1, #0
	blx   main

_end:
	wfi
	b     _end


	@ The following is a stub that just returns 0 (success),
	@ it will be used instead of "ps7_init" by the linker script
	@ for the QEMU version, as there is no HW to be initialized.
	@ It is put into its own section so that the linker can remove it
	@ in the standard (real SoC) case where it is unused.
.section .text._return
.global _return
.type   _return, "function"
_return:
	mov   r0, #0
	bx    lr

