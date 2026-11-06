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
#include <string.h>

#include "CMSIS_Device.h"
#include "MyZynq.h"

#include "uart.h"
#include "dma.h"
#include "scheduler.h"
#include "events.h"

static const char *dma_result_str[] = {
	"DMA BUSY",
	"INVALID LEN",
	"ALIGNMENT ERROR",
	"DMA HALTED",
	"OK"};

// test parameters
#define RX_TRANSFER_LEN 13 * 13 * 18
#define TX_TRANSFER_LEN 416 * 416 * 3
#define N_TRANSFERS 100

static int processor_mode;
static const char *const processor_mode_text[] = {
	"USR",
	"FIQ",
	"IRQ",
	"SVC",
	NULL,
	NULL,
	"MON",
	"ABT",
	NULL,
	NULL,
	"HYP",
	"UND",
	NULL,
	NULL,
	NULL,
	"SYS",
};

int check_processor_mode(void)
{
	int mode;
	__asm__ volatile(
		"	mrs %[modereg], cpsr\n"
		"	and %[modereg], #0x1F\n"
		: // output operands
		[modereg] "=r"(mode)
		: // input operands
		: // clobbers
	);
	return mode;
}

void show_processor_mode(void)
{
	processor_mode = check_processor_mode();
	serial_print_dec("Processor mode: ", processor_mode, " (");
	serial_send(processor_mode_text[processor_mode & 0x0F]);
	serial_send(")\r\n");
}

/*
 * MMU section attributes:
 *
 * Descriptor | TEX | C | B | XN | AP  | Domain | S | nG | NS
 * -----------|-----|---|---|----|-----|--------|---|----|----
 * 0x5C06     | 101 | 0 | 1 | 0  | 011 |   0    | 0 | 0  |  0
 * 0x4C12     | 100 | 0 | 0 | 1  | 011 |   0    | 0 | 0  |  0
 *
 * TEX[2] = 1          -> Normal memory
 * TEX[1:0] = 01       -> Outer Write-Back, Write-Allocate
 * C:B = 01            -> Inner Write-Back, Write-Allocate
 * TEX[1:0] = 00       -> Outer non-cacheable
 * C:B = 00            -> Inner non-cacheable
 *
 * XN = 1              -> Execute Never
 * AP = 011            -> Read/Write in user and privileged mode
 */

static uint32_t main_translation_table[4096] __attribute__((aligned(1 << 14)));

static void setup_mtt_and_cache(void)
{
	extern void cache_clean(void);
	extern void cache_enable(void *main_ptr);
	for (unsigned i = 0; i < 4096; ++i)
	{
		uint16_t attributes;
		if (i < 0x100)
			attributes = 0x5C06; // DRAM
		else if (i < 0x200)
			attributes = 0x4C12; // DRAM (non-cacheable)
		else if (i < 0xC00)
			attributes = 0x0C12; // device (strongly ordered)
		else if (i < 0xE00)
			attributes = 0x0000; // reserved
		else if (i < 0xE10)
			attributes = 0x0C12; // device (strongly ordered)
		else if (i < 0xF80)
			attributes = 0x0000; // reserved
		else if (i < 0xFF0)
			attributes = 0x0C12; // device (strongly ordered)
		else
			attributes = 0x5C06; // SRAM
		main_translation_table[i] = i << 20 | attributes;
	}
	cache_clean();
	cache_enable(main_translation_table);
	L2C_Enable();
}

__attribute__((target("general-regs-only"), interrupt("ABORT"))) void DAB_Handler(void)
{
	uint32_t DFSR, DFAR;
	__asm__("MRC p15, 0, %0, c5, c0, 0" : "=r"(DFSR));
	__asm__("MRC p15, 0, %0, c6, c0, 0" : "=r"(DFAR));

	show_processor_mode();
	serial_print_hex("DATA ABORT @", DFAR, "\r\n");
	serial_print_hex("STATUS REG.:", DFSR, "\r\n");
}

__attribute__((target("general-regs-only"), interrupt("ABORT"))) void UND_Handler(void)
{
	show_processor_mode();
loop:
	goto loop;
}

