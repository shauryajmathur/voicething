#ifndef VOICETHING_RING_H
#define VOICETHING_RING_H
#include <stdatomic.h>
#include <stdint.h>
#include <string.h>

#define VT_RING_FRAMES 32768
#define VT_LATENCY 2048
static _Atomic(uint64_t) vtSamples[VT_RING_FRAMES];
static _Atomic(int64_t) vtTimes[VT_RING_FRAMES];
_Static_assert(ATOMIC_LLONG_LOCK_FREE == 2, "Audio callbacks require lock-free 64-bit atomics");

static void VTRingReset(void) {
    for (int i = 0; i < VT_RING_FRAMES; i++) atomic_store_explicit(&vtTimes[i], INT64_MIN, memory_order_release);
}

static void VTRingWrite(const float *samples, uint32_t count, int64_t start) {
    for (uint32_t i = 0; i < count; i++) {
        int64_t time = start + i;
        uint32_t index = (uint64_t)time % VT_RING_FRAMES;
        uint64_t bits;
        memcpy(&bits, samples + i * 2, sizeof(bits));
        atomic_store_explicit(&vtTimes[index], INT64_MIN, memory_order_seq_cst);
        atomic_store_explicit(&vtSamples[index], bits, memory_order_seq_cst);
        atomic_store_explicit(&vtTimes[index], time, memory_order_seq_cst);
    }
}

static void VTRingRead(float *samples, uint32_t count, int64_t start) {
    for (uint32_t i = 0; i < count; i++) {
        int64_t time = start + i;
        uint32_t index = (uint64_t)time % VT_RING_FRAMES;
        int64_t before = atomic_load_explicit(&vtTimes[index], memory_order_seq_cst);
        uint64_t bits = atomic_load_explicit(&vtSamples[index], memory_order_seq_cst);
        int64_t after = atomic_load_explicit(&vtTimes[index], memory_order_seq_cst);
        if (time < 0 || before != time || after != time) bits = 0;
        memcpy(samples + i * 2, &bits, sizeof(bits));
    }
}
#endif
