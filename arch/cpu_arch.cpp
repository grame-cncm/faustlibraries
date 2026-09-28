// CPU harness for `scripts/check_cpu.py`: the "flash" measurement of Yann
// Orlarey's faustcompilerbenchtool (flasharch_footer.cpp, commit 770d5bc,
// https://github.com/orlarey/faustcompilerbenchtool, MIT License,
// Copyright (c) 2024 Yann Orlarey), adapted to the library tests:
//
// - LCG noise on every input (silence would let a filter or a reverb settle
//   to zeros, or to denormals, and measure nothing), 512-frame blocks;
// - a ~200 ms spin before anything is timed: asymmetric schedulers (Apple
//   Silicon) start short processes on efficiency cores and only promote
//   sustained work, so a short run would be timed on a lottery-drawn core;
// - warm-up, then FLASH_REPS repetitions of FLASH_BLOCKS blocks; the result is
//   the BEST ns/frame (the minimum is the machine's clean answer, the rest is
//   scheduling noise);
// - every widget is set to its declared default (the old C++ backend,
//   `-lang ocpp`, assigns defaults only through buildUserInterface).
//
// Changes from the original, for the library tests:
// - buttons and checkboxes are PRESSED by default (FLASH_PRESS=1), as in
//   print_arch.cpp: an instrument test with its gate released renders
//   silence, and its cost would be the cost of silence;
// - soundfiles are loaded (SoundUI, MEMORY_READER), as in print_arch.cpp;
// - the sample rate is FLASH_SR (48000 by default, instead of 44100);
// - the output is checked for non-finite samples outside the timed region
//   (a NaN has its own cost, and a non-finite test measures nothing useful),
//   and reported as `finite=0|1`.
//
// Output: one line, "<best> ns/frame finite=<0|1> (sink <x>)".
// Knobs (environment): FLASH_COUNT (512), FLASH_WARM (400), FLASH_REPS (30),
// FLASH_BLOCKS (200), FLASH_SPIN_MS (200), FLASH_SR (48000), FLASH_PRESS (1).

#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "faust/dsp/dsp.h"
#include "faust/gui/meta.h"
#include "faust/gui/DecoratorUI.h"

#define MEMORY_READER
#include "faust/gui/SoundUI.h"

<<includeIntrinsic>>

<<includeclass>>

// -ffast-math implies -ffinite-math-only: the compiler may then fold
// std::isfinite to true, and even a test on the bits of a value it computed
// (clang does both). The bytes are therefore read through volatile accesses,
// which it cannot reason about.
static bool isFiniteBits(const FAUSTFLOAT* x)
{
    const volatile unsigned char* p = reinterpret_cast<const volatile unsigned char*>(x);
    unsigned char bytes[sizeof(FAUSTFLOAT)];
    for (size_t k = 0; k < sizeof(FAUSTFLOAT); k++) {
        bytes[k] = p[k];
    }
    if (sizeof(FAUSTFLOAT) == sizeof(uint32_t)) {
        uint32_t b;
        memcpy(&b, bytes, sizeof(b));
        return (b & 0x7f800000u) != 0x7f800000u;
    }
    uint64_t b;
    memcpy(&b, bytes, sizeof(b));
    return (b & 0x7ff0000000000000ull) != 0x7ff0000000000000ull;
}

static int envInt(const char* name, int dflt)
{
    const char* v = getenv(name);
    return v ? atoi(v) : dflt;
}

