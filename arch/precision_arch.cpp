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
//
// CONTROLS may also hold, comma-separated, after or instead of a setting:
// - `block=N`: compute() in blocks of N frames (ma.BS = N), the buttons and
//   checkboxes released at FRAMES/2 exactly, the block split there; the
//   schedule of scripts/check_backends.py's runners, from frame 0, with no
//   warmup block (scripts/check_backends.py --compare);
// - `nopress`: the buttons and checkboxes are never pressed (`cmaj render`
//   cannot press them);
// - `reinit=SR0`: the program is first initialized at SR0 and run FRAMES
//   frames with the same schedule, then initialized again at SAMPLE_RATE
//   (init(), as a host does when the rate changes) and the second run only
//   is written: it must equal a fresh one (scripts/check_reinit.py);
// - `jump` or `jump:I`: the sliders and number entries (or the I-th alone)
//   jump between their bounds during the run, at the eighths of FRAMES:
//   default, max, min, max, min, max, min, default (scripts/check_jumps.py).
// Any of them selects this schedule, in blocks of 512 unless `block=` says
// otherwise; without them the schedule is that of print_arch.cpp.

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

    // CONTROLS: a setting (min, max, min:I, max:I) and the options of the
    // general schedule (see the header), comma-separated.
    std::string setting;
    int block = 0, reinitRate = 0;
    bool press = true, general = false, jump = false;
    long jumpIndex = -1;
    if (argc > 4) {
        std::string list = argv[4];
        size_t start = 0;
        while (start <= list.size()) {
            const size_t comma = std::min(list.find(',', start), list.size());
            const std::string tok = list.substr(start, comma - start);
            start = comma + 1;
            if (tok.empty()) continue;
            if (tok == "list") {
                for (size_t i = 0; i < control.fRanges.size(); ++i) {
                    const auto& r = control.fRanges[i];
                    std::printf("%zu\t%.17g\t%.17g\t%.17g\t%s\n", i, double(r.min), double(r.max),
                                double(r.init), r.label.c_str());
                }
                return 0;
            } else if (tok.compare(0, 6, "block=") == 0) {
                block = std::max(std::atoi(tok.c_str() + 6), 1);
                general = true;
            } else if (tok == "nopress") {
                press = false;
                general = true;
            } else if (tok.compare(0, 7, "reinit=") == 0) {
                reinitRate = std::max(std::atoi(tok.c_str() + 7), 1);
                general = true;
            } else if (tok == "jump" || tok.compare(0, 5, "jump:") == 0) {
                jump = true;
                jumpIndex = tok.size() > 5 ? std::stol(tok.substr(5)) : -1;
                general = true;
            } else if (tok.compare(0, 3, "min") == 0 || tok.compare(0, 3, "max") == 0) {
                setting = tok;
            } else {
                std::fprintf(stderr, "unknown CONTROLS %s\n", tok.c_str());
                return 2;
            }
        }
    }
    // Sets the sliders and number entries (all, or the I-th of `min:I`) to a bound.
    auto applySetting = [&]() {
        if (setting.empty()) return;
        const bool toMax = setting.compare(0, 3, "max") == 0;
        const size_t colon = setting.find(':');
        for (size_t i = 0; i < control.fRanges.size(); ++i) {
            if (colon == std::string::npos || std::stoul(setting.substr(colon + 1)) == i) {
                auto& r = control.fRanges[i];
                *r.zone = toMax ? r.max : r.min;
            }
        }
    };
    applySetting();

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
    if (general) {
        // The general schedule: blocks of `block` frames, split at the release
        // of the buttons (FRAMES/2) and at the eighths of FRAMES for `jump`.
        if (block == 0) block = 512;
        std::vector<std::vector<FAUSTFLOAT>> gins(numInputs, std::vector<FAUSTFLOAT>(block, 0.0));
        std::vector<std::vector<FAUSTFLOAT>> gouts(numOutputs, std::vector<FAUSTFLOAT>(block, 0.0));
        for (int i = 0; i < numInputs; ++i) inputPtrs[i] = gins[i].data();
        for (int i = 0; i < numOutputs; ++i) outputPtrs[i] = gouts[i].data();
        const int release = frames / 2;
        // the bound of jump segment k (0 to 7): 0 for the default, +1 max, -1 min
        static const int kJumps[8] = {0, 1, -1, 1, -1, 1, -1, 0};
        std::vector<FAUSTFLOAT> defaults;
        for (auto& r : control.fRanges) defaults.push_back(*r.zone);
        auto setJump = [&](int k) {
            for (size_t i = 0; i < control.fRanges.size(); ++i) {
                if (jumpIndex >= 0 && size_t(jumpIndex) != i) continue;
                auto& r = control.fRanges[i];
                *r.zone = kJumps[k] > 0 ? r.max : (kJumps[k] < 0 ? r.min : defaults[i]);
            }
        };
        auto run = [&](bool keep) {
            control.set(FAUSTFLOAT(press ? 1.0 : 0.0));
            int segment = 0;
            for (int pos = 0; pos < frames;) {
                if (control.hasControls() && press && pos == release) control.set(FAUSTFLOAT(0.0));
                if (jump && pos == int((long long)frames * segment / 8)) {
                    setJump(segment);
                    ++segment;
                }
                int next = std::min(pos + block, frames);
                if (control.hasControls() && press && pos < release) next = std::min(next, release);
                if (jump && segment < 8) next = std::min(next, int((long long)frames * segment / 8));
                const int count = next - pos;
                dsp->compute(count, inputBuffer, outputBuffer);
                if (keep) {
                    for (int f = 0; f < count; ++f) {
                        for (int ch = 0; ch < numOutputs; ++ch) frame[ch] = gouts[ch][f];
                        std::fwrite(frame.data(), sizeof(double), numOutputs, out);
                    }
                }
                pos = next;
            }
        };
        if (reinitRate) {
            dsp->init(reinitRate);
            applySetting();
            defaults.clear();
            for (auto& r : control.fRanges) defaults.push_back(*r.zone);
            run(false);
            dsp->init(sampleRate);
            applySetting();
            defaults.clear();
            for (auto& r : control.fRanges) defaults.push_back(*r.zone);
        }
        run(true);
        std::fclose(out);
        return 0;
    }

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
