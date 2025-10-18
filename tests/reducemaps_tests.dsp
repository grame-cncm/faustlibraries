rm = library("reducemaps.lib");

parReduce_test = (1,2,3,4) : rm.parReduce(+, 4);
topReduce_test = (1,2,3,4) : rm.topReduce(+, 4);
botReduce_test = (1,2,3,4) : rm.botReduce(+, 4);
reduce_test = rm.reduce(max, 4, hslider("reduce:input", 0, -1, 1, 0.01));
reducemap_test = rm.reducemap(+, /(4), 4, hslider("reducemap:input", 0, -1, 1, 0.01));
