/*
!========================================================================
!
!                            S P E C F E M 2 D
!                            -----------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!                and CNRS / University of Marseille, France
!                 (there are currently many more authors!)
! (c) Princeton University and CNRS / University of Marseille, April 2014
!
! This software is a computer program whose purpose is to solve
! the two-dimensional viscoelastic anisotropic or poroelastic wave equation
! using a spectral-element method (SEM).
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
! The full text of the license is available in file "LICENSE".
!
!========================================================================
*/

#ifndef SMOOTH_CUDA_H
#define SMOOTH_CUDA_H

#include "mesh_constants_cuda.h"

// smoothing data structure
typedef struct Smooth_data_ {
  realw * x_me;
  realw * z_me;
  realw * data_smooth;
  realw * normalisation;
  realw * wgll_sq;
  realw sigma_h2_inv;
  realw sigma_v2_inv;
  realw h_criterion;
  realw v_criterion;
  int nspec_me;
  int nker;
} Smooth_data;


#endif  // SMOOTH_CUDA_H
