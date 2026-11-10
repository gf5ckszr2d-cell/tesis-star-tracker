#include "sty1.h"
#include <string.h>
void sty1_reset(Sty1 *p) { p->used = 0; p->checksum = 0; }
int sty1_feed(Sty1 *p, uint8_t b)
{
    static const uint8_t header[12] = {'S','T','Y','1',
        STY1_WIDTH & 255, STY1_WIDTH >> 8, STY1_HEIGHT & 255, STY1_HEIGHT >> 8,
        STY1_PIXELS & 255, (STY1_PIXELS >> 8) & 255,
        (STY1_PIXELS >> 16) & 255, (STY1_PIXELS >> 24) & 255};
    if (p->used < 4 && b != header[p->used]) {
        p->used = (b == 'S') ? 1U : 0U;
        if (p->used) p->bytes[0] = b;
        p->checksum = 0;
        return 0;
    }
    p->bytes[p->used++] = b;
    if (p->used == 12 && memcmp(p->bytes, header, 12) != 0) {
        sty1_reset(p); return -1;
    }
    if (p->used > 12 && p->used < STY1_SIZE) p->checksum += b;
    if (p->used == STY1_SIZE) {
        int ok = p->checksum == b;
        sty1_reset(p); /* bytes remain available until next feed */
        return ok ? 1 : -2;
    }
    return 0;
}
