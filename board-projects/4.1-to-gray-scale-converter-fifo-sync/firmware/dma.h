#ifndef DMA_H
#define DMA_H

/*
    custom AXI DMA LogiCORE™ IP Application Programming Interface

    Note: 
    As the handshake protocol waits for the receiver TREADY it is useful to first start the receiver,
    than the transmitter, as follow:
    dma_start_rx
    dma_start_tx
*/

#include <stdint.h>

#define MAX_LEN (1u<<20)-1u
#define DMA_ALIGNMENT 4u
#define DMA_ALIGNMENT_MASK 3u

//handled outcomes after initiating a DMA transaction
#define DMA_HANDLED_ERRORS 4
enum dma_result {
    DMA_ERR_BUSY = -4,
    DMA_ERR_INVALID_LEN = -3,
    DMA_ERR_ALIGNMENT,
    DMA_ERR_HALTED,
    DMA_OK
};

void dma_setup(void);
void dma_reset(void);
void dma_stop(void);

int dma_start_rx(uint32_t dst_addr, uint32_t len);
int dma_start_tx(uint32_t src_addr, uint32_t len);

#endif