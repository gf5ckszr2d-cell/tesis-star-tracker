#ifndef STY1_H
#define STY1_H
#include <stdint.h>
#define STY1_WIDTH 320U
#define STY1_HEIGHT 240U
#define STY1_PIXELS (STY1_WIDTH * STY1_HEIGHT)
#define STY1_SIZE (12U + STY1_PIXELS + 1U)
typedef struct {
    uint8_t bytes[STY1_SIZE];
    uint32_t used;
    uint8_t checksum;
} Sty1;
/* 1 complete, 0 pending, -1 dimensions, -2 checksum. */
int sty1_feed(Sty1 *p, uint8_t b);
void sty1_reset(Sty1 *p);
#endif
