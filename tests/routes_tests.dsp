import("tosc.lib");  // the test source without phase drift (tosc.lib)
ro = library("routes.lib");
os = library("oscillators.lib");

cross_test = (tosc(200), tosc(300), tosc(400)) : ro.cross(3);
crossnn_test = (tosc(110), tosc(220), tosc(330), tosc(440)) : ro.crossnn(2);
crossn1_test = (tosc(100), tosc(200), tosc(300), tosc(400)) : ro.crossn1(3);
cross1n_test = (tosc(150), tosc(250), tosc(350), tosc(450)) : ro.cross1n(3);
crossNM_test = (tosc(180), tosc(280), tosc(380), tosc(480), tosc(580)) : ro.crossNM(2,3);
interleave_test = (tosc(200), tosc(300), tosc(400), tosc(500)) : ro.interleave(2,2);
butterfly_test = (tosc(250), tosc(350), tosc(450), tosc(550)) : ro.butterfly(4);
hadamard_test = (tosc(220), tosc(330), tosc(440), tosc(550)) : ro.hadamard(4);
recursivize_test = (tosc(220), tosc(330)) : ro.recursivize(*(0.5), *(0.3));
bubbleSort_test = (
    hslider("bubbleSort:x0", 0.3, -1, 1, 0.01),
    hslider("bubbleSort:x1", -0.2, -1, 1, 0.01),
    hslider("bubbleSort:x2", 0.8, -1, 1, 0.01),
    hslider("bubbleSort:x3", -0.5, -1, 1, 0.01)
) : ro.bubbleSort(4);
bitonicSort_test = (
    hslider("bubbleSort:x0", 0.3, -1, 1, 0.01),
    hslider("bubbleSort:x1", -0.2, -1, 1, 0.01),
    hslider("bubbleSort:x2", 0.8, -1, 1, 0.01),
    hslider("bubbleSort:x3", -0.5, -1, 1, 0.01)
) : ro.bitonicSort(4);
bitonicSortIdx_test = (
    hslider("bubbleSort:x0", 0.3, -1, 1, 0.01),
    hslider("bubbleSort:x1", -0.2, -1, 1, 0.01),
    hslider("bubbleSort:x2", 0.8, -1, 1, 0.01),
    hslider("bubbleSort:x3", -0.5, -1, 1, 0.01)
) : ro.bitonicSortIdx(4);
cross2_test = (1,2,3,4) : ro.cross2;
