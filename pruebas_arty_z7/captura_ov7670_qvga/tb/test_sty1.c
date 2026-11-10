#include "sty1.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static Sty1 p;
static uint8_t frame[STY1_SIZE];
static int feed_frame(void) {
    int result = 0;
    for (unsigned i=0; i<STY1_SIZE; ++i) {
        result = sty1_feed(&p, frame[i]);
        if (i+1<STY1_SIZE) assert(result == 0);
    }
    return result;
}
int main(void) {
    uint8_t header[12] = {'S','T','Y','1',64,1,240,0,0,44,1,0};
    memcpy(frame, header, 12);
    for (unsigned i=0; i<STY1_PIXELS; ++i) frame[12+i] = (uint8_t)(i*5+17);
    memcpy(frame+100,"STY1\r\nFIN\r\nIMG 19213",20);
    for (unsigned i=12; i<STY1_SIZE-1; ++i) frame[STY1_SIZE-1] += frame[i];
    assert(feed_frame()==1);
    assert(memcmp(p.bytes,frame,STY1_SIZE)==0);
    assert(feed_frame()==1); /* successive frame */
    frame[STY1_SIZE-1] ^= 1;
    assert(feed_frame()==-2);
    frame[STY1_SIZE-1] ^= 1;
    frame[4] = 0;
    for (unsigned i=0; i<12; ++i) {
        int r = sty1_feed(&p,frame[i]);
        if (i==11) assert(r==-1);
    }
    frame[4] = 64;
    for (unsigned i=0; i<100; ++i) sty1_feed(&p,frame[i]);
    assert(p.used==100);
    sty1_reset(&p); /* timeout abort */
    assert(feed_frame()==1);
    sty1_feed(&p,'S'); sty1_feed(&p,'S'); /* partial magic overlap */
    for (unsigned i=1; i<STY1_SIZE; ++i) {
        int r = sty1_feed(&p,frame[i]);
        if (i==STY1_SIZE-1) assert(r==1);
    }
    puts("PASS_STY1_C: two frames, binary markers, checksum, dimensions, timeout reset, resync");
    return 0;
}
