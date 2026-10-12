// Test harness for `scripts/check_long.py`: a long render analysed as it comes,
// without writing the samples (two minutes at 192 kHz would be 92 MB per
// channel). Same control schedule as print_arch.cpp and precision_arch.cpp:
// every button and checkbox is ON for the first half of the render and OFF
// for the second, the sliders at their default values, the inputs at 0.
//
// Usage: <binary> SECONDS SAMPLE_RATE PRECISION
// PRECISION (single, double) is the one the program was compiled in: a
// sample is subnormal below FLT_MIN in single precision, DBL_MIN in double.
// Prints one line per second of audio, over all the output channels:
//   SECOND PEAK RMS NONFINITE FIRST_NONFINITE_FRAME SUBNORMAL
// PEAK is the largest finite magnitude, RMS the RMS of the finite samples,
// FIRST_NONFINITE_FRAME -1 when the second has no non-finite sample.

// Outputs are exchanged in double in both builds: a subnormal float stays
// subnormal there, and the precision under test is the one of the generated code.
#define FAUSTFLOAT double

#include "faust/dsp/dsp.h"
#include "faust/gui/meta.h"
#include "faust/gui/DecoratorUI.h"

#define MEMORY_READER
#include "faust/gui/SoundUI.h"

#include <algorithm>
#include <cfloat>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <vector>

<<includeIntrinsic>>

<<includeclass>>

// The buttons and checkboxes, set to 1 then to 0 (see main)
struct SwitchUI : public GenericUI {
    std::vector<FAUSTFLOAT*> fZones;

    virtual void addButton(const char* label, FAUSTFLOAT* zone) { fZones.push_back(zone); }
    virtual void addCheckButton(const char* label, FAUSTFLOAT* zone) { fZones.push_back(zone); }

    void set(FAUSTFLOAT value)
    {
        for (auto zone : fZones) {
            *zone = value;
        }
    }
};

int main(int argc, char* argv[])
{
    if (argc < 4) {
        std::fprintf(stderr, "usage: %s SECONDS SAMPLE_RATE PRECISION\n", argv[0]);
        return 2;
    }
    const int    seconds    = std::max(std::atoi(argv[1]), 1);
    const int    sampleRate = std::max(std::atoi(argv[2]), 1);
    const double tiny       = (std::strcmp(argv[3], "single") == 0) ? double(FLT_MIN) : DBL_MIN;

    std::unique_ptr<mydsp> dsp(new mydsp());
    dsp->init(sampleRate);

    SwitchUI switches;
    dsp->buildUserInterface(&switches);
    SoundUI sound;
    dsp->buildUserInterface(&sound);

    const int kBlock     = 1024;
    const int numInputs  = dsp->getNumInputs();
    const int numOutputs = dsp->getNumOutputs();
    std::vector<std::vector<FAUSTFLOAT>> inputs(numInputs, std::vector<FAUSTFLOAT>(kBlock, 0.0));
    std::vector<std::vector<FAUSTFLOAT>> outputs(numOutputs, std::vector<FAUSTFLOAT>(kBlock, 0.0));
    std::vector<FAUSTFLOAT*> inputPtrs(numInputs), outputPtrs(numOutputs);
    for (int i = 0; i < numInputs; ++i) inputPtrs[i] = inputs[i].data();
    for (int i = 0; i < numOutputs; ++i) outputPtrs[i] = outputs[i].data();

    const int64_t total   = int64_t(seconds) * sampleRate;
    const int64_t release = total / 2;
    switches.set(FAUSTFLOAT(1.0));
    bool released = switches.fZones.empty();

    int64_t frame = 0;
    for (int s = 0; s < seconds; ++s) {
        double  peak      = 0.0, sum2 = 0.0;
        int64_t count     = 0;
        int64_t nonfinite = 0, firstNonfinite = -1, subnormal = 0;
        int64_t end       = int64_t(s + 1) * sampleRate;
        while (frame < end) {
            if (!released && frame >= release) {
                switches.set(FAUSTFLOAT(0.0));
                released = true;
            }
            // a block never straddles the release nor the end of the second
            int64_t stop = released ? end : std::min(end, release);
            int     n    = int(std::min<int64_t>(kBlock, stop - frame));
            dsp->compute(n, numInputs ? inputPtrs.data() : nullptr, outputPtrs.data());
            for (int c = 0; c < numOutputs; ++c) {
                const FAUSTFLOAT* out = outputs[c].data();
                for (int k = 0; k < n; ++k) {
                    const double v = out[k];
                    if (!std::isfinite(v)) {
                        if (nonfinite++ == 0) firstNonfinite = frame + k;
                    } else {
                        const double a = std::fabs(v);
                        peak           = std::max(peak, a);
                        sum2 += v * v;
                        count++;
                        if (a != 0.0 && a < tiny) subnormal++;
                    }
                }
            }
            frame += n;
        }
        const double rms = count ? std::sqrt(sum2 / double(count)) : 0.0;
        std::printf("%d %.9g %.9g %lld %lld %lld\n", s, peak, rms, (long long)nonfinite,
                    (long long)firstNonfinite, (long long)subnormal);
    }
    return 0;
}
