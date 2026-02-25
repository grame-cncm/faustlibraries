ro = library("routes.lib");
os = library("oscillators.lib");

cross_test = (os.osc(200), os.osc(300), os.osc(400)) : ro.cross(3);
crossnn_test = (os.osc(110), os.osc(220), os.osc(330), os.osc(440)) : ro.crossnn(2);
crossn1_test = (os.osc(100), os.osc(200), os.osc(300), os.osc(400)) : ro.crossn1(3);
cross1n_test = (os.osc(150), os.osc(250), os.osc(350), os.osc(450)) : ro.cross1n(3);
crossNM_test = (os.osc(180), os.osc(280), os.osc(380), os.osc(480), os.osc(580)) : ro.crossNM(2,3);
interleave_test = (os.osc(200), os.osc(300), os.osc(400), os.osc(500)) : ro.interleave(2,2);
butterfly_test = (os.osc(250), os.osc(350), os.osc(450), os.osc(550)) : ro.butterfly(4);
hadamard_test = (os.osc(220), os.osc(330), os.osc(440), os.osc(550)) : ro.hadamard(4);
recursivize_test = (os.osc(220), os.osc(330)) : ro.recursivize(*(0.5), *(0.3));
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
