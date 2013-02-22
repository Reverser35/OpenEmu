#ifndef __OSINT_H
#define __OSINT_H
#include "OEVectrexSystemResponderClient.h"

#define EMU_TIMER			1/60*1000			// milliseconds per frame
#define DEFAULT_WIDTH		660
#define DEFAULT_HEIGHT		820
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

#endif

