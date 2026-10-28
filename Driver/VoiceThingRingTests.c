#include "VoiceThingRing.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    float source[1024], result[1024];
    for (int i = 0; i < 1024; i++) source[i] = (float)i / 1024;
    VTRingReset();
    VTRingRead(result, 512, 0);
    for (int i = 0; i < 1024; i++) assert(result[i] == 0);
    VTRingWrite(source, 512, 100);
    VTRingRead(result, 512, 100);
    assert(memcmp(source, result, sizeof(source)) == 0);
    VTRingRead(result, 512, 100 + VT_RING_FRAMES);
    for (int i = 0; i < 1024; i++) assert(result[i] == 0);
    VTRingWrite(source, 512, VT_RING_FRAMES - 100);
    VTRingRead(result, 512, VT_RING_FRAMES - 100);
    assert(memcmp(source, result, sizeof(source)) == 0);
    VTRingReset();
    VTRingRead(result, 512, VT_RING_FRAMES - 100);
    for (int i = 0; i < 1024; i++) assert(result[i] == 0);
    VTRingRead(result, 512, -200);
    for (int i = 0; i < 1024; i++) assert(result[i] == 0);
    puts("VoiceThing audio: silence, stereo samples, ring wrap, stale data, reset, and negative timestamps passed.");
    return 0;
}
