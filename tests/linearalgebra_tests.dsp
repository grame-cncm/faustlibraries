//----------------------------------------------------------------------------
// linearalgebra_tests.dsp
// Tests for linear algebra helper functions.
//----------------------------------------------------------------------------

la = library("linearalgebra.lib");

determinant_test = (1, 2, 3, 4) : la.determinant(2);

minor_test = (1, 2, 3,
              0, 4, 5,
              7, 8, 9) : la.minor(3, 1, 1);

inverse_test = (4, 7,
                2, 6) : la.inverse(2);

transpose2_test = (1, 2, 3,
                   4, 5, 6) : la.transpose2(2, 3);

matMul_test = (1, 2,
               3, 4),
              (5, 6,
               7, 8) : la.matMul(2, 2, 2, 2);

identity_test = la.identity(3);

diag_test = (1, 2, 3) : la.diag(3);
