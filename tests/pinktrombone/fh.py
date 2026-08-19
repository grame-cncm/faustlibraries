"""DawDreamer helper: compile a Faust string against this repo's libraries and render."""
import os
HERE=os.path.dirname(os.path.abspath(__file__))
REPO=os.path.abspath(os.path.join(HERE,'..','..'))
import dawdreamer as dd, numpy as np
LIBS=[REPO]
def render(code, seconds=1.0, sr=44100, params=None, bs=512, inputs=None):
    e=dd.RenderEngine(sr,bs)
    f=e.make_faust_processor('f')
    f.faust_libraries_paths=LIBS
    f.set_dsp_string(code)
    if not f.compile(): raise RuntimeError(f.code)
    if params:
        for k,v in params.items(): f.set_parameter(k,v)
    if inputs is not None:
        pb=e.make_playback_processor('pb', inputs)
        e.load_graph([(pb,[]),(f,['pb'])])
    else:
        e.load_graph([(f,[])])
    e.render(seconds)
    return f.get_audio()
