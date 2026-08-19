"""Compare Pink Trombone render cost against a saved library revision.

Only the selected pinktrombone.lib changes between builds; its dependencies come
from this checkout. This is a local microbenchmark, not a real-time latency test.
"""
import argparse
import json
import os
from pathlib import Path
import shlex
import statistics
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
CASES = {
    "glottis": "pt.glottis(140 + 20*os.osc(0.5), 0.6, 1, 1)",
    "voice": "pt.pinkTrombone2(140, 0.6, 1, 1, 12.9, 2.43, 30, 0.55, 1, 20, 0.8, 1, 0)",
    "moving": (
        "pt.pinkTrombone2(140 + 20*os.osc(0.5), 0.6 + 0.2*os.osc(0.7), 1, 1, "
        "20 + 7*os.osc(0.2), 2.5 + 0.3*os.osc(0.3), 30, 0.55, 1, 20, 0.8, 1, 0)"
    ),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True, help="Saved pre-change pinktrombone.lib")
    parser.add_argument("--candidate", type=Path, default=REPO / "pinktrombone.lib")
    parser.add_argument("--include", type=Path, action="append", default=[], help="C++ header search directory")
    parser.add_argument("--precision", choices=["single", "double"], default="single")
    parser.add_argument("--rounds", type=int, default=9)
    parser.add_argument("--output", type=Path, help="Optional JSON report")
    args = parser.parse_args()
    if args.rounds < 1:
        parser.error("--rounds must be positive")
    libraries = {"baseline": args.baseline.resolve(), "candidate": args.candidate.resolve()}
    for library in libraries.values():
        if not library.is_file():
            parser.error(f"Library does not exist: {library}")
    faust = shlex.split(os.environ.get("FAUST", "faust"))
    cxx = shlex.split(os.environ.get("CXX", "c++"))
    flags = shlex.split(os.environ.get("CXXFLAGS", "-O2 -std=c++17"))
    includes = [flag for path in args.include for flag in ("-I", str(path))]
    report = {
        "sample_rate": 48000, "block_size": 256, "blocks_per_round": 4000,
        "precision": args.precision, "rounds": args.rounds,
        "compiler_flags": flags, "cases": {},
    }
    with tempfile.TemporaryDirectory(prefix="pinktrombone-bench-") as temporary:
        work = Path(temporary)
        # Finish every compilation before timing; build load would bias results.
        for label, library in libraries.items():
            for case, expression in CASES.items():
                stem = work / f"{label}-{case}"
                stem.with_suffix(".dsp").write_text(
                    f"pt = library({json.dumps(str(library))}); "
                    f'os = library("oscillators.lib"); process = {expression};\n'
                )
                subprocess.run(faust + ["-" + args.precision, "-I", str(REPO), "-a",
                                       str(HERE / "benchmark.cpp"), str(stem.with_suffix(".dsp")),
                                       "-o", str(stem.with_suffix(".cpp"))], check=True)
                subprocess.run(cxx + flags + includes + [str(stem.with_suffix(".cpp")),
                                                         "-o", str(stem)], check=True)
        for case in CASES:
            times = {label: [] for label in libraries}
            for round_index in range(args.rounds):
                # Alternate order to reduce warm-up and thermal bias.
                labels = list(libraries) if round_index % 2 == 0 else list(reversed(libraries))
                for label in labels:
                    output = subprocess.check_output([str(work / f"{label}-{case}")], text=True)
                    times[label].append(float(output.split()[0]))
            medians = {label: statistics.median(values) for label, values in times.items()}
            reduction = 100 * (1 - medians["candidate"] / medians["baseline"])
            report["cases"][case] = {"ns_per_sample": times, "median_ns_per_sample": medians,
                                     "time_reduction_percent": reduction}
            print(f"{case}: {medians['baseline']:.2f} -> {medians['candidate']:.2f} ns/sample "
                  f"({reduction:.1f}% less time)", flush=True)
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
