MEMORY
{
	DRAM   (rwx) : ORIGIN = 0x00000000, LENGTH = 1024M
	FLASH  (rx)  : ORIGIN = 0xE2000000, LENGTH = 64M
	QSPI   (rx)  : ORIGIN = 0xFC000000, LENGTH = 16M
	SRAM1  (rwx) : ORIGIN = 0xFFFC0000, LENGTH = 128K   # used for stacks
	SRAM2  (rwx) : ORIGIN = 0xFFFE0000, LENGTH = 128K
    LRAM2  (rwx) : ORIGIN = 0x00020000, LENGTH = 64K    # startup mapping
}

ENTRY(__startup_ram)

SECTIONS
{
    .startup : {
        PROVIDE(__startup_ram = .);
    } > LRAM2

	.text : {
		KEEP(startup.o(.text))
		*(.text*)
	} > SRAM2 AT> LRAM2

	.rodata : {
		*(.rodata*)
	} > SRAM2 AT> LRAM2

	.data : {
		*(.data*)
	} > SRAM2 AT> LRAM2

	.bss (NOLOAD) : {
		__bss_start = . ;
		*(.bss*)
		__bss_length = . - __bss_start ;
	} > DRAM
	end = . ;

	.vectors 0xFFFF0000 : {
		RST_Handler = _start ;
		KEEP(*(.vectors))
	}

	.logo 0x00100000 (NOLOAD) : {
		KEEP(*(.logo))
	}
}
