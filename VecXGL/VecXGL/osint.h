#ifndef __OSINT_H
#define __OSINT_H
#include "OEVectrexSystemResponderClient.h"

#define EMU_TIMER			1.0/50.0*1000.0			// milliseconds per frame
#define DEFAULT_WIDTH		330
#define DEFAULT_HEIGHT		410
#define DEFAULT_LINEWIDTH	1.0f
#define DEFAULT_OVERLAYTRANSPARENCY	0.5f

void osint_render (void);
int osint_msgs (void);
void openCart(const char *romName);
int osint_defaults (void);
void osint_gencolors (void);
void osint_emuloop (void);
void osint_btnDown(OEVectrexButton btn);
void osint_btnUp(OEVectrexButton btn);
void initSound(void);
void fillsoundbuffer(void *userdata, uint8_t *stream, int len);

#endif

