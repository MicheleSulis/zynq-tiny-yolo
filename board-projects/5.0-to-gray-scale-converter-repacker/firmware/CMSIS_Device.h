#ifndef DEVICE_H
#define DEVICE_H

typedef enum IRQn
{
/* ----------------------  SGI Interrupts Numbers  ----------------------------- */
  SGI0_IRQn                =  0,        /* Software Generated Interrupt  0 */
  SGI1_IRQn                =  1,        /* Software Generated Interrupt  1 */
  SGI2_IRQn                =  2,        /* Software Generated Interrupt  2 */
  SGI3_IRQn                =  3,        /* Software Generated Interrupt  3 */
  SGI4_IRQn                =  4,        /* Software Generated Interrupt  4 */
  SGI5_IRQn                =  5,        /* Software Generated Interrupt  5 */
  SGI6_IRQn                =  6,        /* Software Generated Interrupt  6 */
  SGI7_IRQn                =  7,        /* Software Generated Interrupt  7 */
  SGI8_IRQn                =  8,        /* Software Generated Interrupt  8 */
  SGI9_IRQn                =  9,        /* Software Generated Interrupt  9 */
  SGI10_IRQn               = 10,        /* Software Generated Interrupt 10 */
  SGI11_IRQn               = 11,        /* Software Generated Interrupt 11 */
  SGI12_IRQn               = 12,        /* Software Generated Interrupt 12 */
  SGI13_IRQn               = 13,        /* Software Generated Interrupt 13 */
  SGI14_IRQn               = 14,        /* Software Generated Interrupt 14 */
  SGI15_IRQn               = 15,        /* Software Generated Interrupt 15 */
/* ----------------------  Cortex-A9 Processor Exceptions Numbers  ------------- */
  GlobalTimer_IRQn         = 27,        /* Global Timer Interrupt          */
  PrivTimer_IRQn           = 29,        /* Private Timer Interrupt         */
  PrivWatchdog_IRQn        = 30,        /* Private Watchdog Interrupt      */
/* ----------------------  Platform Interrupt Numbers  ------------------------- */
  UART0_IRQn               = 59,
  UART1_IRQn               = 82,
  DMA_MM2S_IRQn            = 61,
  DMA_S2MM_IRQn            = 62
} IRQn_Type;
#define IRQ_GIC_LINE_COUNT   96

/* ----  Peripheral Memory Map  -------------------------------------------- */
#define GIC_INTERFACE_BASE   0xF8F00100
#define GLOBAL_TIMER_BASE    0xF8F00200
#define TIMER_BASE           0xF8F00600
#define GIC_DISTRIBUTOR_BASE 0xF8F01000
#define L2C_310_BASE         0xF8F02000

/* ----  Configuration of Core Peripherals  -------------------------------- */
#define __CA_REV                  0x0300U   /* Core revision r3p0 */
#define __CORTEX_A                9U        /* Cortex-A9 Core     */
#define __FPU_PRESENT             1U        /* FPU present */
#define __GIC_PRESENT             1U        /* GIC present */
#define __TIM_PRESENT             1U        /* TIM present */
#define __L2C_PRESENT             1U        /* L2C present */

#include <CMSIS/Core/Include/core_ca.h>
#include <CMSIS/Core/Include/a-profile/irq_ctrl.h>

#endif