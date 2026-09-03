
#include "faust/dsp/dsp.h"
#include "faust/gui/meta.h"
#include "faust/gui/DecoratorUI.h"

#define MEMORY_READER
#include "faust/gui/SoundUI.h"

#include <algorithm>
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

// Allows to set buttons/checkbox state
struct ControlUI : public GenericUI {
    
    struct Control {
        
        std::string fLabel;
        FAUSTFLOAT* fZone;
        
        Control(const std::string& label, FAUSTFLOAT* zone) : fLabel(label), fZone(zone)
        {}
    };
    
    std::vector<Control> fButtons;
    std::vector<Control> fCheckbox;
    
    virtual void addButton(const char* label, FAUSTFLOAT* zone)
    {
        fButtons.push_back(Control(label, zone));
    }
    virtual void addCheckButton(const char* label, FAUSTFLOAT* zone)
    {
        fButtons.push_back(Control(label, zone));
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

    SoundUI sound;
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
    
    // Button and checkbox ON on the first buffer
    control.buttonON();
    control.checkboxON();
    
    std::cout << std::setprecision(10);
    
    dsp->compute(kWarmup, inputBuffer, outputBuffer);
    
    // Print at most what was asked for: a short run stops inside the warm-up.
    for (int frame = 0; frame < std::min(frames, kWarmup); ++frame) {
        std::cout << frame;
        for (int ch = 0; ch < numOutputs; ++ch) {
            std::cout << '\t' << outputs[ch][frame];
        }
        std::cout << '\n';
    }
    
    // Button and checkbox OFF
    control.buttonON();
    control.checkboxOFF();
    
    // Then regular computation
    dsp->compute(frames, inputBuffer, outputBuffer);
    
    for (int frame = 0; frame < frames - kWarmup; ++frame) {
        std::cout << frame + kWarmup;
        for (int ch = 0; ch < numOutputs; ++ch) {
            std::cout << '\t' << outputs[ch][frame];
        }
        std::cout << '\n';
    }
     
    return 0;
}
