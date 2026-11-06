// Simple UART CLI example.
/*
 * Copyright © 2023-2025 Giorgio Biagetti <g.biagetti@staff.univpm.it>
 * Department of Information Engineering
 * Università Politecnica delle Marche (ITALY)
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

#include "scheduler.h"
#include "uart.h"

#include "build_date.h"


static char    rxbuf[256];
static uint8_t rxcnt;

#define TTY_TITLE   "Zynq-7000 UART Driver Demo"
#define TTY_WELCOME "  Welcome to the " TTY_TITLE

static const char welcome_msg[] =
	"\e[H\e[J\e[3J"                // clear screen (and backscrolling)
	"\e]0;"    TTY_TITLE   "\e\\"  // set terminal window title
	"\e[93m"                       // set welcome text color
		"\e#3" TTY_WELCOME "\r\n"
		"\e#4" TTY_WELCOME "\r\n"
	"\e[m\r\n";

static const char version_msg[] =
	"Firmware version: ";

static const char help_msg[] =
	"Avaiable commands:\r\n"
	"  \e[1mhelp\e[m        print this help message\r\n"
	"  \e[1mlogo\e[m        display the Institution's banner\r\n"
	"  CTRL+\e[1mC\e[m      clear current line\r\n"
	"  CTRL+\e[1mD\e[m      quits demo application\r\n"
	"  CTRL+\e[1mE\e[m      display identification tags\r\n"
	"  \e[3mnum op num\e[m  applies mathematical operator \e[3mop\e[m to the two \e[3mnum\e[mbers\r\n"
;

static const char exit_msg[] =
	"Bye!\r\n";

static const char prompt[] = "\e[32m>\e[97m ";


static const char BACK[] = "\b\e[K"; // ␈␛[K
static const char ESC0[] = "\e[0m";  // ␛[0m
static const char CRLF[] = "\r\n";   // ␍␊


void show_version (void)
{
	uart_post(version_msg, sizeof version_msg - 1);
	uart_post(build_timestamp_str, build_timestamp_len);
	uart_post(CRLF, sizeof CRLF - 1);
}

void show_enquiry (void)
{
	// Send ID: TTY_TITLE
	uart_post("\x01" "ID" "\t\x02", 5); // ␁ID␉␂
	uart_post(TTY_TITLE, __builtin_strlen(TTY_TITLE));
	uart_post(CRLF, sizeof CRLF - 1);
	// Send FW: build_timestamp
	uart_post("\x01" "FW" "\t\x02", 5); // ␁FW␉␂
	uart_post(build_timestamp_str, build_timestamp_len);
	uart_post(CRLF, sizeof CRLF - 1);
	// That's all!
	uart_post("\x03", 1); // ␃
}

void show_control (uint8_t c)
{
	char fmt[] = "\e[96m␀\e[m\r\n";
	size_t len = 13;
	fmt[7] += c;
	uart_post(fmt, len);
}

void show_prompt (void)
{
	uart_post(prompt, sizeof prompt - 1);
	if (rxcnt) uart_post(rxbuf, rxcnt);
}

void show_welcome_msg (void)
{
	uart_post(welcome_msg, sizeof welcome_msg - 1);
	show_version();
	uart_post(prompt, sizeof prompt - 1);
}

void process_input (void)
{
	if (rxcnt == 4 && strncmp(rxbuf, "help", rxcnt) == 0) {
		uart_post(help_msg, sizeof help_msg - 1);
	} else if (rxcnt == 4 && strncmp(rxbuf, "logo", rxcnt) == 0) {
		extern const char _binary_logo_txt_start[];
		uart_post(_binary_logo_txt_start, 0);
	} else {
		double x, y;
		rxbuf[rxcnt] = 0;
		unsigned char op[4];
		int n = sscanf(rxbuf, "%lf %2s %lf", &x, (char *) op, &y);
		if (n == 3) {
			switch (op[0] | op[1] << 8) {
				case '+':
					x += y; break;
				case '-':
					x -= y; break;
				case '*':
				case 0x97C3: // '×'
					x *= y; break;
				case '/':
				case 0xB7C3: // '÷'
					x /= y; break;
				default:
					uart_post("\e[93m: \e[91mError\e[m\r\n", 22);
				op[0] = 0;
			}
			if (op[0]) {
				static char buf[64];
				int n = sprintf(buf, "%s %g%s\r\n", "\e[93m=\e[m\e[1m", x, "\e[m");
				uart_post(buf, n);
			}
		}
	}
	rxcnt = 0;
	uart_post(prompt, sizeof prompt - 1);
}

int cli_run (void)
{
	static int escape = 0;
	static bool connected = false;
//	while (true) {
//		wait_for_event(uart_rx_ready);
		for (uint16_t value; (value = uart_read()) != uart_fifo_empty; ) {
			if (value == uart_recv_break) connected = false;
			if (value == uart_recv_idle && !connected) {
				show_welcome_msg();
				connected = true;
			}
			if (value < 0x100) {
				if (escape) {
					if (value == 24) escape = 0; // CAN
					switch (escape) {
						case 1:
							switch (value) {
								case '[': escape = 2; break;
								case '#': escape = 3; break;
								case ']': escape = 4; break;
								default : escape = 0;
							} break;
						case 2:
							// ignore all escape sequences for now.
							if (value > 0x40) escape = 0;
							break;
						case 3:
							switch (value) {
								case '+': break; // TODO: ECHO ON
								case '-': break; // TODO: ECHO OFF
							}
							escape = 0;
							break;
						case 4:
							if (value == '\e') escape = 5;
							break;
						case 5:
							if (value == '\\') escape = 0; else escape = 4;
							break;
					}
					continue;
				}
				if (value == 0) { // ␀
					// do nothing
				} else if (value == 3) { // ␃
					rxcnt = 0;
					show_control(value);
					show_prompt();
				} else if (value == 4) { // ␄
					show_control(value);
					uart_post(ESC0, sizeof ESC0 - 1);
					uart_post(CRLF, sizeof CRLF - 1);
					uart_post(exit_msg, sizeof exit_msg - 1);
					return 1;
				} else if (value == 5) { // ␅
					show_control(value);
					show_enquiry();
					show_prompt();
				} else if (value == 7) { // ␇
					// blink LED.
				} else if (value == 8   || // ␈
				           value == 127) { // ␡
					if (rxcnt) {
						while (rxcnt) {
							// handle UTF-8 codepoints... sort of...
							uint8_t v = rxbuf[--rxcnt];
							if ((v & 0xC0) != 0x80) break;
						}
						uart_post(BACK, sizeof BACK - 1);
					}
				} else if (value == 13) {
					uart_post(ESC0, sizeof ESC0 - 1);
					uart_post(CRLF, sizeof CRLF - 1);
					process_input();
				} else if (value == 27) {
					escape = 1;
				} else if (value >= 0x20) {
					rxbuf[rxcnt++] = value;
					uart_post(&value, 1);
				}
			}
		}
//	}
	uart_recv(true);
	return 0;
}

