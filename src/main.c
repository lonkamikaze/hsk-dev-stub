/** \file
 * Device main.c Stub
 * 
 * @author kami
 */

#include <Infineon/XC878.h>

#include <hsk_boot/hsk_boot.h>

#include "config.h"

void main(void);
void init(void);
void run(void);

/**
 * Call init functions and invoke the run routine.
 */
void main(void) {
	init();
	run();
}

/**
 * Initialize ports, timers and ISRs.
 */
void init(void) {
	/* Activate external clock. */
	hsk_boot_extClock(CLK);
}

/**
 * The main code body.
 */
void run(void) {
	while (1) {
	}
}

