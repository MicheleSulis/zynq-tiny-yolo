/* scheduler.c: Useful but platform-dependent functions to handle low-level CPU chores. */
/*
 * Copyright © 2023-2025 Giorgio Biagetti <g.biagetti@staff.univpm.it>
 * Department of Information Engineering
 * Università Politecnica delle Marche (ITALY)
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


// This file is for ARMv7-A

inline static void enable_interrupts (void)
{
	__asm__("cpsie i");
}

inline static void disable_interrupts (void)
{
	__asm__("cpsid i");
}

#include "scheduler.h"

#include <stdatomic.h>

static atomic_int events;

void wait_for_events (uint32_t mask)
{
	register uint32_t arg __asm__("r0") = mask;
	__asm__ ("SVC #1" : : "r" (arg));
}

__attribute__ ((target("general-regs-only"), interrupt("SWI")))
void SVC_Handler (uint32_t mask)
{
	while (1) {
		disable_interrupts();
		if (events & mask) {
//			events &= ~mask;
			enable_interrupts();
			return;
		} else {
			__asm__("dsb");
			__asm__("wfi");
			enable_interrupts();
		}
	}
}

void event_set (uint32_t mask)
{
	events |= mask;
}

bool event_test (uint32_t mask)
{
	return !!(events & mask);
}

void event_clear (uint32_t mask)
{
	events &= ~mask;
}