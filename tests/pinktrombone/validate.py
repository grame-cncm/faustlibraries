"""Validate the Faust Pink Trombone port against the Python reference (ptref.py).
Run:  python3.11 validate.py   (needs dawdreamer, numpy, scipy)"""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, ptref, dawdreamer as dd
from fh import render, LIBS
sr=44100


def check_error(label, actual, expected, tolerance, relative=True):
    """Fail on nonfinite output or drift beyond the documented comparison budget."""
    assert np.all(np.isfinite(actual)), f"{label}: nonfinite Faust output"
    assert np.all(np.isfinite(expected)), f"{label}: nonfinite reference output"
    error = np.max(np.abs(actual - expected))
    if relative:
        scale = np.max(np.abs(expected))
        assert scale > 0, f"{label}: silent reference"
        error /= scale
    print(f"{label}: error {error:.3g} (limit {tolerance:g})", flush=True)
    assert error <= tolerance, f"{label}: {error:g} exceeds {tolerance:g}"

# Float32 LF phase error is amplified near the steep return phase (historically
# up to 1.3e-3). Settled tract comparisons have historically been below 2e-6;
# 1e-4 allows compiler rounding without accepting meaningful waveform drift.


# ---- 1. LF waveform ----
for ten in [0.0, 0.3, 0.6, 0.9, 1.0]:
    Rd=3*(1-ten)
    code=f'pt = library("pinktrombone.lib"); process = pt.lfWaveform({Rd}, os.lf_sawpos(100)); import("stdfaust.lib");'
    y=render(code, seconds=0.05)[0]
    t=(np.arange(len(y))*100/sr)%1.0
    p=ptref.lf_params(ten)
    ref=np.array([ptref.lf_wave(tt,p) for tt in t])
    check_error(f"LF tenseness={ten}", y, ref, 2e-3, relative=False)
    print(f"LF tenseness={ten}: max abs err {np.abs(y-ref).max():.2e}  (max |ref| {np.abs(ref).max():.2f})")

