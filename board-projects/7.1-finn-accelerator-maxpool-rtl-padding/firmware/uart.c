/* UART Low-Level Interface */
/*
 * Copyright © 2023-2025 Giorgio Biagetti <g.biagetti@staff.univpm.it>
 * Department of Information Engineering
 * Università Politecnica delle Marche (ITALY)
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "CMSIS_Device.h"
#include "MyZynq.h"

#include "uart.h"
#include "scheduler.h"
#include "events.h"
#include <errno.h>


#define UART_FIFO_SIZE 64 // this should be 64 on real HW and 16 on QEMU
#define UART_FIFO_TRIG (UART_FIFO_SIZE * 3 / 4)

// status flags:
#define UART_TxFIFO_EMPTY  8
#define UART_TxFIFO_FULL  16


// very low-level trasmission primitives (do not properly wait in case FIFO fills...):

void serial_send (const char *p)
{
	while (!(uart->status & UART_TxFIFO_EMPTY)) ;
	while (*p) uart->fifo = *p++;
}

void serial_print_dec (const char *prefix, unsigned value, const char *suffix)
{
	if (prefix) serial_send(prefix);
	char *p, buffer[10];
	for (p = buffer; value; value /= 10) *p++ = '0' + value % 10;
	if (p == buffer) *p++ = '0';
	while (!(uart->status & UART_TxFIFO_EMPTY)) ;
	while (p != buffer) uart->fifo = *--p;
	if (suffix) serial_send(suffix);
}

void serial_print_hex (const char *prefix, uint32_t value, const char *suffix)
{
	const char HEX[16] = "0123456789ABCDEF";
	if (prefix) serial_send(prefix);
	while (!(uart->status & UART_TxFIFO_EMPTY)) ;
	for (unsigned i = 8; i; --i) {
		uart->fifo = HEX[value >> 28];
		value <<= 4;
	}
	if (suffix) serial_send(suffix);
}


// marginally better transmission primitives (actually do wait if FIFO fills):

static void const *uart_background_send_ptr;
static size_t      uart_background_send_len;

// This function can be used to send both binary data (by specifying len)
// and zero-terminated strings, by passing len == 0.
// In the former case it may block if there is not enough space in the FIFO,
// but always sends the whole specified length.
// In the latter case it stops when the FIFO fills, and returns a pointer
// to the data not yet transmitted.
const void *uart_send (const void *data, size_t len)
{
	const char *p = data;
	if (len) while (len--) {
		while (uart->status & UART_TxFIFO_FULL) ;
		uart->fifo = *p++;
	} else while (!(uart->status & UART_TxFIFO_FULL)) {
		if (!*p) return NULL;
		uart->fifo = *p++;
	}
	return p;
}

// Transmit queue handling:

struct uart_queue_item
{
	void const *data_ptr;
	size_t      data_len;
};

static unsigned queue_head;
static unsigned queue_tail;
enum {queue_size = 16};

static struct uart_queue_item queue[queue_size];

int uart_post (const void *data, size_t len)
{
	__asm__ volatile ("" : "=m" (queue_head));
	unsigned queue_next = (queue_tail + 1) % queue_size;
	if (queue_next == queue_head) return -ENOSPC;
	queue[queue_tail] = (struct uart_queue_item) {data, len};
	__asm__ volatile ("" : : "m" (queue[queue_tail]));
	queue_tail = queue_next;
	__asm__ volatile ("" : : "m" (queue_tail));
	uart->irq_enable = UART_TxFIFO_EMPTY;
	IRQ_SetPending(uart_irq);
	return 0;
}


// reception handling - this can only be done using interrupts!

static volatile bool idle;

void uart_recv (bool enable)
{
	if (enable)
		uart->irq_enable  = 0x0101; // RxTO + RxWM
	else
		uart->irq_disable = 0x0101; // RxTO + RxWM
}

int uart_read (void)
{
	if (uart->status & 0x02) {
		if (idle) {
			idle = false;
			return uart_recv_idle;
		}
		return uart_fifo_empty;
	} else {
		return uart->fifo;
	}
}



// This is the UART ISR
// it is called in interrupt context,
// so care must be taken on what is accessible!
__attribute__ ((target("general-regs-only")))
static void my_uart_isr (void)
{
	uint32_t irq_mask   = uart->irq_mask;
	uint32_t irq_status = uart->irq_status;

	// Handle TX interrupts:
	if (irq_mask & UART_TxFIFO_EMPTY) { // check if TXEMPTY irq is enabled
		if (!uart_background_send_ptr) {
			// fetch an element from the quque, if any
			if (queue_head == queue_tail) {
				uart->irq_disable = UART_TxFIFO_EMPTY;
				event_set(uart_tx_done);
			} else {
				uart_background_send_ptr = queue[queue_head].data_ptr;
				uart_background_send_len = queue[queue_head].data_len;
				queue_head = (queue_head + 1) % queue_size;
			}
		}
		if (uart_background_send_ptr && (uart->status & UART_TxFIFO_EMPTY)) {
			// a transmission was already in progress
			size_t len = UART_FIFO_SIZE;
			if (len > uart_background_send_len)
				len = uart_background_send_len;
			uart_background_send_ptr = uart_send(uart_background_send_ptr, len);
			if (uart_background_send_len) {
				// check if prefixed-length string is finished:
				uart_background_send_len -= len;
				if (!uart_background_send_len) uart_background_send_ptr = NULL;
			}
		}
	}

	// Handle RX interrupts:
	if (irq_status & 0x101) {
		uart->irq_disable = 0x101;
		event_set(uart_rx_ready);
	}
	uart->irq_status = irq_status;
}

// UART initialization code:
void uart_setup (void)
{
	// Clock divider uses the IO PLL, configured to run at 1.8 GHz (multiplier = 54) by ps7_init,
	// and it is set to 18 -> UART = 100 MHz.
	// Choosing CD=31 and BDIV=6 we have 
	// baud rate = 100000000/(31*7)=460829,49
	// with an +0.0064% error

	// configure baud rate:
	uart->mode = 0x20;
	uart->control = 0b000101000; // disable Rx & Tx

	uart->baud_gen = 31;  // CD    
	uart->baud_div = 6; // BDIV   : set to 14× oversample

	uart->control = 0b000101011; // reset Tx & Rx
	while (uart->control & 3) ;  // wait for reset
	uart->control = 0b000010100; // enable Rx & Tx

	// configure IRQ:
	uart->rx_fifo_trigger = UART_FIFO_TRIG;
	uart->rx_timeout = 5; // 20 symbol time = 2 bytes pause

	IRQ_SetHandler(uart_irq, my_uart_isr);
	IRQ_SetMode(uart_irq, IRQ_MODE_TYPE_IRQ | IRQ_MODE_CPU_0 | IRQ_MODE_TRIG_LEVEL | IRQ_MODE_TRIG_LEVEL_HIGH);
	IRQ_SetPriority(uart_irq, 0xF0);
	IRQ_Enable(uart_irq);
	idle = true;
	event_set(uart_rx_ready);
}