int main(void)
{
	setup_mtt_and_cache();
	IRQ_Initialize();
	uart_setup();
	dma_setup();
	
	*(volatile uint32_t *)0xF8F00208 = 1;

	//show_processor_mode();
	__asm__("CPSIE i");
	__asm__("CPS #16");
	//show_processor_mode();

	// main execution
	extern uint8_t _binary_picture_bin_start[];
	static volatile uint8_t rx_buf[RX_TRANSFER_LEN] __attribute__((section(".dma_nocache"), aligned(DMA_ALIGNMENT)));


	// --- Single transfer latency test ---
	event_clear(dma_tx_done | dma_rx_done | dma_tx_err | dma_rx_err);

	enum dma_result rx_res = dma_start_rx((uint32_t)rx_buf, RX_TRANSFER_LEN);
	uint32_t tick = *(volatile uint32_t *)0xF8F00200;
	enum dma_result tx_res = dma_start_tx((uint32_t)_binary_picture_bin_start, TX_TRANSFER_LEN);

	if (rx_res != DMA_OK)
	{
		char err_msg[256];
		sprintf(err_msg, "DMA RX start failed: %s\r\n", dma_result_str[rx_res + DMA_HANDLED_ERRORS]);
		serial_send(err_msg);
		return rx_res;
	}

	if (tx_res != DMA_OK)
	{
		char err_msg[256];
		sprintf(err_msg, "DMA TX start failed: %s\r\n", dma_result_str[tx_res + DMA_HANDLED_ERRORS]);
		serial_send(err_msg);
		return tx_res;
	}

	bool rx_done = false, tx_done = false;

	while (!rx_done || !tx_done)
	{
		wait_for_events(dma_tx_done | dma_rx_done | dma_tx_err | dma_rx_err);

		if (event_test(dma_tx_err))
		{
			event_clear(dma_tx_err);
			serial_send("DMA TX ERROR\r\n");
			return -1;
		}

		if (event_test(dma_rx_err))
		{
			event_clear(dma_rx_err);
			serial_send("DMA RX ERROR\r\n");
			return -1;
		}

		if (event_test(dma_tx_done))
		{
			event_clear(dma_tx_done);
			tx_done = 1;
		}

		if (event_test(dma_rx_done))
		{
			event_clear(dma_rx_done);
			rx_done = 1;
		}
	}

	//uart_send((void *)rx_buf, RX_TRANSFER_LEN);

	tick = *(volatile uint32_t *)0xF8F00200 - tick;
	serial_print_dec("Latency (us): ", tick / 333, "\r\n");
	
/*
	// --- Throughput test: N_TRANSFERS pipelined transfers ---
	event_clear(dma_tx_done | dma_rx_done | dma_tx_err | dma_rx_err);

	int tx_count = 0;
	int rx_count = 0;

	uint32_t tick_start = *(volatile uint32_t *)0xF8F00200;

	// Start first RX and first TX
	dma_start_rx((uint32_t)rx_buf, RX_TRANSFER_LEN);
	dma_start_tx((uint32_t)_binary_picture_bin_start, TX_TRANSFER_LEN);

	while (rx_count < N_TRANSFERS || tx_count < N_TRANSFERS)
	{
		wait_for_events(dma_tx_done | dma_rx_done | dma_tx_err | dma_rx_err);

		if (event_test(dma_tx_err))
		{
			event_clear(dma_tx_err);
			serial_send("DMA TX ERROR\r\n");
			return -1;
		}

		if (event_test(dma_rx_err))
		{
			event_clear(dma_rx_err);
			serial_send("DMA RX ERROR\r\n");
			return -1;
		}

		if (event_test(dma_tx_done))
		{
			event_clear(dma_tx_done);
			tx_count++;
			if (tx_count < N_TRANSFERS)
			{
				dma_start_tx((uint32_t)_binary_picture_bin_start, TX_TRANSFER_LEN);
			}
		}

		if (event_test(dma_rx_done))
		{
			event_clear(dma_rx_done);
			rx_count++;
			if (rx_count < N_TRANSFERS)
			{
				dma_start_rx((uint32_t)rx_buf, RX_TRANSFER_LEN);
			}
		}
	}

	uint32_t tick_total = *(volatile uint32_t *)0xF8F00200 - tick_start;
	serial_print_dec("Total time (ms): ", tick_total / 333333, "\r\n");
	serial_print_dec("Avg time per frame (us): ", (tick_total / 333) / N_TRANSFERS, "\r\n");
*/
	return 0;
}
