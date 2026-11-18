/*
    Procedure inspired by: https://docs.amd.com/r/en-US/pg021_axi_dma/Direct-Register-Mode-Simple-DMA

    dma_init:
    1 MM2S_DMACR.RS = 1 -> check if MM2S_DMASR.Halted == 0 
    2 Enable interrupts MM2S_DMACR.IOC_IrqEn and MM2S_DMACR.Err_IrqEn = 1
    3 S2MM_DMACR.RS = 1 -> check if S2MM_DMASR.Halted == 0 
    4 Enable interrupts S2MM_DMACR.IOC_IrqEn and S2MM_DMACR.Err_IrqEn = 1

    dma_stop:
    1 MM2S_DMACR.RS = 0 -> check if MM2S_DMASR.Halted == 1
    2 S2MM_DMACR.RS = 0 -> check if S2MM_DMASR.Halted == 1
    
    dma_reset:
    1 MM2S_DMACR.RESET = 1 -> 
        check if MM2S_DMASR.Halted == 1; 
        check if S2MM_DMACR.Halted == 1; 
        check if MM2S_DMACR.IOC_IrqEn and MM2S_DMACR.Err_IrqEn == 0;
        check if S2MM_DMACR.IOC_IrqEn and S2MM_DMACR.Err_IrqEn == 0;
    NOTE: BIT RESET set to 1 resets all core, not only the channel the register belongs to.

    dma_start_rx:
    1 Write destination address S2MM = 0x... (Align data based on data length and SA)
    2 S2MM_LENGTH = number of bytes to transfer (must be written last)

    dma_start_tx:
    1 Write source address MM2S_SA = 0x... (Align data based on data length and SA)
    2 MM2S_LENGTH = number of bytes to transfer (must be written last)

    dma_clear_interrupt:
    MM2S_DMASR set one to clear IOC_Irq Err_Irq
*/

#include "CMSIS_Device.h"
#include "MyZynq.h"

#include "dma.h"
#include "scheduler.h"
#include "events.h"

static bool tx_started;
static bool rx_started;

inline static uint32_t dma_read(uint32_t addr){
    return *(volatile uint32_t *) addr;
}

inline static void dma_write(uint32_t addr, uint32_t val){
    *(volatile uint32_t *) addr = val;
}

static inline void dma_clear_rx_ioc(void){
    dma_write(S2MM_DMASR, DMA_IOC_IRQ);
}

static inline void dma_clear_rx_err(void){
    dma_write(S2MM_DMASR, DMA_ERR_IRQ);
}

static inline void dma_clear_tx_ioc(void){
    dma_write(MM2S_DMASR, DMA_IOC_IRQ);
}

static inline void dma_clear_tx_err(void){
    dma_write(MM2S_DMASR, DMA_ERR_IRQ);
}

__attribute__ ((target("general-regs-only")))
static void dma_tx_isr(void){
    uint32_t status = dma_read(MM2S_DMASR);

    if(status & DMA_IOC_IRQ){
        dma_clear_tx_ioc();
        event_set(dma_tx_done);
    }

    if(status & DMA_ERR_IRQ){
        dma_clear_tx_err();
        event_set(dma_tx_err);
    }
}

__attribute__ ((target("general-regs-only")))
static void dma_rx_isr(void){
    uint32_t status = dma_read(S2MM_DMASR);

    if(status & DMA_IOC_IRQ){
        dma_clear_rx_ioc();
        event_set(dma_rx_done);
    }

    if(status & DMA_ERR_IRQ){
        dma_clear_rx_err();
        event_set(dma_rx_err);
    }
}

void dma_setup(void){
    tx_started = false;
    rx_started = false;
    // configure tx IRQ:
    IRQ_SetHandler(DMA_MM2S_IRQn, dma_tx_isr);
	IRQ_SetMode(DMA_MM2S_IRQn, IRQ_MODE_TYPE_IRQ | IRQ_MODE_CPU_0 | IRQ_MODE_TRIG_LEVEL | IRQ_MODE_TRIG_LEVEL_HIGH);
	IRQ_SetPriority(DMA_MM2S_IRQn, 0xF0);
	IRQ_Enable(DMA_MM2S_IRQn);

    // configure rx IRQ:
    IRQ_SetHandler(DMA_S2MM_IRQn, dma_rx_isr);
	IRQ_SetMode(DMA_S2MM_IRQn, IRQ_MODE_TYPE_IRQ | IRQ_MODE_CPU_0 | IRQ_MODE_TRIG_LEVEL | IRQ_MODE_TRIG_LEVEL_HIGH);
	IRQ_SetPriority(DMA_S2MM_IRQn, 0xF0);
	IRQ_Enable(DMA_S2MM_IRQn);

    uint32_t ctrl = DMA_RS | DMA_IOC_IRQ_EN | DMA_ERR_IRQ_EN;
    dma_write(MM2S_DMACR, ctrl);
    dma_write(S2MM_DMACR, ctrl);

    while((dma_read(MM2S_DMASR) & DMA_HALTED) || (dma_read(S2MM_DMASR) & DMA_HALTED)) ;
}

void dma_stop(void){
    dma_write(MM2S_DMACR, dma_read(MM2S_DMACR) & ~DMA_RS);
    dma_write(S2MM_DMACR, dma_read(S2MM_DMACR) & ~DMA_RS);

    while(!(dma_read(MM2S_DMASR) & DMA_HALTED) || !(dma_read(S2MM_DMASR) & DMA_HALTED)) ;
}

void dma_reset(void){
    dma_write(MM2S_DMACR, dma_read(MM2S_DMACR) | DMA_RESET); //reset both MM2S and S2MM channels

    while(dma_read(MM2S_DMACR) & DMA_RESET) ; //when DMA_RESET bit returns to 0 reset effect is done
    tx_started = false;
    rx_started = false;
}

int dma_start_rx(uint32_t dst_addr, uint32_t len){
    if(len==0 || len>MAX_LEN)
        return DMA_ERR_INVALID_LEN;
    if(dst_addr&DMA_ALIGNMENT_MASK)
        return DMA_ERR_ALIGNMENT;
    if(dma_read(S2MM_DMASR)&DMA_HALTED)
        return DMA_ERR_HALTED;
    if(rx_started && !(dma_read(S2MM_DMASR)&DMA_IDLE))
        return DMA_ERR_BUSY;

    rx_started = true;
    
    dma_write(S2MM_DA, dst_addr);
    dma_write(S2MM_LENGTH, len); //triggers transfer
    return DMA_OK;
}

int dma_start_tx(uint32_t src_addr, uint32_t len){
    if(len==0||len>MAX_LEN)
        return DMA_ERR_INVALID_LEN;
    if(src_addr&DMA_ALIGNMENT_MASK)
        return DMA_ERR_ALIGNMENT;
    if(dma_read(MM2S_DMASR)&DMA_HALTED)
        return DMA_ERR_HALTED;
    if(tx_started && !(dma_read(MM2S_DMASR)&DMA_IDLE))
        return DMA_ERR_BUSY;

    tx_started = true;

    dma_write(MM2S_SA, src_addr);
    dma_write(MM2S_LENGTH, len); //triggers transfer
    return DMA_OK;
}