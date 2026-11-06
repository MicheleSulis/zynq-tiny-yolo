#ifndef EVENTS_H
#define EVENTS_H

enum system_events {
	uart_tx_done  = 1u << 0,
	uart_rx_ready = 1u << 1,

    timer_tick    = 1u << 2,
                  
    dma_tx_done   = 1u << 3,
    dma_rx_done   = 1u << 4,
    dma_tx_err    = 1u << 5,
    dma_rx_err    = 1u << 6
};

#endif