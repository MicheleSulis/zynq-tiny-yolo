/*
 * Copyright © 2023-2025 Giorgio Biagetti <g.biagetti@staff.univpm.it>
 * Department of Information Engineering
 * Università Politecnica delle Marche (ITALY)
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "CMSIS_Device.h"
#include "MyZynq.h"

#include "uart.h"
#include "test.h"
#include "scheduler.h"

static const char hello_text[] = "Hello, this is some UART text.\r\n";

static int processor_mode;
static const char * const processor_mode_text[] = {
	"USR", "FIQ", "IRQ", "SVC",
	 NULL,  NULL, "MON", "ABT",
	 NULL,  NULL, "HYP", "UND",
	 NULL,  NULL,  NULL, "SYS",
};

int check_processor_mode (void)
{
	int mode;
	__asm__ volatile (
		"	mrs %[modereg], cpsr\n"
		"	and %[modereg], #0x1F\n"
		: // output operands
			[modereg] "=r" (mode)
		: // input operands
		: // clobbers
	);
	return mode;
}

void show_processor_mode (void)
{
	processor_mode = check_processor_mode();
	serial_print_dec("Processor mode: ", processor_mode, " (");
	serial_send(processor_mode_text[processor_mode & 0x0F]);
	serial_send(")\r\n");
}


static void setup_system (void)
{
	slcr->SLCR_UNLOCK = 0xDF0D;

	slcr->MIO_PIN[RxD] = 0x000012E1;
	slcr->MIO_PIN[TxD] = 0x000012E0;

	// setup UART reference clock divider:
	// it uses the IO PLL, configured to run at 1 GHz (multiplier = 30) by ps7_init
	// The ideal UART reference could be 921600 × 16 = 14.7456 MHz
	// but that would require dividing by 68, which exceeds the maximum (6 bits, -> max = 63)
	// so, we double the reference clock, dividing by 34,
	// obtaining 2×14.7059 MHz,
	// which is only -0.27% from desired frequency.
	*(volatile uint32_t *) 0xF8000154 = 0x2203; // slcr->UART_CLK_CTRL

	slcr->SLCR_LOCK = 0x767B;
}


static uint32_t main_translation_table[4096] __attribute__((aligned(1 << 14)));

static void setup_mtt_and_cache (void)
{
	extern void cache_clean  (void);
	extern void cache_enable (void *main_ptr);
	for (unsigned i = 0; i < 4096; ++i) {
		uint16_t a;
		     if (i < 0x400) a = 0x5C06; // DRAM
		else if (i < 0xC00) a = 0x0C12; // device (strongly ordered)
		else if (i < 0xE00) a = 0x0000; // reserved
		else if (i < 0xE10) a = 0x0C12; // device (strongly ordered)
		else if (i < 0xF80) a = 0x0000; // reserved
		else if (i < 0xFF0) a = 0x0C12; // device (strongly ordered)
		else                a = 0x5C06; // SRAM
		main_translation_table[i] = i << 20 | a;
	}
	cache_clean();
	cache_enable(main_translation_table);
	L2C_Enable();
}


__attribute__ ((target("general-regs-only"), interrupt("ABORT")))
void DAB_Handler (void)
{
	uint32_t DFSR, DFAR;
	__asm__("MRC p15, 0, %0, c5, c0, 0" : "=r" (DFSR));
	__asm__("MRC p15, 0, %0, c6, c0, 0" : "=r" (DFAR));

	show_processor_mode();
	serial_print_hex("DATA ABORT @", DFAR, "\r\n");
	serial_print_hex("STATUS REG.:", DFSR, "\r\n");
}

__attribute__ ((target("general-regs-only"), interrupt("ABORT")))
void UND_Handler (void)
{
	show_processor_mode();
loop:
	goto loop;
}

enum {timer_tick = 4};

__attribute__ ((target("general-regs-only")))
void my_timer_isr (void)
{
	event_set(timer_tick);
	PTIM->ISR = PTIM->ISR;
}

static char str[64];
void print_time (void)
{
	static int n = 0;
	++n;
	sprintf(str, "%sTime: %d%s",
		"\e[s\e[3;999H\e[10D", // save and position cursor line 3 column 10 from right
		n,
		"\e[u"                 // restore cursor position
	);
	uart_post(str, 0);
}

int main (void)
{
	setup_mtt_and_cache();
	setup_system();
	IRQ_Initialize();
	uart_setup();

	serial_send(hello_text);
	show_processor_mode();
	__asm__ ("CPSIE i");
	__asm__ ("CPS #16");
	show_processor_mode();

	// NOTE: The following read generates a data abort as the 0xD0000000 segment is not mapped by the MMU:
	*(volatile uint32_t *) 0xD1234567;
	show_processor_mode();

	// QEMU default private timer freq is 100 MHz, real board should be 375 MHz
	PTIM->LOAD = 3830000 - 1;
	PTIM->CONTROL = PTIM_CONTROL_Prescaler(99) | 7;
	IRQ_SetHandler(PrivTimer_IRQn, my_timer_isr);
	IRQ_SetMode(PrivTimer_IRQn, IRQ_MODE_TYPE_IRQ | IRQ_MODE_CPU_0 | IRQ_MODE_TRIG_EDGE_RISING);
	IRQ_SetPriority(PrivTimer_IRQn, 0xE0);
	IRQ_Enable(PrivTimer_IRQn);

	uart_post("\e[4;r", 5);
	while (1) {
		wait_for_events(uart_rx_ready | timer_tick);
		if (event_test(uart_rx_ready)) {
			event_clear(uart_rx_ready);
			if (cli_run()) break;
		}
		if (event_test(timer_tick)) {
			event_clear(timer_tick);
			print_time();
		}
	}
	uart_post("\e[s\e[r\e[u", 9);

	return 0;
}

