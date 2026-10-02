ro = library("routes.lib");
os = library("oscillators.lib");

cross_test = (os.tosc(200), os.tosc(300), os.tosc(400)) : ro.cross(3);
crossnn_test = (os.tosc(110), os.tosc(220), os.tosc(330), os.tosc(440)) : ro.crossnn(2);
crossn1_test = (os.tosc(100), os.tosc(200), os.tosc(300), os.tosc(400)) : ro.crossn1(3);
cross1n_test = (os.tosc(150), os.tosc(250), os.tosc(350), os.tosc(450)) : ro.cross1n(3);
crossNM_test = (os.tosc(180), os.tosc(280), os.tosc(380), os.tosc(480), os.tosc(580)) : ro.crossNM(2,3);
interleave_test = (os.tosc(200), os.tosc(300), os.tosc(400), os.tosc(500)) : ro.interleave(2,2);
butterfly_test = (os.tosc(250), os.tosc(350), os.tosc(450), os.tosc(550)) : ro.butterfly(4);
hadamard_test = (os.tosc(220), os.tosc(330), os.tosc(440), os.tosc(550)) : ro.hadamard(4);
recursivize_test = (os.tosc(220), os.tosc(330)) : ro.recursivize(*(0.5), *(0.3));
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
