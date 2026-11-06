CPU_OPTS := -mcpu=cortex-a9 -mfloat-abi=hard
GCC_OPTS := -std=c11 -ffunction-sections -ffreestanding
GCC_OPTS += -g3 -O3 -flto -mthumb
GCC_OPTS += -I /opt/arm/CMSIS_6-6.1.0
ASM_OPTS := -g
LLD_OPTS := --gc-sections

LIBS := -lc_nano -lnosys

SRCS := startup.s cache.s mynosys.c ps7_init.c
SRCS += irq_ctrl_gic.c exceptions.c scheduler.c
SRCS += zynq.c uart.c dma.c
SRCS += picture.bin

OUT1 := zynq.elf
LLD1 := zynq.ld

OBJS := $(addsuffix .o, $(basename $(SRCS)))
DEPS := $(addsuffix .d, $(basename $(SRCS)))

LLDtoGCC := -Wl,
LCC_OPTS := $(CPU_OPTS) $(addprefix $(LLDtoGCC),$(LLD_OPTS))
LCC_OPTS += -nostartfiles -flto

NOW  := $(shell date +%Y-%m-%dT%H:%M:%S%z)
LIBS += -DBUILD_TIMESTAMP=$(NOW) build_date.c

default : $(OUT1)

$(OUT1) : $(OBJS) $(LLD1)
	arm-none-eabi-gcc $(LCC_OPTS) -T $(LLD1)  -o $@ $(OBJS) $(LIBS)

%.o : %.s
	arm-none-eabi-as  $(ASM_OPTS) $(CPU_OPTS) -o $@ --MD $*.d $<

%.o : %.c
	arm-none-eabi-gcc $(GCC_OPTS) $(CPU_OPTS) -o $@ -MMD -MP -c $<

%.o : %.bin
	arm-none-eabi-objcopy -I binary -O elf32-littlearm -B armv7 \
		--rename-section .data=.picture,alloc,load,readonly,data,contents \
		$< $@

$(DEPS):
-include $(wildcard $(DEPS))

clean:
	rm -f $(OUT1) $(OBJS) $(DEPS)

run: $(OUT1)
	osascript -e 'tell application "Terminal" to do script "cd \"$(CURDIR)\" && openocd -f interface/ftdi/c232hm.cfg -f target/zynq_7000.cfg"'
	osascript -e 'tell application "Terminal" to do script "cd \"$(CURDIR)\" && sleep 1 && arm-none-eabi-gdb $(OUT1) -x load.gdb"'
	osascript -e 'tell application "Terminal" to do script "screen $$(ls /dev/tty.usbserial* | head -n 1) 115200"'
	#osascript -e 'tell application "Terminal" to do script "cd \"$(CURDIR)\" && python3 ../software/visualize-image.py"'

.PHONY: default clean debug run