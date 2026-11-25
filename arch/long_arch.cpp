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
#include <string>
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

// A soundfile of the tests is not read from its file: MemoryReader provides
// SOUND_LENGTH frames of silence (at SOUND_SR, 44.1 kHz), filled here with a
// decaying sine, one octave apart between the channels, so that soundfiles.lib
// has something to play. The same reader as print_arch.cpp (keep them in step):
// with silence, a soundfile player gives 0 in both precisions whatever it reads,
// and it.decrease going the wrong way in -single (issue #335) went unseen.
struct TestSoundReader : public MemoryReader {

    template <typename REAL>
    static void fill(void* buffers, int start)
    {
        const double kPi = 3.14159265358979323846;
        for (int chan = 0; chan < SOUND_CHAN; chan++) {
            for (int sample = 0; sample < SOUND_LENGTH; sample++) {
                const double envelope = 1.0 - double(sample) / SOUND_LENGTH;
                static_cast<REAL**>(buffers)[chan][start + sample] =
                    REAL(envelope * std::sin(2.0 * kPi * (chan + 1) * sample / 64.0));
            }
        }
    }

    virtual void readFile(Soundfile* soundfile, const std::string& path_name, int part, int& offset, int max_chan) override
    {
        MemoryReader::readFile(soundfile, path_name, part, offset, max_chan);
        const int start = offset - SOUND_LENGTH;
        if (soundfile->fIsDouble) {
            fill<double>(soundfile->fBuffers, start);
        } else {
            fill<float>(soundfile->fBuffers, start);
        }
    }
};

// Whether the program was compiled in -double: its soundfiles then hold doubles.
struct CompileOptions : public Meta {

    bool fDouble = false;

    virtual void declare(const char* key, const char* value)
    {
        if (std::string(key) == "compile_options") {
            fDouble = std::string(value).find("-double") != std::string::npos;
        }
    }
};

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
    CompileOptions options;
    dsp->metadata(&options);
    SoundUI sound("", -1, new TestSoundReader(), options.fDouble);
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
