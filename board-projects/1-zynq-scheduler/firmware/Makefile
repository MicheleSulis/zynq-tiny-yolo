CPU_OPTS := -mcpu=cortex-a9 -mfloat-abi=hard
GCC_OPTS := -std=c11 -ffunction-sections -ffreestanding
GCC_OPTS += -g3 -O3 -flto -mthumb
GCC_OPTS += -I /opt/arm/CMSIS_6-6.1.0
ASM_OPTS := -g
LLD_OPTS := --gc-sections

LIBS := -lc_nano -lnosys

SRCS := startup.s cache.s mynosys.c ps7_init.c
SRCS += irq_ctrl_gic.c exceptions.c scheduler.c
SRCS += zynq.c uart.c
SRCS += test.c logo.txt

OUT1 := emu.elf
OUT2 := board.elf
LLD1 := emu.ld
LLD2 := board.ld

OBJS := $(addsuffix .o, $(basename $(SRCS)))
DEPS := $(addsuffix .d, $(basename $(SRCS)))

LLDtoGCC := -Wl,
LCC_OPTS := $(CPU_OPTS) $(addprefix $(LLDtoGCC),$(LLD_OPTS))
LCC_OPTS += -nostartfiles -flto -u _printf_float -u _scanf_float

NOW  := $(shell date +%Y-%m-%dT%H:%M:%S%z)
LIBS += -DBUILD_TIMESTAMP=$(NOW) build_date.c

default : $(OUT1)

board: $(OUT2)

$(OUT1) : $(OBJS) $(LLD1)
	arm-none-eabi-gcc $(LCC_OPTS) -T $(LLD1)  -o $@ $(OBJS) $(LIBS)

%.o : %.s
	arm-none-eabi-as  $(ASM_OPTS) $(CPU_OPTS) -o $@ --MD $*.d $<

%.o : %.c
	arm-none-eabi-gcc $(GCC_OPTS) $(CPU_OPTS) -o $@ -MMD -MP -c $<

%.o : %.txt
	arm-none-eabi-objcopy -I binary -O elf32-littlearm -B armv7 \
		--rename-section .data=.logo,alloc,load,readonly,data,contents \
		--change-addresses=0x100000 \
		$< $@

$(OUT2) : $(OBJS) $(LLD2)
	arm-none-eabi-gcc $(LCC_OPTS) -T $(LLD2)  -o $@ $(OBJS) $(LIBS)

$(DEPS):

-include $(wildcard $(DEPS))

clean:
	rm -f $(OUT1) $(OBJS) $(DEPS)

emu: $(OUT1)
	qemu-system-arm -nographic \
		-monitor telnet::12345,server,nowait \
		-machine xilinx-zynq-a9 -cpu cortex-a9 -m 1024 \
		-serial none -serial stdio \
		-gdb tcp::1234 \
		-device loader,cpu-num=0,file=$(OUT1) \
#		-S \
#		-drive if=pflash,file=nor.bin,format=raw \
#		-drive if=mtd,index=1,file=spi.bin,format=raw \

debug: $(OUT1)
	gdb-multiarch --ex "target extended-remote :1234" -se $(OUT1)

.PHONY: default clean emu debug

