rm = library("reducemaps.lib");
os = library("oscillators.lib");

parReduce_test = (1,2,3,4) : rm.parReduce(+, 4);
topReduce_test = (1,2,3,4) : rm.topReduce(+, 4);
botReduce_test = (1,2,3,4) : rm.botReduce(+, 4);
reduce_test = os.tosc(440) : rm.reduce(max, 4);
reducemap_test = os.tosc(440) : rm.reducemap(+, /(4), 4);
sumn_test = os.tosc(440) : rm.sumn(64);
maxn_test = os.tosc(440) : rm.maxn(64);
minn_test = os.tosc(440) : rm.minn(64);
mean_test = os.tosc(440) : rm.mean(64);
RMS_test = os.tosc(440) : rm.RMS(64);
