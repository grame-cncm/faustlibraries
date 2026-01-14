import("stdfaust.lib");

wd = library("wdmodels.lib");
os = library("oscillators.lib");

resistor_test = wd.buildtree(vsrc : (series_node : (res_leaf, probe)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(220));
  series_node(i) = wd.series(i);
  res_leaf(i) = wd.resistor(i, 1000);
  probe(i) = wd.resistor_Vout(i, 1000);
};

resistor_Vout_test = wd.buildtree(vsrc : (series_node : (res_probe, res_load)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(220));
  series_node(i) = wd.series(i);
  res_probe(i) = wd.resistor_Vout(i, 820);
  res_load(i) = wd.resistor(i, 1800);
};

resistor_Iout_test = wd.buildtree(vsrc : (series_node : (current_probe, load)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(220));
  series_node(i) = wd.series(i);
  current_probe(i) = wd.resistor_Iout(i, 1000);
  load(i) = wd.resistor_Vout(i, 1500);
};

u_voltage_test = wd.buildtree(vsrc : (series_node : (branch_a, branch_b)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(330));
  series_node(i) = wd.series(i);
  branch_a(i) = wd.resistor(i, 1200);
  branch_b(i) = wd.resistor_Vout(i, 2200);
};

u_current_test = wd.buildtree(isrc : (parallel_node : (branch_a, branch_b)))
with {
  isrc(i) = wd.u_current(i, os.osc(110));
  parallel_node(i) = wd.parallel(i);
  branch_a(i) = wd.resistor(i, 560);
  branch_b(i) = wd.resistor_Vout(i, 2200);
};

resVoltage_test = wd.buildtree(vsrc : (series_node : (branch_source, probe)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(440));
  series_node(i) = wd.series(i);
  branch_source(i) = wd.resVoltage(i, 1000, 0.5);
  probe(i) = wd.resistor_Vout(i, 1800);
};

resVoltage_Vout_test = wd.buildtree(vsrc : (series_node : (branch_source, load)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(330));
  series_node(i) = wd.series(i);
  branch_source(i) = wd.resVoltage_Vout(i, 1500, 0.3);
  load(i) = wd.resistor(i, 2200);
};

u_resVoltage_test = wd.buildtree(root : (series_node : (branch_a, branch_b)))
with {
  root(i) = wd.u_resVoltage(i, 1800, os.osc(220));
  series_node(i) = wd.series(i);
  branch_a(i) = wd.resistor(i, 1500);
  branch_b(i) = wd.resistor_Vout(i, 2200);
};

resCurrent_test = wd.buildtree(root : (parallel_node : (source_branch, probe)))
with {
  root(i) = wd.u_current(i, os.osc(110));
  parallel_node(i) = wd.parallel(i);
  source_branch(i) = wd.resCurrent(i, 2200, 0.15);
  probe(i) = wd.resistor_Vout(i, 1500);
};

u_resCurrent_test = wd.buildtree(root : (parallel_node : (branch_a, branch_b)))
with {
  root(i) = wd.u_resCurrent(i, 2000, os.osc(150));
  parallel_node(i) = wd.parallel(i);
  branch_a(i) = wd.resistor(i, 1200);
  branch_b(i) = wd.resistor_Vout(i, 1800);
};

u_switch_test = wd.buildtree(root : (series_node : (branch_a, branch_b)))
with {
  drive = os.osc(330);
  lambda = hslider("u_switch:lambda", -1, -1, 1, 0.01);
  root(i) = wd.u_switch(i, lambda);
  series_node(i) = wd.series(i);
  branch_a(i) = wd.resistor(i, 1000);
  branch_b(i) = wd.resistor_Vout(i, 2200);
};

capacitor_test = wd.buildtree(vsrc : (series_node : (cap_branch, probe)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(440));
  series_node(i) = wd.series(i);
  cap_branch(i) = wd.capacitor(i, 1e-7);
  probe(i) = wd.resistor_Vout(i, 1800);
};

capacitor_Vout_test = wd.buildtree(vsrc : (series_node : (cap_branch, load)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(330));
  series_node(i) = wd.series(i);
  cap_branch(i) = wd.capacitor_Vout(i, 2e-7);
  load(i) = wd.resistor(i, 1500);
};

