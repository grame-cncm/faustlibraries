
#include "faust/dsp/dsp.h"
#include "faust/gui/meta.h"
#include "faust/gui/DecoratorUI.h"

#define MEMORY_READER
#include "faust/gui/SoundUI.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <memory>
#include <vector>
#include <string>

<<includeIntrinsic>>

<<includeclass>>

#ifndef FAUSTFLOAT
#define FAUSTFLOAT float
#endif

// A soundfile of the tests is not read from its file: MemoryReader provides
// SOUND_LENGTH frames of silence, filled here with a decaying sine, one octave
// apart between the channels, so that soundfiles.lib has something to play.
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

// Allows to set buttons/checkbox state, and to read the bargraphs
struct ControlUI : public GenericUI {
    
    struct Control {
        
        std::string fLabel;
        FAUSTFLOAT* fZone;
        
        Control(const std::string& label, FAUSTFLOAT* zone) : fLabel(label), fZone(zone)
        {}
    };
    
    std::vector<Control> fButtons;
    std::vector<Control> fCheckbox;
    std::vector<Control> fBargraphs;
    
    virtual void addHorizontalBargraph(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT, FAUSTFLOAT)
    {
        fBargraphs.push_back(Control(label, zone));
    }
    virtual void addVerticalBargraph(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT, FAUSTFLOAT)
    {
        fBargraphs.push_back(Control(label, zone));
    }
    virtual void addButton(const char* label, FAUSTFLOAT* zone)
    {
        fButtons.push_back(Control(label, zone));
    }
    virtual void addCheckButton(const char* label, FAUSTFLOAT* zone)
    {
        fCheckbox.push_back(Control(label, zone));
    }

    bool hasControls() const
    {
        return !fButtons.empty() || !fCheckbox.empty();
    }
    
    void buttonON()
    {
        for (auto& it: fButtons) {
            *it.fZone = FAUSTFLOAT(1.0);
        }
    }
    
    void buttonOFF()
    {
        for (auto& it: fButtons) {
            *it.fZone = FAUSTFLOAT(0.0);
        }
    }
    
    void checkboxON()
    {
        for (auto& it: fCheckbox) {
            *it.fZone = FAUSTFLOAT(1.0);
        }
    }
    
    void checkboxOFF()
    {
        for (auto& it: fCheckbox) {
            *it.fZone = FAUSTFLOAT(0.0);
        }
    }
};

int main(int argc, char* argv[])
{
    int frames = (argc > 1) ? std::atoi(argv[1]) : 128;
    if (frames <= 0) {
        frames = 128;
    }

    int sampleRate = (argc > 2) ? std::atoi(argv[2]) : 48000;
    if (sampleRate <= 0) {
        sampleRate = 48000;
    }

    // Allocated on the heap: some DSPs have large internal delay-line buffers
    // as class members, which would overflow the stack if `dsp` were a local.
    std::unique_ptr<mydsp> dsp(new mydsp());
    dsp->init(sampleRate);

    ControlUI control;
    dsp->buildUserInterface(&control);

    CompileOptions options;
    dsp->metadata(&options);
    SoundUI sound("", -1, new TestSoundReader(), options.fDouble);
    dsp->buildUserInterface(&sound);

    const int numInputs = dsp->getNumInputs();
    const int numOutputs = dsp->getNumOutputs();

    // The warm-up pass below always computes `kWarmup` frames, so the buffers
    // must hold at least that many even when fewer are requested. Without this
    // the harness writes past the end of the vectors and crashes for any
    // `frames < kWarmup`.
    const int kWarmup = 32;
    const int capacity = std::max(frames, kWarmup);

    std::vector<std::vector<FAUSTFLOAT>> inputs(numInputs, std::vector<FAUSTFLOAT>(capacity, static_cast<FAUSTFLOAT>(0)));
    std::vector<std::vector<FAUSTFLOAT>> outputs(numOutputs, std::vector<FAUSTFLOAT>(capacity, static_cast<FAUSTFLOAT>(0)));

    std::vector<FAUSTFLOAT*> inputPtrs(numInputs);
    std::vector<FAUSTFLOAT*> outputPtrs(numOutputs);

    for (int i = 0; i < numInputs; ++i) {
        inputPtrs[i] = inputs[i].data();
    }
    for (int i = 0; i < numOutputs; ++i) {
        outputPtrs[i] = outputs[i].data();
    }

    FAUSTFLOAT** inputBuffer = numInputs ? inputPtrs.data() : nullptr;
    FAUSTFLOAT** outputBuffer = numOutputs ? outputPtrs.data() : nullptr;
    
    // Control schedule, shared with precision_arch.cpp: every button and
    // checkbox is ON (1) for the first half of the printed frames and OFF (0)
    // for the second half, so that a gate is pressed then released and a
    // checkbox (a bypass, a mode) is rendered in both states, with the
    // transition between them. The run is cut at the release only when the
    // program has a button or a checkbox: the length of each compute() call
    // is the block size (ma.BS), which some functions read.
    control.buttonON();
    control.checkboxON();

    std::cout << std::setprecision(10);

    // Print `count` frames of the last compute(), the first one being frame
    // `start`. The bargraphs follow the outputs, in the order of the interface.
    auto print = [&](int start, int count) {
        for (int frame = 0; frame < count; ++frame) {
            std::cout << start + frame;
            for (int ch = 0; ch < numOutputs; ++ch) {
                std::cout << '\t' << outputs[ch][frame];
            }
            for (auto& it: control.fBargraphs) {
                std::cout << '\t' << *it.fZone;
            }
            std::cout << '\n';
        }
    };

    // A bargraph holds its value at the end of a compute(): a program that has
    // some runs in blocks of kBargraphBlock frames, to follow them over time.
    const int kBargraphBlock = 64;

    // Compute and print `count` frames, the first one being frame `start`.
    auto render = [&](int start, int count) {
        const int block = control.fBargraphs.empty() ? count : kBargraphBlock;
        for (int done = 0; done < count; done += block) {
            const int length = std::min(block, count - done);
            dsp->compute(length, inputBuffer, outputBuffer);
            print(start + done, length);
        }
    };

    dsp->compute(kWarmup, inputBuffer, outputBuffer);
    // Print at most what was asked for: a short run stops inside the warm-up.
    print(0, std::min(frames, kWarmup));

    if (control.hasControls()) {
        const int release = std::max(frames / 2, kWarmup);
        const int pressed = std::max(std::min(release, frames) - kWarmup, 0);
        if (pressed > 0) {
            render(kWarmup, pressed);
        }
        control.buttonOFF();
        control.checkboxOFF();
        const int released = std::max(frames - kWarmup - pressed, 0);
        if (released > 0) {
            render(kWarmup + pressed, released);
        }
    } else {
        // Then regular computation
        render(kWarmup, std::max(frames - kWarmup, 0));
    }

    return 0;
}
