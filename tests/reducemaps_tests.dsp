rm = library("reducemaps.lib");
os = library("oscillators.lib");

parReduce_test = (1,2,3,4) : rm.parReduce(+, 4);
topReduce_test = (1,2,3,4) : rm.topReduce(+, 4);
botReduce_test = (1,2,3,4) : rm.botReduce(+, 4);
reduce_test = rm.reduce(max, 4, hslider("reduce:input", 0.5, -1, 1, 0.01));
reducemap_test = rm.reducemap(+, /(4), 4, hslider("reducemap:input", 0.5, -1, 1, 0.01));
sumn_test = os.osc(440) : rm.sumn(64);
maxn_test = os.osc(440) : rm.maxn(64);
minn_test = os.osc(440) : rm.minn(64);
mean_test = os.osc(440) : rm.mean(64);
RMS_test = os.osc(440) : rm.RMS(64);
