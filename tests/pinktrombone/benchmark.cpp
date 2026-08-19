// Timing harness: 48 kHz, 256-frame blocks, with a deterministic checksum.
#include <chrono>
#include <iostream>
#include <memory>
#include <vector>
#include "faust/dsp/dsp.h"
#include "faust/gui/meta.h"
#include "faust/gui/UI.h"
<<includeIntrinsic>>
<<includeclass>>
int main() {
    auto processor = std::make_unique<mydsp>();
    processor->init(48000);
    const int block = 256, runs = 4000;
    std::vector<std::vector<FAUSTFLOAT>> output(processor->getNumOutputs(), std::vector<FAUSTFLOAT>(block));
    std::vector<FAUSTFLOAT*> pointers;
    for (auto& channel : output) pointers.push_back(channel.data());
    for (int k = 0; k < 50; ++k) processor->compute(block, nullptr, pointers.data());
    double checksum = 0;
    auto start = std::chrono::steady_clock::now();
    for (int k = 0; k < runs; ++k) {
        processor->compute(block, nullptr, pointers.data());
        checksum += output[0][block-1];
    }
    auto end = std::chrono::steady_clock::now();
    double seconds = std::chrono::duration<double>(end-start).count();
    std::cout << seconds * 1e9 / (runs * block) << " " << checksum << "\n";
}