# ---- 2. tract steady state, pulse train ----
N=sr
g=np.zeros(N); g[::315]=1.0
ref=ptref.run_tract(sr,g)
inp=np.stack([g,np.full(N,0.3)]).astype(np.float32)
y=render('pt = library("pinktrombone.lib"); process = pt.tract(12.9, 2.43, 30, 3, 0, 0);', seconds=N/sr, inputs=inp)[0][:N]
seg=slice(sr//4, (N//512)*512)
check_error("tract pulse-train", y[seg], ref[seg], 1e-4)
print("tract pulse-train: rel max err after 0.25 s", np.abs(y[seg]-ref[seg]).max()/np.abs(ref[seg]).max())

# ---- 3. tract with different tongue, nasal on ----
for (ti,td,nasal) in [(20,3.2,0),(27,2.2,1),(12,2.05,1)]:
    def run(nasal_flag):
        T=ptref.Tract(sr,512,ti,td); T.velumTarget=0.4 if nasal_flag else 0.01
        out=np.zeros(N)
        for b in range(N//512):
            T.setConstriction(0,3,False)
            for j in range(512):
                k=b*512+j; l1=j/512; l2=(j+0.5)/512
                T.runStep(g[k],0,l1); v=T.lipOutput+T.noseOutput
                T.runStep(g[k],0,l2); v+=T.lipOutput+T.noseOutput
                out[k]=v*0.125
            T.finishBlock()
        return out
    ref=run(nasal)
    y=render(f'pt = library("pinktrombone.lib"); process = pt.tract({ti}, {td}, 30, 3, 0, {nasal});', seconds=N/sr, inputs=inp)[0][:N]
    # velum moves at block rate in JS vs sample rate in Faust => small differences during first ~0.5 s of opening; compare last 0.15s
    seg=slice(N-int(0.15*sr), (N//512)*512)
    check_error(f"tract tongue=({ti},{td}) nasal={nasal}", y[seg], ref[seg], 1e-4)
    print(f"tract tongue=({ti},{td}) nasal={nasal}: rel max err (last 150ms)", np.abs(y[seg]-ref[seg]).max()/np.abs(ref[seg]).max())

# ---- 4. constriction with turbulence (deterministic noise via tractN) ----
rng=np.random.RandomState(0)
noise=rng.uniform(-1,1,N)
cidx,cdia=30.4,0.55
ref=ptref.run_tract(sr,g,constriction=(cidx,cdia,True),noise=noise,noiseMod=0.3)
inp3=np.stack([noise,g,np.full(N,0.3)]).astype(np.float32)
y=render(f'pt = library("pinktrombone.lib"); process = _,_,_ : (\\(nz,gl,nm).(pt.tractN(nz, 12.9, 2.43, {cidx}, {cdia}, 1, 0, gl, nm)));', seconds=N/sr, inputs=inp3)
print("tractN inputs:", y.shape)
y=y[0][:N]
seg=slice(sr//4, (N//512)*512)  # constriction diameters converge over ~0.1-0.2 s (block-rate vs sample-rate slew)
check_error("tract fricative", y[seg], ref[seg], 1e-4)
print("tract fricative: rel max err (after ~0.1s)", np.abs(y[seg]-ref[seg]).max()/np.abs(ref[seg]).max())
print("   corr", np.corrcoef(y[seg],ref[seg])[0,1])

# ---- 5. closure release transient: closure at index 30 for 0.25 s then open ----
nb=-(-N//512)
acts=np.zeros(nb,bool); acts[:int(0.25*sr/512)]=True
ref=ptref.run_tract(sr,g,constriction=(30.0,0.0,acts))
e=dd.RenderEngine(sr,512); f=e.make_faust_processor('f'); f.faust_libraries_paths=LIBS
f.set_dsp_string('pt = library("pinktrombone.lib"); import("stdfaust.lib"); process = pt.tract(12.9, 2.43, 30, 0, checkbox("act"), 0);')
assert f.compile(), f.code
act=np.zeros(N); act[:int(0.25*sr/512)*512]=1
f.set_automation("/dawdreamer/act", act.astype(np.float32))
pb=e.make_playback_processor('pb', inp)
e.load_graph([(pb,[]),(f,['pb'])]); e.render(N/sr)
y=f.get_audio()[0][:N]
t0=int(0.25*sr/512)*512
print("closure release: ref peak after release", np.abs(ref[t0:t0+2000]).max(), " faust", np.abs(y[t0:t0+2000]).max())
seg=slice(t0-2000,t0)
print("   during closure: ref rms", np.sqrt(np.mean(ref[seg]**2)), "faust rms", np.sqrt(np.mean(y[seg]**2)))
seg=slice(t0+4410, N)
print("   after reopen (100ms+): rel err", np.abs(y[seg]-ref[seg]).max()/np.abs(ref[seg]).max())
seg=slice(t0+int(0.3*sr), (N//512)*512)
check_error("closure settled after release", y[seg], ref[seg], 1e-4)
print("   after reopen (300ms+): rel err", np.abs(y[seg]-ref[seg]).max()/np.abs(ref[seg]).max())
i0=np.abs(ref[t0:t0+3000]).argmax(); i1=np.abs(y[t0:t0+3000]).argmax()
print("   peak sample offset ref", i0, "faust", i1)
# Sample-rate geometry differs from the original block-rate geometry during
# release: the documented peaks differ by about 8%, with matching peak timing.
ref_peak = np.max(np.abs(ref[t0:t0+2000]))
actual_peak = np.max(np.abs(y[t0:t0+2000]))
assert ref_peak > 0 and 0.85 <= actual_peak/ref_peak <= 1.15, "release peak drift"
assert abs(i0-i1) <= 2, "release timing drift"
# ---- 6. two simultaneous constrictions (fricative at 36.3 + velar narrowing at 20.6) ----
rng=np.random.RandomState(7); noise2=rng.uniform(-1,1,N)
c1=(36.3, 0.5, True); c2=(20.6, 0.8, True)
ref=ptref.run_tract(sr,g,constrictions=[c1,c2],noise=noise2,noiseMod=0.3)
inp6=np.stack([noise2,g,np.full(N,0.3)]).astype(np.float32)
y=render(f'pt = library("pinktrombone.lib"); process = _,_,_ : (\\(nz,gl,nm).(pt.tractN2(nz, 12.9, 2.43, {c1[0]}, {c1[1]}, 1, {c2[0]}, {c2[1]}, 1, 0, gl, nm)));', seconds=N/sr, inputs=inp6)[0][:N]
seg=slice(sr//4, (N//512)*512)
check_error("tract two-constriction", y[seg], ref[seg], 1e-4)
print("tract two-constriction: rel max err (after 0.25s)", np.abs(y[seg]-ref[seg]).max()/np.abs(ref[seg]).max())

print("All reference comparisons passed.")