capacitor_Iout_test = wd.buildtree(vsrc : (series_node : (cap_branch, load)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(440));
  series_node(i) = wd.series(i);
  cap_branch(i) = wd.capacitor_Iout(i, 1e-6);
  load(i) = wd.resistor(i, 1000);
};

inductor_test = wd.buildtree(vsrc : (series_node : (inductive_branch, probe)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(260));
  series_node(i) = wd.series(i);
  inductive_branch(i) = wd.inductor(i, 0.01);
  probe(i) = wd.resistor_Vout(i, 2200);
};

inductor_Vout_test = wd.buildtree(vsrc : (series_node : (inductive_branch, load)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(280));
  series_node(i) = wd.series(i);
  inductive_branch(i) = wd.inductor_Vout(i, 0.02);
  load(i) = wd.resistor(i, 1500);
};

inductor_Iout_test = wd.buildtree(vsrc : (series_node : (inductive_branch, load)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(280));
  series_node(i) = wd.series(i);
  inductive_branch(i) = wd.inductor_Iout(i, 0.02);
  load(i) = wd.resistor(i, 1500);
};

u_idealDiode_test = wd.buildtree(diode : (series_node : (branch_a, branch_b)))
with {
  diode(i) = wd.u_idealDiode(i);
  series_node(i) = wd.series(i);
  branch_a(i) = wd.resistor(i, 1200);
  branch_b(i) = wd.resistor_Vout(i, 1800);
};

u_chua_test = wd.buildtree(chua_node : (series_node : (branch_a, branch_b)))
with {
  chua_node(i) = wd.u_chua(i, 1e-3, 5e-4, 0.2);
  series_node(i) = wd.series(i);
  branch_a(i) = wd.resistor(i, 1500);
  branch_b(i) = wd.resistor_Vout(i, 2200);
};

lambert_test = os.osc(220) * wd.lambert(0.5, 6);

omega_test = wd.omega(0.5);

u_diodePair_test = wd.u_diodePair(2, 1e-12, 0.025);

u_diodeSingle_test = wd.u_diodeSingle(2, 8e-13, 0.026);

u_diodeAntiparallel_test = wd.u_diodeAntiparallel(2, 1e-12, 0.025, 2, 2);

u_diodeAntiparallel_omega_test = wd.u_diodeAntiparallel_omega(2, 2.52e-9, 0.02585, 1, 1);

u_parallel2Port_test = wd.buildtree(root : (branch_source, branch_load))
with {
  root(i) = wd.u_parallel2Port(i);
  branch_source(i) = wd.resVoltage_Vout(i, 1500, 0.2 * os.osc(220));
  branch_load(i) = wd.resistor(i, 1800);
};

parallel2Port_test = wd.buildtree(vsrc : (connector : load))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(260));
  connector(i) = wd.parallel2Port(i);
  load(i) = wd.resistor_Vout(i, 2200);
};

u_series2Port_test = wd.buildtree(root : (branch_source, branch_load))
with {
  root(i) = wd.u_series2Port(i);
  branch_source(i) = wd.resVoltage_Vout(i, 1200, 0.25 * os.osc(180));
  branch_load(i) = wd.resistor(i, 1800);
};

series2Port_test = wd.buildtree(vsrc : (connector : load))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(200));
  connector(i) = wd.series2Port(i);
  load(i) = wd.resistor_Vout(i, 2200);
};

parallelCurrent_test = wd.buildtree(vsrc : (connector : load))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(240));
  connector(i) = wd.parallelCurrent(i, 0.1);
  load(i) = wd.resistor_Vout(i, 1500);
};

seriesVoltage_test = wd.buildtree(vsrc : (connector : load))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(210));
  connector(i) = wd.seriesVoltage(i, 0.3);
  load(i) = wd.resistor_Vout(i, 1500);
};

u_transformer_test = wd.buildtree(root : (primary, secondary))
with {
  root(i) = wd.u_transformer(i, 2.0);
  primary(i) = wd.resVoltage_Vout(i, 1500, 0.2 * os.osc(220));
  secondary(i) = wd.resistor_Vout(i, 2200);
};

transformer_test = wd.buildtree(vsrc : (xfmr : load))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(180));
  xfmr(i) = wd.transformer(i, 2.5);
  load(i) = wd.resistor_Vout(i, 2200);
};

u_transformerActive_test = wd.buildtree(root : (primary, secondary))
with {
  root(i) = wd.u_transformerActive(i, 0.9, 0.8);
  primary(i) = wd.resVoltage_Vout(i, 1200, 0.18 * os.osc(190));
  secondary(i) = wd.resistor_Vout(i, 2200);
};

