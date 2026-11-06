/* exceptions.c: ARM Cortex-A exception table */
/*
 * Copyright © 2025 Giorgio Biagetti <g.biagetti@staff.univpm.it>
 * Department of Information Engineering
 * Università Politecnica delle Marche (ITALY)
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

// This file declares the exception table for ARM Cortex-A processors
// It requires a linker script that places the ".vectors" section
// at the proper address (usually 0x00000000 or 0xFFFF0000).
// The names of the exception handlers are declared as weak symbols
// to allow easy overriding in the user application.

// Undefined handlers are diverted to a tight loop - hopefully never really happens!
__attribute__ ((naked))
static void default_handler (void)
{
	__asm__ ("b .");
}

// The handler names:
void RST_Handler (void) __attribute__ ((weak, used, alias("default_handler")));
void UND_Handler (void) __attribute__ ((weak, used, alias("default_handler")));
void SVC_Handler (    ) __attribute__ ((weak, used, alias("default_handler")));
void PAB_Handler (void) __attribute__ ((weak, used, alias("default_handler")));
void DAB_Handler (void) __attribute__ ((weak, used, alias("default_handler")));
void HYP_Handler (    ) __attribute__ ((weak, used, alias("default_handler")));
void IRQ_Handler (void) __attribute__ ((weak, used, alias("default_handler")));
void FIQ_Handler (void) __attribute__ ((weak, used, alias("default_handler")));

// The exception table:
__attribute__ ((target("arm"), section(".vectors"), naked, used))
static void exception_table (void)
{
	__asm__ (
		"LDR    PC, =RST_Handler \n"
		"LDR    PC, =UND_Handler \n"
		"LDR    PC, =SVC_Handler \n"
		"LDR    PC, =PAB_Handler \n"
		"LDR    PC, =DAB_Handler \n"
		"LDR    PC, =HYP_Handler \n" // unused in the main bank!
		"LDR    PC, =IRQ_Handler \n"
		"LDR    PC, =FIQ_Handler \n"
	);
}
