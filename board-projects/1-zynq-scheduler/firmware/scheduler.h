// scheduler.h

#ifndef SCHEDULER_H
#define SCHEDULER_H

#include <stdint.h>
#include <stdbool.h>

extern void wait_for_event (uint32_t mask); // Just one event  - autoclears it!
extern void wait_for_events(uint32_t mask); // Multiple events - user must call event_clear afterwards.

extern void event_set      (uint32_t mask);
extern bool event_test     (uint32_t mask);
extern void event_clear    (uint32_t mask);

#endif
