/* UART Low-Level Interface */
/*
 * Copyright © 2023-2025 Giorgio Biagetti <g.biagetti@staff.univpm.it>
 * Department of Information Engineering
 * Università Politecnica delle Marche (ITALY)
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef INC_ZYNQUART_H
#define INC_ZYNQUART_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

/**************************************
 ** Serial Port Communication        **
 **************************************/

// UART low-level driver:

extern void uart_setup (void);

extern void serial_send      (const char *p);
extern void serial_print_dec (const char *prefix, unsigned value, const char *suffix);
extern void serial_print_hex (const char *prefix, uint32_t value, const char *suffix);

// UART higher-level driver:

enum uart_recv_flags {
	uart_fifo_empty = 0x119, // EM  : FIFO underrun
	uart_recv_error = 0x115, // NAK : framing error
	uart_recv_noise = 0x11A, // SUB : noise in symbol
	uart_recv_break = 0x104, // EOT : break detected
	uart_recv_idle  = 0x100, // NUL : idle line detected
};

extern const void *uart_send (const void *data, size_t len);
extern int         uart_post (const void *data, size_t len);
extern void        uart_recv (bool enable);
extern int         uart_read (void);

#endif