transformerActive_test = wd.buildtree(vsrc : (xfmr : load))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(175));
  xfmr(i) = wd.transformerActive(i, 0.9, 0.8);
  load(i) = wd.resistor_Vout(i, 2200);
};

parallel_test = wd.buildtree(vsrc : (junction : (branch_a, branch_b)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(220));
  junction(i) = wd.parallel(i);
  branch_a(i) = wd.resistor(i, 1200);
  branch_b(i) = wd.resistor_Vout(i, 1800);
};

series_test = wd.buildtree(vsrc : (junction : (branch_a, branch_b)))
with {
  vsrc(i) = wd.u_voltage(i, os.osc(260));
  junction(i) = wd.series(i);
  branch_a(i) = wd.resistor(i, 1000);
  branch_b(i) = wd.resistor_Vout(i, 2200);
};

u_sixportPassive_test = (1000, 1200, 1400, 1600, 1800, 2000, os.osc(220), 0, 0, 0, 0, 0, 0)
  : wd.u_sixportPassive(0) : _, !, !, !, !;

genericNode_test = wd.genericNode(0, scatter, upRes)(os.osc(220))
with {
  scatter(a) = -a * 0.5;
  upRes = 1200;
};

genericNode_Vout_test = wd.genericNode_Vout(0, scatter, upRes)(os.osc(200)) : _, !
with {
  scatter(a) = -a * 0.4;
  upRes = 1600;
};

genericNode_Iout_test = wd.genericNode_Iout(0, scatter, upRes)(os.osc(230)) : _, !
with {
  scatter(a) = -a * 0.3;
  upRes = 1400;
};

u_genericNode_test = wd.u_genericNode(0, scatter)(os.osc(220))
with {
  scatter(a) = -a * 0.5;
};

builddown_test = wd.builddown(tree) ~ wd.buildup(tree) : wd.buildout(tree)
with {
  vsrc(i) = wd.u_voltage(i, os.osc(220));
  branch(i) = wd.series(i);
  res_leaf(i) = wd.resistor(i, 1200);
  probe(i) = wd.resistor_Vout(i, 1800);
  tree = vsrc : (branch : (res_leaf, probe));
};

buildup_test = wd.builddown(tree) ~ wd.buildup(tree) : wd.buildout(tree)
with {
  vsrc(i) = wd.u_voltage(i, os.osc(220));
  branch(i) = wd.series(i);
  res_leaf(i) = wd.resistor(i, 1200);
  probe(i) = wd.resistor_Vout(i, 1800);
  tree = vsrc : (branch : (res_leaf, probe));
};

getres_test = os.osc(110) * (1.0/(1.0 + getres_value))
with {
  branch(i) = wd.series(i);
  res_leaf(i) = wd.resistor(i, 1200);
  probe(i) = wd.resistor_Vout(i, 1800);
  subtree = branch : (res_leaf, probe);
  getres_value = wd.getres(subtree);
};

parres_test = wd.parres((subtree_left, subtree_right)) : _, !
with {
  left_branch(i) = wd.series(i);
  left_res(i) = wd.resistor(i, 1200);
  left_probe(i) = wd.resistor_Vout(i, 1800);
  subtree_left = left_branch : (left_res, left_probe);

  right_branch(i) = wd.parallel(i);
  right_res(i) = wd.resistor(i, 1500);
  right_probe(i) = wd.resistor(i, 2200);
  subtree_right = right_branch : (right_res, right_probe);
};

buildout_test = wd.builddown(tree) ~ wd.buildup(tree) : buildout_matrix
with {
  vsrc(i) = wd.u_voltage(i, os.osc(240));
  branch(i) = wd.series(i);
  res_leaf(i) = wd.resistor(i, 1200);
  probe(i) = wd.resistor_Vout(i, 1800);
  tree = vsrc : (branch : (res_leaf, probe));
  buildout_matrix = wd.buildout(tree);
};

buildtree_test = wd.buildtree(tree)
with {
  vsrc(i) = wd.u_voltage(i, os.osc(220));
  branch(i) = wd.series(i);
  res_leaf(i) = wd.resistor(i, 1200);
  probe(i) = wd.resistor_Vout(i, 1800);
  tree = vsrc : (branch : (res_leaf, probe));
};
