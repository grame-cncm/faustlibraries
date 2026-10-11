// Test harness for `scripts/check_precision.py`: same excitation and control
// schedule as print_arch.cpp, but the samples are written in binary, at full
// resolution, so that a -single and a -double build of the same test can be
// compared sample by sample.
//
// Usage: <binary> FRAMES SAMPLE_RATE OUTPUT_FILE [CONTROLS]
// OUTPUT_FILE receives an int32 channel count, then FRAMES frames of
// interleaved float64 samples.
//
// CONTROLS (scripts/check_extremes.py) sets the sliders and number entries
// before the run instead of leaving them at their default: `min` or `max`
// for all of them, `min:I` or `max:I` for the I-th one alone (from 0, in the
// order of buildUserInterface). `list` prints them, one per line
// (index, min, max, init, label, tab-separated), and renders nothing.

// Inputs, outputs and controls are exchanged in double in both builds: the
// precision under test is the one the generated code computes in.
#define FAUSTFLOAT double

#include "faust/dsp/dsp.h"
#include "faust/gui/meta.h"
#include "faust/gui/DecoratorUI.h"

#define MEMORY_READER
#include "faust/gui/SoundUI.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <string>
#include <vector>

<<includeIntrinsic>>

<<includeclass>>

// Same control handling as print_arch.cpp, so that both harnesses test the
// same thing: every button and checkbox is set to 1, then to 0 (see main).
struct ControlUI : public GenericUI {

    std::vector<FAUSTFLOAT*> fControls;

    // The sliders and number entries, for CONTROLS.
    struct Range {
        FAUSTFLOAT* zone;
        FAUSTFLOAT init, min, max;
        std::string label;
    };
    std::vector<Range> fRanges;

    virtual void addButton(const char* label, FAUSTFLOAT* zone) { fControls.push_back(zone); }
    virtual void addCheckButton(const char* label, FAUSTFLOAT* zone) { fControls.push_back(zone); }
    virtual void addHorizontalSlider(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT init,
                                     FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT step)
    {
        fRanges.push_back({zone, init, min, max, label});
    }
    virtual void addVerticalSlider(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT init,
                                   FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT step)
    {
        fRanges.push_back({zone, init, min, max, label});
    }
    virtual void addNumEntry(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT init,
                             FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT step)
    {
        fRanges.push_back({zone, init, min, max, label});
    }

    bool hasControls() const { return !fControls.empty(); }

    void set(FAUSTFLOAT value)
    {
        for (auto zone : fControls) {
            *zone = value;
        }
    }
};

int main(int argc, char* argv[])
{
    if (argc < 4) {
        std::fprintf(stderr, "usage: %s FRAMES SAMPLE_RATE OUTPUT_FILE [CONTROLS]\n", argv[0]);
        return 2;
    }
    int frames = std::max(std::atoi(argv[1]), 1);
    int sampleRate = std::max(std::atoi(argv[2]), 1);

    std::unique_ptr<mydsp> dsp(new mydsp());
    dsp->init(sampleRate);

    ControlUI control;
    dsp->buildUserInterface(&control);

    SoundUI sound;
    dsp->buildUserInterface(&sound);

    if (argc > 4) {
        const std::string mode = argv[4];
        if (mode == "list") {
            for (size_t i = 0; i < control.fRanges.size(); ++i) {
                const auto& r = control.fRanges[i];
                std::printf("%zu\t%.17g\t%.17g\t%.17g\t%s\n", i, double(r.min), double(r.max),
                            double(r.init), r.label.c_str());
            }
            return 0;
        }
        const bool toMax = mode.compare(0, 3, "max") == 0;
        if (!toMax && mode.compare(0, 3, "min") != 0) {
            std::fprintf(stderr, "unknown CONTROLS %s\n", argv[4]);
            return 2;
        }
        const size_t colon = mode.find(':');
        for (size_t i = 0; i < control.fRanges.size(); ++i) {
            if (colon == std::string::npos || std::stoul(mode.substr(colon + 1)) == i) {
                auto& r = control.fRanges[i];
                *r.zone = toMax ? r.max : r.min;
            }
        }
    }

    const int numInputs = dsp->getNumInputs();
    const int numOutputs = dsp->getNumOutputs();

    const int kWarmup = 32;
    const int capacity = std::max(frames, kWarmup);

    std::vector<std::vector<FAUSTFLOAT>> inputs(numInputs, std::vector<FAUSTFLOAT>(capacity, 0.0));
    std::vector<std::vector<FAUSTFLOAT>> outputs(numOutputs, std::vector<FAUSTFLOAT>(capacity, 0.0));
    std::vector<FAUSTFLOAT*> inputPtrs(numInputs);
    std::vector<FAUSTFLOAT*> outputPtrs(numOutputs);
    for (int i = 0; i < numInputs; ++i) inputPtrs[i] = inputs[i].data();
    for (int i = 0; i < numOutputs; ++i) outputPtrs[i] = outputs[i].data();
    FAUSTFLOAT** inputBuffer = numInputs ? inputPtrs.data() : nullptr;
    FAUSTFLOAT** outputBuffer = numOutputs ? outputPtrs.data() : nullptr;

    FILE* out = std::fopen(argv[3], "wb");
    if (!out) {
        std::perror(argv[3]);
        return 2;
    }
    int32_t channels = numOutputs;
    std::fwrite(&channels, sizeof(channels), 1, out);

    std::vector<double> frame(numOutputs);
    auto write = [&](int count) {
        for (int f = 0; f < count; ++f) {
            for (int ch = 0; ch < numOutputs; ++ch) frame[ch] = outputs[ch][f];
            std::fwrite(frame.data(), sizeof(double), numOutputs, out);
        }
    };

    // Same schedule as print_arch.cpp: every button and checkbox is ON for
    // the first half of the FRAMES written and OFF for the second half; the
    // run is cut at the release only when the program has a button or a
    // checkbox (the length of each compute() call is the block size, ma.BS).
    control.set(FAUSTFLOAT(1.0));
    dsp->compute(kWarmup, inputBuffer, outputBuffer);
    write(std::min(frames, kWarmup));
    if (control.hasControls()) {
        const int release = std::max(frames / 2, kWarmup);
        const int pressed = std::max(std::min(release, frames) - kWarmup, 0);
        if (pressed > 0) {
            dsp->compute(pressed, inputBuffer, outputBuffer);
            write(pressed);
        }
        control.set(FAUSTFLOAT(0.0));
        const int released = std::max(frames - kWarmup - pressed, 0);
        if (released > 0) {
            dsp->compute(released, inputBuffer, outputBuffer);
            write(released);
        }
    } else {
        dsp->compute(frames, inputBuffer, outputBuffer);
        write(std::max(frames - kWarmup, 0));
    }

    std::fclose(out);
    return 0;
}
