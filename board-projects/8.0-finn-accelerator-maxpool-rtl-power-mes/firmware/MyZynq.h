#ifndef MY_ZYNQ_DEVICE_H
#define MY_ZYNQ_DEVICE_H

#include "CMSIS_Device.h"

typedef struct slcr_s {
	uint32_t SCL;
	uint32_t SLCR_LOCK;
	uint32_t SLCR_UNLOCK;
	uint32_t SLCR_LOCKSTA;
	uint32_t unused[0b111000000-4];
	uint32_t MIO_PIN[54];
} slcr_t;

static volatile slcr_t * const slcr = (volatile void *) 0xF8000000;

typedef struct uart_s {
	uint32_t control;
	uint32_t mode;
	uint32_t irq_enable;
	uint32_t irq_disable;
	uint32_t irq_mask;
	uint32_t irq_status;
	uint32_t baud_gen;
	uint32_t rx_timeout;
	uint32_t rx_fifo_trigger;
	uint32_t modem_control;
	uint32_t modem_status;
	uint32_t status;
	uint32_t fifo;
	uint32_t baud_div;
	uint32_t flow_delay;
	uint32_t reserved[2];
	uint32_t tx_fifo_trigger;
} uart_t;

static volatile uart_t * const uart0 = (volatile void *) 0xE0000000;
static volatile uart_t * const uart1 = (volatile void *) 0xE0001000;

#define IRQn_UART0 UART0_IRQn
#define IRQn_UART1 UART1_IRQn

static volatile uart_t * const uart     = uart1;
static          int      const uart_irq = IRQn_UART1;

//DMA register addresses
#define DMABASEADDR 0x40400000
#define MM2S_DMACR  DMABASEADDR + 0x00
#define MM2S_DMASR  DMABASEADDR + 0x04
#define MM2S_SA     DMABASEADDR + 0x18
#define MM2S_LENGTH DMABASEADDR + 0x28
#define S2MM_DMACR  DMABASEADDR + 0x30
#define S2MM_DMASR  DMABASEADDR + 0x34
#define S2MM_DA     DMABASEADDR + 0x48
#define S2MM_LENGTH DMABASEADDR + 0x58

//DMA register bit positions
#define DMA_RS          1u<< 0  //RUNSTOP   Control Register
#define DMA_RESET       1u<< 2  //          Control Register
#define DMA_IOC_IRQ_EN  1u<<12  //          Control Register
#define DMA_ERR_IRQ_EN  1u<<14  //          Control Register
#define DMA_HALTED      1u<< 0  //          Status Register
#define DMA_IDLE        1u<< 1
#define DMA_IOC_IRQ     1u<<12  //          Status Register
#define DMA_ERR_IRQ     1u<<14  //          Status Register

#define TxD 48 // MIO GPIO number
#define RxD 49 // MIO GPIO number

// LEDs have the anode connected to +VCC
// (set GPIO low to light them)
#define LED1 0 // on the PCB it's the one closer to the "DONE"  (red)  LED
#define LED2 9 // on the PCB it's the one closer to the "POWER" (blue) LED

#endif
