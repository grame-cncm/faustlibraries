#  linearalgebra.lib 

Linear Algebra library. Its official prefix is `la`.

This library provides mathematical tools for matrix and vector operations
in Faust. It includes basic arithmetic, dot products, outer products, matrix inversion,
determinant computation, and utilities for linear transformations and numerical analysis.

This library adds some new linear algebra functions:

`determinant`

`minor`

`inverse`

`transpose2`

`matMul` matrix multiplication

`identity`

`diag`

How does it work? An `NxM` matrix can be flattened into a bus `si.bus(N*M)`. These buses can be passed to functions as long as `N` and sometimes `M` (if the matrix need not be square) are passed too.

#### Some things to think about going forward

##### Implications for ML in Faust

Next step of making a "Dense"/"Linear" layer from machine learning.
Where in the libraries should `ReLU` go?
What about 3D tensors instead of 2D matrices? Image convolutions take place on 3D tensors shaped `HxWxC`.

#####Design of matMul

Currently the design is `matMul(J, K, L, M, leftHandMat, rightHandMat)` where `leftHandMat` is `JxK` and `rightHandMat` is `LxM`.

It would also be neat to have `matMul(J, K, rightHandMat, L, M, leftHandMat)`.

Then a "packed" matrix could be consistently stored as a combination of a 2-channel "header" `N, M` and the values `si.bus(N*M)`.

This would ultimately enable `result = packedLeftHand : matMul(packedRightHand);` for the equivalent numpy code: `result = packedLeftHand @ packedRightHand;`.

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/linearalgebra.lib](https://github.com/grame-cncm/faustlibraries/blob/master/linearalgebra.lib)

----

### `(la.)determinant`

Calculates the determinant of a bus that represents
an `NxN` matrix.

#### Usage
```
si.bus(N*N) : determinant(N) : _
```

Where:

* `N`: the size of each axis of the matrix.

#### Test
```
la = library("linearalgebra.lib");
determinant_test = (1, 2, 3, 4) : la.determinant(2);
```

----

### `(la.)minor`

An utility for finding the matrix minor when inverting a matrix.
It returns the determinant of the submatrix formed by deleting the row at
index `ROW` and column at index `COL`.
The following implementation doesn't work but looks simple.
```
minor(N, ROW, COL) = par(r, N, par(c, N, select2((ROW==r)||(COL==c),_,!))) : determinant(N-1);
```

#### Usage
```
si.bus(N*N) : minor(N, ROW, COL) : _
```

Where:

* `N`: the size of each axis of the matrix.
* `ROW`: the selected position on 0th dimension of the matrix (`0 <= ROW < N`)
* `COL`: the selected position on the 1st dimension of the matrix (`0 <= COL < N`)

#### Test
```
la = library("linearalgebra.lib");
minor_test = (1, 2, 3, 0, 4, 5, 7, 8, 9) : la.minor(3, 1, 1);
```

#### References

* [https://en.wikipedia.org/wiki/Minor_(linear_algebra)#First_minor](https://en.wikipedia.org/wiki/Minor_(linear_algebra)#First_minor)

----

### `(la.)inverse`

Inverts a matrix. The incoming bus represents an `NxN` matrix.
Note, this is an unsafe operation since not all matrices are invertible.

#### Usage
```
si.bus(N*N) : inverse(N) : si.bus(N*N)
```

Where:

* `N`: the size of each axis of the matrix.

#### Test
```
la = library("linearalgebra.lib");
inverse_test = (4, 7, 2, 6) : la.inverse(2);
```

----

### `(la.)transpose2`

Transposes an `NxM` matrix stored in row-major order, resulting
in an `MxN` matrix stored in row-major order.

#### Usage
```
si.bus(N*M) : transpose2(N, M) : si.bus(M*N)
```

Where:

* `N`: the number of rows in the input matrix
* `M`: the number of columns in the input matrix

#### Test
```
la = library("linearalgebra.lib");
transpose2_test = (1, 2, 3, 4, 5, 6) : la.transpose2(2, 3);
```

----

### `(la.)matMul`

Multiply a `JxK` matrix (mat1) and an `LxM` matrix (mat2) to produce a `JxM` matrix.
Note that `K==L`.
Both matrices should use row-major order.
In terms of numpy, this function is `mat1 @ mat2`.

#### Usage
```
matMul(J, K, L, M, si.bus(J*K), si.bus(L*M)) : si.bus(J*M)
```

Where:

* `J`: the number of rows in `mat1`
* `K`: the number of columns in `mat1`
* `L`: the number of rows in `mat2`
* `M`: the number of columns in `mat2`

#### Test
```
la = library("linearalgebra.lib");
matMul_test = (1, 2, 3, 4), (5, 6, 7, 8) : la.matMul(2, 2, 2, 2);
```

----

### `(la.)identity`

Creates an `NxN` identity matrix.

#### Usage
```
identity(N) : si.bus(N*N)
```

Where:

* `N`: The size of each axis of the identity matrix.

#### Test
```
la = library("linearalgebra.lib");
identity_test = la.identity(3);
```

----

### `(la.)diag`

Creates a diagonal matrix of size `NxN` with specified
values along the diagonal.

#### Usage
```
si.bus(N) : diag(N) : si.bus(N*N)
```

Where:

* `N`: The size of each axis of the matrix.

#### Test
```
la = library("linearalgebra.lib");
diag_test = (1, 2, 3) : la.diag(3);
```