// Writes every widget's declared default into its zone, and the press value
// into the buttons and checkboxes.
struct SetDefaultUI : public GenericUI {
    FAUSTFLOAT press = 1;
    virtual void addButton(const char*, FAUSTFLOAT* z) { *z = press; }
    virtual void addCheckButton(const char*, FAUSTFLOAT* z) { *z = press; }
    virtual void addVerticalSlider(const char*, FAUSTFLOAT* z, FAUSTFLOAT init, FAUSTFLOAT,
                                   FAUSTFLOAT, FAUSTFLOAT)
    {
        *z = init;
    }
    virtual void addHorizontalSlider(const char*, FAUSTFLOAT* z, FAUSTFLOAT init, FAUSTFLOAT,
                                     FAUSTFLOAT, FAUSTFLOAT)
    {
        *z = init;
    }
    virtual void addNumEntry(const char*, FAUSTFLOAT* z, FAUSTFLOAT init, FAUSTFLOAT, FAUSTFLOAT,
                             FAUSTFLOAT)
    {
        *z = init;
    }
};

int main()
{
    const int count  = envInt("FLASH_COUNT", 512);
    const int warm   = envInt("FLASH_WARM", 400);
    const int reps   = envInt("FLASH_REPS", 30);
    const int blocks = envInt("FLASH_BLOCKS", 200);
    const int sr     = envInt("FLASH_SR", 48000);

    mydsp* d = new mydsp();
    d->init(sr);
    SetDefaultUI ui;
    ui.press = FAUSTFLOAT(envInt("FLASH_PRESS", 1));
    d->buildUserInterface(&ui);
    SoundUI sound;
    d->buildUserInterface(&sound);
    int nins  = d->getNumInputs();
    int nouts = d->getNumOutputs();

    FAUSTFLOAT** in  = new FAUSTFLOAT*[nins ? nins : 1];
    FAUSTFLOAT** out = new FAUSTFLOAT*[nouts ? nouts : 1];
    for (int i = 0; i < nins; i++) {
        in[i] = new FAUSTFLOAT[count];
        memset(in[i], 0, count * sizeof(FAUSTFLOAT));
    }
    for (int i = 0; i < nouts; i++) {
        out[i] = new FAUSTFLOAT[count];
    }

    unsigned lcg  = 123456789u;
    auto     fill = [&]() {
        for (int i = 0; i < nins; i++) {
            for (int j = 0; j < count; j++) {
                lcg      = lcg * 1664525u + 1013904223u;
                in[i][j] = FAUSTFLOAT(int(lcg >> 9) % 65536 - 32768) / FAUSTFLOAT(32768);
            }
        }
    };
    bool finite = true;
    auto check  = [&]() {
        for (int i = 0; i < nouts; i++) {
            for (int j = 0; j < count; j++) {
                finite = finite && isFiniteBits(&out[i][j]);
            }
        }
    };

    fill();
    // Core promotion: ~200 ms of insistence buys the fast core before
    // anything is timed. FLASH_SPIN_MS=0 disables it.
    {
        double          spinMs = envInt("FLASH_SPIN_MS", 200);
        volatile double spin   = 1.0;
        auto            t0     = std::chrono::steady_clock::now();
        while (std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0)
                   .count() < spinMs) {
            for (int i = 0; i < 20000; i++) {
                spin = spin * 1.0000001 + 1e-9;
            }
        }
        if (spin < 0) printf("%f", spin);  // keep the loop observable
    }
    for (int w = 0; w < warm; w++) {
        d->compute(count, in, out);
    }
    check();

    double best = 1e30;
    for (int r = 0; r < reps; r++) {
        fill();
        auto t0 = std::chrono::steady_clock::now();
        for (int b = 0; b < blocks; b++) {
            d->compute(count, in, out);
        }
        auto   t1 = std::chrono::steady_clock::now();
        double ns = std::chrono::duration<double, std::nano>(t1 - t0).count() /
                    (double(blocks) * double(count));
        if (ns < best) {
            best = ns;
        }
        check();  // outside the timed region
    }
    // the output buffers must stay observable, or the whole loop is dead code
    double sink = 0;
    for (int i = 0; i < nouts; i++) {
        sink += double(out[i][count - 1]);
    }
    printf("%.3f ns/frame finite=%d (sink %g)\n", best, finite ? 1 : 0, sink);
    return 0;
}
