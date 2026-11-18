DMA_ALIGNMENT = 4;

MEMORY
{
	DRAM   (rwx) : ORIGIN = 0x00000000, LENGTH = 256M
	DMA_NC (rw)  : ORIGIN = 0x10000000, LENGTH = 256M

	FLASH  (rx)  : ORIGIN = 0xE2000000, LENGTH =  64M
	QSPI   (rx)  : ORIGIN = 0xFC000000, LENGTH =  16M
	SRAM1  (rwx) : ORIGIN = 0xFFFC0000, LENGTH = 128K   # used for stacks
	SRAM2  (rwx) : ORIGIN = 0xFFFE0000, LENGTH = 128K
    LRAM2  (rwx) : ORIGIN = 0x00020000, LENGTH =  64K   # startup mapping
}

ENTRY(__startup_ram)

SECTIONS
{
    .startup : {
        PROVIDE(__startup_ram = .);
    } > LRAM2

	.text : ALIGN_WITH_INPUT {
		KEEP(startup.o(.text))
		*(.text*)
	} > SRAM2 AT> LRAM2

	.rodata : ALIGN_WITH_INPUT {
		*(.rodata*)
	} > SRAM2 AT> LRAM2

	.data : ALIGN_WITH_INPUT {
		*(.data*)
	} > SRAM2 AT> LRAM2

	.bss (NOLOAD) : {
		__bss_start = . ;
		*(.bss*)
		__bss_length = . - __bss_start ;
	} > DRAM
	end = . ;

	.dma_nocache (NOLOAD) : {
		KEEP(*(.dma_nocache*))
	} > DMA_NC

	.vectors 0xFFFF0000 : {
		RST_Handler = _start ;
		KEEP(*(.vectors))
	}

	.picture (NOLOAD) : ALIGN(DMA_ALIGNMENT) {
		KEEP(*(.picture))
	} > DMA_NC
}