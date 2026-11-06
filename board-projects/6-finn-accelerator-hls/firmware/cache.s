@ Sample code to clear the data cache
@ ARM Cortex-A Series Programmes's Guide, §8.9.1
@ Modified to save and restore clobbed registers
.global cache_clean
.type   cache_clean, "function"
cache_clean:
	PUSH  {R4, R5, R7, R9, R10, R11}
	MRC   p15, 1, R0, c0, c0, 1   @ Read CLIDR into R0
	ANDS  R3, R0, #0x07000000
	MOV   R3, R3, LSR #23	      @ Cache level value (naturally aligned)
	BEQ   Finished
	MOV   R10, #0
Loop1:
	ADD   R2, R10, R10, LSR #1    @ Work out 3 x cache level
	MOV   R1, R0, LSR R2          @ bottom 3 bits are the Cache type for this level
	AND   R1, R1, #7              @ get those 3 bits alone
	CMP   R1, #2
	BLT   Skip                    @ no cache or only instruction cache at this level
	MCR   p15, 2, R10, c0, c0, 0  @ write CSSELR from R10
	ISB                           @ ISB to sync the change to the CCSIDR
	MRC   p15, 1, R1, c0, c0, 0   @ read current CCSIDR to R1
	AND   R2, R1, #7              @ extract the line length field
	ADD   R2, R2, #4              @ add 4 for the line length offset (log2 16 bytes)
	LDR   R4, =0x3FF
	ANDS  R4, R4, R1, LSR #3      @ R4 is the max number on the way size (right aligned)
	CLZ   R5, R4                  @ R5 is the bit position of the way size increment
	MOV   R9, R4                  @ R9 working copy of the max way size (right aligned)
Loop2:
	LDR   R7, =0x00007FFF
	ANDS  R7, R7, R1, LSR #13     @ R7 is the max num of the index size (right aligned)
Loop3:
	ORR   R11, R10, R9, LSL R5    @ factor in the way number and cache number into R11
	ORR   R11, R11, R7, LSL R2    @ factor in the index number
	MCR   p15, 0, R11, c7, c10, 2 @ DCCSW, clean by set/way
	SUBS  R7, R7, #1              @ decrement the index
	BGE   Loop3
	SUBS  R9, R9, #1              @ decrement the way number
	BGE   Loop2
Skip:
	ADD   R10, R10, #2
	CMP   R3, R10
	BGT   Loop1
	DSB
Finished:
	POP   {R4, R5, R7, R9, R10, R11}
	BX    R14

@ The following code enables the MMU and D-Cache:
.global cache_enable
.type   cache_enable, "function"
cache_enable:
	@ set MMU registers:
	@ it expects the Translation Table Base address in r0
	orr   r0, #0x48                @ flags that specify cacheability of page tables
	mcr   p15, 0, r0, c2, c0, 0    @ r0 -> TTBR0
	ldr   r0, =#0x55555555         @ client mode (permission bits checked)
	mcr   p15, 0, r0, c3, c0, 0    @ r0 -> DACR
	@ enable cache:
	mrc   p15, 0, r0, c1, c0, 0    @ SCTLR -> r0
	orr   r0, #0x5                 @ Enable D-Cache & MMU
	mcr   p15, 0, r0, c1, c0, 0    @ SCTLR <- r0
	isb
	bx    lr
	