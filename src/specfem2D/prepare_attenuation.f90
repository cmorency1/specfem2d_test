!========================================================================
!
!                   S P E C F E M 2 D  Version 7 . 0
!                   --------------------------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                              CNRS, France
!                       and Princeton University, USA
!                 (there are currently many more authors!)
!                           (c) October 2017
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


  subroutine prepare_attenuation()

  use constants, only: IMAIN,TWO,PI,FOUR_THIRDS,TWO_THIRDS,USE_A_STRONG_FORMULATION_FOR_E1
  use specfem_par

  implicit none

  ! local parameters
  integer :: i,j,ispec,n,ier

  ! for shifting of velocities if needed in the case of viscoelasticity
  double precision :: vp,vs,rhol,mul,lambdal,kappal
  double precision :: qkappal,qmul

  ! attenuation factors
  real(kind=CUSTOM_REAL) :: Mu_nu1_sent,Mu_nu2_sent
  real(kind=CUSTOM_REAL), dimension(:), allocatable :: tau_epsilon_nu1_sent,tau_epsilon_nu2_sent
  real(kind=CUSTOM_REAL), dimension(:), allocatable :: inv_tau_sigma_nu1_sent,inv_tau_sigma_nu2_sent, &
                                                       phi_nu1_sent,phi_nu2_sent
  real(kind=CUSTOM_REAL), dimension(N_SLS) ::  phinu,tauinvnu,temp,coef
  ! attenuation shift
  logical, dimension(:), allocatable :: already_shifted_velocity

  ! attenuation
  ! user output
  if (myrank == 0) then
    write(IMAIN,*)
    write(IMAIN,*) 'Attenuation:'
    write(IMAIN,*) '  viscoelastic  attenuation:',ATTENUATION_VISCOELASTIC
    write(IMAIN,*) '  viscoacoustic attenuation:',ATTENUATION_VISCOACOUSTIC
    write(IMAIN,*)
    call flush_IMAIN()
  endif

  ! array allocations
  if (ATTENUATION_VISCOELASTIC) then
    nspec_ATT_el = nspec
  else
    nspec_ATT_el = 1
  endif

  ! allocate memory variables for attenuation
  allocate(e1(N_SLS,NGLLX,NGLLZ,nspec_ATT_el), &
           e11(N_SLS,NGLLX,NGLLZ,nspec_ATT_el), &
           e13(N_SLS,NGLLX,NGLLZ,nspec_ATT_el), &
           dux_dxl_old(NGLLX,NGLLZ,nspec_ATT_el), &
           duz_dzl_old(NGLLX,NGLLZ,nspec_ATT_el), &
           dux_dzl_plus_duz_dxl_old(NGLLX,NGLLZ,nspec_ATT_el), &
           A_newmark_nu1(N_SLS,NGLLX,NGLLZ,nspec_ATT_el), &
           B_newmark_nu1(N_SLS,NGLLX,NGLLZ,nspec_ATT_el), &
           A_newmark_nu2(N_SLS,NGLLX,NGLLZ,nspec_ATT_el), &
           B_newmark_nu2(N_SLS,NGLLX,NGLLZ,nspec_ATT_el), stat=ier)

  ! attenuation
  if (ATTENUATION_VISCOACOUSTIC) then
    nglob_ATT = nglob
    nspec_ATT_ac = nspec
  else
    nglob_ATT = 1
    nspec_ATT_ac = 1
  endif

  allocate(e1_acous_sf(N_SLS,NGLLX,NGLLZ,nspec_ATT_ac), &
           sum_forces_old(NGLLX,NGLLZ,nspec_ATT_ac), stat=ier)

  if (ATTENUATION_VISCOACOUSTIC .and. .not. USE_A_STRONG_FORMULATION_FOR_E1) then

    allocate(e1_acous(nglob_acoustic,N_SLS), &
             dot_e1(nglob_acoustic,N_SLS), &
             A_newmark_e1_sf(1,1,1,1), &
             B_newmark_e1_sf(1,1,1,1),stat=ier)
    if (time_stepping_scheme == 1) then
      allocate(dot_e1_old(nglob_acoustic,N_SLS), &
               A_newmark_e1(nglob_acoustic,N_SLS), &
               B_newmark_e1(nglob_acoustic,N_SLS),stat=ier)
    else
      allocate(dot_e1_old(1,N_SLS), &
               A_newmark_e1(1,N_SLS), &
               B_newmark_e1(1,N_SLS),stat=ier)
    endif

    if (time_stepping_scheme == 2) then
      allocate(e1_acous_temp(nglob_acoustic,N_SLS),stat=ier)
    else
      allocate(e1_acous_temp(1,N_SLS),stat=ier)
    endif

  else if (ATTENUATION_VISCOACOUSTIC .and. USE_A_STRONG_FORMULATION_FOR_E1) then

    allocate(e1_acous(1,N_SLS), &
             e1_acous_temp(1,N_SLS), &
             dot_e1(1,N_SLS), &
             dot_e1_old(1,N_SLS), &
             A_newmark_e1(1,N_SLS), &
             B_newmark_e1(1,N_SLS),stat=ier)
    allocate(A_newmark_e1_sf(N_SLS,NGLLX,NGLLZ,nspec), &
             B_newmark_e1_sf(N_SLS,NGLLX,NGLLZ,nspec),stat=ier)

  else ! no ATTENUATION_VISCOACOUSTIC

    allocate(e1_acous(1,N_SLS), &
             e1_acous_temp(1,N_SLS), &
             dot_e1(1,N_SLS), &
             dot_e1_old(1,N_SLS), &
             A_newmark_e1(1,N_SLS), &
             B_newmark_e1(1,N_SLS), &
             A_newmark_e1_sf(1,1,1,1), &
             B_newmark_e1_sf(1,1,1,1),stat=ier)
  endif
  if (ier /= 0) call stop_the_code('Error allocating attenuation arrays')

  e1(:,:,:,:) = 0._CUSTOM_REAL
  e11(:,:,:,:) = 0._CUSTOM_REAL
  e13(:,:,:,:) = 0._CUSTOM_REAL
  dux_dxl_old(:,:,:) = 0._CUSTOM_REAL
  duz_dzl_old(:,:,:) = 0._CUSTOM_REAL
  dux_dzl_plus_duz_dxl_old(:,:,:) = 0._CUSTOM_REAL

  e1_acous(:,:) = 0._CUSTOM_REAL
  e1_acous_sf(:,:,:,:) = 0._CUSTOM_REAL

  dot_e1_old = 0._CUSTOM_REAL
  dot_e1     = 0._CUSTOM_REAL
  sum_forces_old = 0._CUSTOM_REAL

  if (SIMULATION_TYPE == 3) then
    if (any_acoustic) then
      allocate(b_e1_acous_sf(N_SLS,NGLLX,NGLLZ,nspec_ATT_ac), &
               b_sum_forces_old(NGLLX,NGLLZ,nspec_ATT_ac),stat=ier)
      if (ier /= 0) call stop_the_code('Error allocating acoustic attenuation arrays')
      b_e1_acous_sf(:,:,:,:) = 0._CUSTOM_REAL
      b_sum_forces_old(:,:,:) = 0._CUSTOM_REAL
    endif
    if (any_elastic) then
      allocate(b_e1(N_SLS,NGLLX,NGLLZ,nspec_ATT_el), &
               b_e11(N_SLS,NGLLX,NGLLZ,nspec_ATT_el), &
               b_e13(N_SLS,NGLLX,NGLLZ,nspec_ATT_el), &
               b_dux_dxl_old(NGLLX,NGLLZ,nspec_ATT_el), &
               b_duz_dzl_old(NGLLX,NGLLZ,nspec_ATT_el), &
               b_dux_dzl_plus_duz_dxl_old(NGLLX,NGLLZ,nspec_ATT_el),stat=ier)
      if (ier /= 0) call stop_the_code('Error allocating attenuation arrays')
      b_e1(:,:,:,:) = 0._CUSTOM_REAL
      b_e11(:,:,:,:) = 0._CUSTOM_REAL
      b_e13(:,:,:,:) = 0._CUSTOM_REAL
      b_dux_dxl_old(:,:,:) = 0._CUSTOM_REAL
      b_duz_dzl_old(:,:,:) = 0._CUSTOM_REAL
      b_dux_dzl_plus_duz_dxl_old(:,:,:) = 0._CUSTOM_REAL
    endif
  endif

  if (time_stepping_scheme == 2) then
    if (ATTENUATION_VISCOELASTIC) then
      allocate(e1_LDDRK(NGLLX,NGLLZ,nspec_ATT_el,N_SLS))
      allocate(e11_LDDRK(NGLLX,NGLLZ,nspec_ATT_el,N_SLS))
      allocate(e13_LDDRK(NGLLX,NGLLZ,nspec_ATT_el,N_SLS))
    else
      allocate(e1_LDDRK(1,1,1,1))
      allocate(e11_LDDRK(1,1,1,1))
      allocate(e13_LDDRK(1,1,1,1))
    endif

    if (ATTENUATION_VISCOACOUSTIC) then
        allocate(e1_LDDRK_acous(nglob_att,N_SLS))
    else
        allocate(e1_LDDRK_acous(1,1))
    endif
  else
    allocate(e1_LDDRK(1,1,1,1))
    allocate(e11_LDDRK(1,1,1,1))
    allocate(e13_LDDRK(1,1,1,1))

    allocate(e1_LDDRK_acous(1,1))
  endif
  e1_LDDRK(:,:,:,:) = 0._CUSTOM_REAL
  e11_LDDRK(:,:,:,:) = 0._CUSTOM_REAL
  e13_LDDRK(:,:,:,:) = 0._CUSTOM_REAL

  e1_LDDRK_acous(:,:) = 0._CUSTOM_REAL

  if (time_stepping_scheme == 3) then
    allocate(e1_initial_rk(NGLLX,NGLLZ,nspec_ATT_el,N_SLS))
    allocate(e11_initial_rk(NGLLX,NGLLZ,nspec_ATT_el,N_SLS))
    allocate(e13_initial_rk(NGLLX,NGLLZ,nspec_ATT_el,N_SLS))
    allocate(e1_force_rk(NGLLX,NGLLZ,nspec_ATT_el,N_SLS,stage_time_scheme))
    allocate(e11_force_rk(NGLLX,NGLLZ,nspec_ATT_el,N_SLS,stage_time_scheme))
    allocate(e13_force_rk(NGLLX,NGLLZ,nspec_ATT_el,N_SLS,stage_time_scheme))

    if (ATTENUATION_VISCOACOUSTIC) then
            allocate(e1_initial_rk_acous(nglob_att,N_SLS))
            allocate(e1_force_rk_acous(nglob_att,N_SLS,stage_time_scheme))
    else
            allocate(e1_initial_rk_acous(1,1))
            allocate(e1_force_rk_acous(1,1,1))
    endif
  else
    allocate(e1_initial_rk(1,1,1,1))
    allocate(e11_initial_rk(1,1,1,1))
    allocate(e13_initial_rk(1,1,1,1))
    allocate(e1_force_rk(1,1,1,1,1))
    allocate(e11_force_rk(1,1,1,1,1))
    allocate(e13_force_rk(1,1,1,1,1))

    allocate(e1_initial_rk_acous(1,1))
    allocate(e1_force_rk_acous(1,1,1))
  endif
  e1_initial_rk(:,:,:,:) = 0._CUSTOM_REAL
  e11_initial_rk(:,:,:,:) = 0._CUSTOM_REAL
  e13_initial_rk(:,:,:,:) = 0._CUSTOM_REAL
  e1_force_rk(:,:,:,:,:) = 0._CUSTOM_REAL
  e11_force_rk(:,:,:,:,:) = 0._CUSTOM_REAL
  e13_force_rk(:,:,:,:,:) = 0._CUSTOM_REAL

  e1_initial_rk_acous(:,:) = 0._CUSTOM_REAL
  e1_force_rk_acous(:,:,:) = 0._CUSTOM_REAL

  ! attenuation arrays
  if (.not. assign_external_model) then
    allocate(already_shifted_velocity(numat),stat=ier)
    if (ier /= 0) call stop_the_code('Error allocating attenuation Qkappa,Qmu,.. arrays')
    already_shifted_velocity(:) = .false.
  else
    ! dummy
    allocate(already_shifted_velocity(1),stat=ier)
    if (ier /= 0) call stop_the_code('Error allocating attenuation Qkappa,Qmu,.. arrays')
  endif

  allocate(inv_tau_sigma_nu1(NGLLX,NGLLZ,max(nspec_ATT_el,nspec_ATT_ac),N_SLS), &
           inv_tau_sigma_nu2(NGLLX,NGLLZ,max(nspec_ATT_el,nspec_ATT_ac),N_SLS), &
           phi_nu1(NGLLX,NGLLZ,max(nspec_ATT_el,nspec_ATT_ac),N_SLS), &
           phi_nu2(NGLLX,NGLLZ,max(nspec_ATT_el,nspec_ATT_ac),N_SLS), &
           Mu_nu1(NGLLX,NGLLZ,max(nspec_ATT_el,nspec_ATT_ac)), &
           Mu_nu2(NGLLX,NGLLZ,max(nspec_ATT_el,nspec_ATT_ac)), &
! ZX ZX needed for further optimization with nspec_ATT_el replaced with nspec_PML
           tau_epsilon_nu1(NGLLX,NGLLZ,max(nspec_ATT_el,nspec_ATT_ac),N_SLS), &
           tau_epsilon_nu2(NGLLX,NGLLZ,max(nspec_ATT_el,nspec_ATT_ac),N_SLS),stat=ier)
  if (ier /= 0) call stop_the_code('Error allocating attenuation arrays')

  ! temporary arrays for function argument
  allocate(tau_epsilon_nu1_sent(N_SLS), &
           tau_epsilon_nu2_sent(N_SLS), &
           inv_tau_sigma_nu1_sent(N_SLS), &
           inv_tau_sigma_nu2_sent(N_SLS), &
           phi_nu1_sent(N_SLS), &
           phi_nu2_sent(N_SLS),stat=ier)
  if (ier /= 0) call stop_the_code('Error allocating attenuation coefficient arrays')

  ! initialize to dummy values
  ! convention to indicate that Q = 9999 in that element i.e. that there is no viscoelasticity in that element
  inv_tau_sigma_nu1(:,:,:,:) = -1._CUSTOM_REAL
  inv_tau_sigma_nu2(:,:,:,:) = -1._CUSTOM_REAL

  tau_epsilon_nu1(:,:,:,:) = -1._CUSTOM_REAL
  tau_epsilon_nu2(:,:,:,:) = -1._CUSTOM_REAL

  phi_nu1(:,:,:,:) = 0._CUSTOM_REAL
  phi_nu2(:,:,:,:) = 0._CUSTOM_REAL

  ! do not change this, in the case of a viscoacoustic medium the mass matrix is multiplied by this,
  ! and thus the factor needs to be equal to +1 when QKappa = 9999 i.e. when viscoacousticity is turned off in parts of the medium
  Mu_nu1(:,:,:) = +1._CUSTOM_REAL
  Mu_nu2(:,:,:) = +1._CUSTOM_REAL

  ! if source is not a Dirac or Heavyside then ATTENUATION_f0_REFERENCE is f0 of the first source
  if (.not. (time_function_type(1) == 4 .or. time_function_type(1) == 5)) then
    ATTENUATION_f0_REFERENCE = f0_source(1)
  endif

  ! setup attenuation
  if (ATTENUATION_VISCOELASTIC .or. ATTENUATION_VISCOACOUSTIC) then
    ! user output
    if (myrank == 0) then
      write(IMAIN,*) 'Preparing attenuation in viscoelastic or viscoacoustic parts of the model:'
      write(IMAIN,*) '  using external model for Qkappa and Qmu: ',assign_external_model
      write(IMAIN,*) '  reading velocity at f0                 : ',READ_VELOCITIES_AT_f0
      write(IMAIN,*) '  using an attenuation reference frequency of ',ATTENUATION_f0_REFERENCE,'Hz'
      write(IMAIN,*)
      call flush_IMAIN()
    endif

    ! define the attenuation quality factors.
    do ispec = 1,nspec

      ! get values for internal meshes
      if (.not. assign_external_model) then
        qkappal = QKappa_attenuationcoef(kmato(ispec))
        qmul = Qmu_attenuationcoef(kmato(ispec))
        ! if no attenuation in that elastic element
        if (qkappal > 9998.999d0 .and. qmul > 9998.999d0) cycle

        ! determines attenuation factors
        call attenuation_model(qkappal,qmul,ATTENUATION_f0_REFERENCE,N_SLS, &
                               tau_epsilon_nu1_sent,inv_tau_sigma_nu1_sent,phi_nu1_sent,Mu_nu1_sent, &
                               tau_epsilon_nu2_sent,inv_tau_sigma_nu2_sent,phi_nu2_sent,Mu_nu2_sent)
      endif

      do j = 1,NGLLZ
        do i = 1,NGLLX

          ! get values for external meshes
          if (assign_external_model) then

            qkappal = QKappa_attenuationext(i,j,ispec)
            qmul = Qmu_attenuationext(i,j,ispec)

            ! if no attenuation in that elastic element
            if (qkappal > 9998.999d0 .and. qmul > 9998.999d0) cycle

            ! determines attenuation factors
            call attenuation_model(qkappal,qmul,ATTENUATION_f0_REFERENCE,N_SLS, &
                                   tau_epsilon_nu1_sent,inv_tau_sigma_nu1_sent,phi_nu1_sent,Mu_nu1_sent, &
                                   tau_epsilon_nu2_sent,inv_tau_sigma_nu2_sent,phi_nu2_sent,Mu_nu2_sent)
          endif

          ! stores attenuation values
          inv_tau_sigma_nu1(i,j,ispec,:) = inv_tau_sigma_nu1_sent(:)
          tau_epsilon_nu1(i,j,ispec,:) = tau_epsilon_nu1_sent(:)
          phi_nu1(i,j,ispec,:) = phi_nu1_sent(:)

          inv_tau_sigma_nu2(i,j,ispec,:) = inv_tau_sigma_nu2_sent(:)
          tau_epsilon_nu2(i,j,ispec,:) = tau_epsilon_nu2_sent(:)
          phi_nu2(i,j,ispec,:) = phi_nu2_sent(:)

          Mu_nu1(i,j,ispec) = Mu_nu1_sent
          Mu_nu2(i,j,ispec) = Mu_nu2_sent

          if (ATTENUATION_VISCOACOUSTIC .and. USE_A_STRONG_FORMULATION_FOR_E1 .and. time_stepping_scheme == 1 ) then
            phinu(:)    = phi_nu1(i,j,ispec,:)
            tauinvnu(:) = inv_tau_sigma_nu1(i,j,ispec,:)
            temp(:)      = exp(- 0.5d0 * tauinvnu(:) * deltat)
            coef(:)     = (1.d0 - temp(:)) / tauinvnu(:)
            A_newmark_e1_sf(:,i,j,ispec) = temp(:)
            B_newmark_e1_sf(:,i,j,ispec) = phinu(:) * coef(:)
          endif

          if (ATTENUATION_VISCOELASTIC .and. time_stepping_scheme == 1 ) then
            phinu(:)    = phi_nu1(i,j,ispec,:)
            tauinvnu(:) = inv_tau_sigma_nu1(i,j,ispec,:)
            temp(:)      = exp(- 0.5d0 * tauinvnu(:) * deltat)
            coef(:)     = (1.d0 - temp(:)) / tauinvnu(:)
            A_newmark_nu1(:,i,j,ispec) = temp(:)
            B_newmark_nu1(:,i,j,ispec) = phinu(:) * coef(:)

            phinu(:)    = phi_nu2(i,j,ispec,:)
            tauinvnu(:) = inv_tau_sigma_nu2(i,j,ispec,:)
            temp(:)      = exp(- 0.5d0 * tauinvnu(:) * deltat)
            coef(:)     = (1.d0 - temp(:)) / tauinvnu(:)
            A_newmark_nu2(:,i,j,ispec) = temp(:)
            B_newmark_nu2(:,i,j,ispec) = phinu(:) * coef(:)
          endif

          ! shifts velocities
          if (READ_VELOCITIES_AT_f0) then

            ! safety check
            if (ispec_is_anisotropic(ispec) .or. ispec_is_poroelastic(ispec)) &
              call stop_the_code('READ_VELOCITIES_AT_f0 only implemented for non anisotropic, non poroelastic materials for now')

            if (ispec_is_acoustic(ispec)) then
              do n = 1,100
                print *,'WARNING: READ_VELOCITIES_AT_f0 in viscoacoustic elements may imply having to rebuild the mass matrix &
                   &with the shifted velocities, since the fluid mass matrix contains Kappa; not implemented yet, BEWARE!!'
              enddo
            endif

            if (assign_external_model) then
              ! external mesh model
              rhol = dble(rhostore(i,j,ispec))
              vp = dble(rho_vpstore(i,j,ispec)/rhol)
              vs = dble(rho_vsstore(i,j,ispec)/rhol)

              ! shifts vp and vs (according to f0 and attenuation band)
              call shift_velocities_from_f0(vp,vs,rhol, &
                                    ATTENUATION_f0_REFERENCE,N_SLS, &
                                    tau_epsilon_nu1_sent,tau_epsilon_nu2_sent,inv_tau_sigma_nu1_sent,inv_tau_sigma_nu2_sent)

              ! stores shifted values
              ! determins mu and kappa
              mul = rhol * vs * vs
              if (AXISYM) then ! CHECK kappa
                kappal = rhol * vp * vp - FOUR_THIRDS * mul
              else
                kappal = rhol * vp * vp - mul
              endif
              ! to compare:
              !lambdal = rhol * vp*vp - TWO * mul
              !if (AXISYM) then ! CHECK kappa
              !  kappal = lambdal + TWO_THIRDS * mul
              !  vp = sqrt((kappal + FOUR_THIRDS * mul)/rhol)
              !else
              !  kappal = lambdal + mul
              !  vp = sqrt((kappal + mul)/rhol)
              !endif

              ! stores unrelaxed moduli
              mustore(i,j,ispec) = mul
              kappastore(i,j,ispec) = kappal

              ! stores density times vp and vs
              rho_vpstore(i,j,ispec) = rhol * vp
              rho_vsstore(i,j,ispec) = rhol * vs

            else
              ! internal mesh
              n = kmato(ispec)

              rhol = density(1,n)
              lambdal = poroelastcoef(1,1,n)
              mul = poroelastcoef(2,1,n)

              if (.not. already_shifted_velocity(n)) then
                vp = sqrt((lambdal + TWO * mul) / rhol)
                vs = sqrt(mul/rhol)

                ! shifts vp and vs
                call shift_velocities_from_f0(vp,vs,rhol, &
                                      ATTENUATION_f0_REFERENCE,N_SLS, &
                                      tau_epsilon_nu1_sent,tau_epsilon_nu2_sent,inv_tau_sigma_nu1_sent,inv_tau_sigma_nu2_sent)

                ! stores shifted mu,lambda
                mul = rhol * vs*vs
                lambdal = rhol * vp*vp - TWO * mul

                poroelastcoef(1,1,n) = lambdal
                poroelastcoef(2,1,n) = mul
                poroelastcoef(3,1,n) = lambdal + TWO * mul

                already_shifted_velocity(n) = .true.
              endif

              ! stores material arrays
              if (AXISYM) then ! CHECK kappa
                kappal = lambdal + TWO_THIRDS * mul
                vp = sqrt((kappal + FOUR_THIRDS * mul)/rhol)
              else
                kappal = lambdal + mul
                vp = sqrt((kappal + mul)/rhol)
              endif
              ! stores unrelaxed moduli
              mustore(i,j,ispec) = mul
              kappastore(i,j,ispec) = kappal
              ! stores density times vp and vs
              vs = sqrt(mul/rhol)
              rho_vpstore(i,j,ispec) = rhol * vp
              rho_vsstore(i,j,ispec) = rhol * vs
            endif

          endif
        enddo
      enddo
    enddo

    if (PML_BOUNDARY_CONDITIONS) call prepare_attenuation_with_PML()

  endif ! of if (ATTENUATION_VISCOELASTIC .or. ATTENUATION_VISCOACOUSTIC)

  ! free memory
  deallocate(already_shifted_velocity)

  ! allocate memory variables for viscous attenuation (poroelastic media)
  if (ATTENUATION_PORO_FLUID_PART) then
    allocate(rx_viscous(NGLLX,NGLLZ,nspec))
    allocate(rz_viscous(NGLLX,NGLLZ,nspec))
    allocate(viscox(NGLLX,NGLLZ,nspec))
    allocate(viscoz(NGLLX,NGLLZ,nspec))
    ! initialize memory variables for attenuation
    rx_viscous(:,:,:) = 0.d0
    rz_viscous(:,:,:) = 0.d0
    viscox(:,:,:) = 0.d0
    viscoz(:,:,:) = 0.d0

    if (time_stepping_scheme == 2) then
      allocate(rx_viscous_LDDRK(NGLLX,NGLLZ,nspec))
      allocate(rz_viscous_LDDRK(NGLLX,NGLLZ,nspec))
      rx_viscous_LDDRK(:,:,:) = 0.d0
      rz_viscous_LDDRK(:,:,:) = 0.d0
    endif

    if (time_stepping_scheme == 3) then
      allocate(rx_viscous_initial_rk(NGLLX,NGLLZ,nspec))
      allocate(rz_viscous_initial_rk(NGLLX,NGLLZ,nspec))
      allocate(rx_viscous_force_RK(NGLLX,NGLLZ,nspec,stage_time_scheme))
      allocate(rz_viscous_force_RK(NGLLX,NGLLZ,nspec,stage_time_scheme))
      rx_viscous_initial_rk(:,:,:) = 0.d0
      rz_viscous_initial_rk(:,:,:) = 0.d0
      rx_viscous_force_RK(:,:,:,:) = 0.d0
      rz_viscous_force_RK(:,:,:,:) = 0.d0
    endif

    ! precompute Runge Kutta coefficients if viscous attenuation
    ! viscous attenuation is implemented following the memory variable formulation of
    ! J. M. Carcione Wave fields in real media: wave propagation in anisotropic,
    ! anelastic and porous media, Elsevier, p. 304-305, 2007
    theta_e = (sqrt(Q0_poroelastic**2+1.d0) +1.d0)/(2.d0*pi*freq0_poroelastic*Q0_poroelastic)
    theta_s = (sqrt(Q0_poroelastic**2+1.d0) -1.d0)/(2.d0*pi*freq0_poroelastic*Q0_poroelastic)

    thetainv = - 1.d0 / theta_s
    alphaval = 1.d0 + deltat*thetainv + deltat**2*thetainv**2 / 2.d0 &
                    + deltat**3*thetainv**3 / 6.d0 + deltat**4*thetainv**4 / 24.d0
    betaval = deltat / 2.d0 + deltat**2*thetainv / 3.d0 + deltat**3*thetainv**2 / 8.d0 + deltat**4*thetainv**3 / 24.d0
    gammaval = deltat / 2.d0 + deltat**2*thetainv / 6.d0 + deltat**3*thetainv**2 / 24.d0
  endif

  ! synchronizes all processes
  call synchronize_all()

  end subroutine prepare_attenuation


!
!-------------------------------------------------------------------------------------
!


  subroutine prepare_attenuation_with_PML()

  use constants
  use specfem_par

  double precision, dimension(2*N_SLS) :: tauinvnu
  double precision, dimension(2*N_SLS + 1) :: tauinvplusone
  double precision :: qkappal,qmul
  double precision :: d_x, d_z, K_x, K_z, alpha_x, alpha_z, beta_x, beta_z
  double precision :: const_for_separation_two

  integer :: i,j,ispec,i_sls,ispec_PML

  ! user output
  if (myrank == 0) then
    write(IMAIN,*) '  preparing attenuation within PML region'
    write(IMAIN,*)
    call flush_IMAIN()
  endif

  const_for_separation_two = min_distance_between_CPML_parameter * 2.d0
  do ispec = 1,nspec
    ispec_PML = spec_to_PML(ispec)
    if (ispec_is_PML(ispec)) then
      do j = 1,NGLLZ
        do i = 1,NGLLX
          if (.not. assign_external_model) then
            qkappal = QKappa_attenuationcoef(kmato(ispec))
            qmul = Qmu_attenuationcoef(kmato(ispec))
          else
            qkappal = QKappa_attenuationext(i,j,ispec)
            qmul = Qmu_attenuationext(i,j,ispec)
          endif
          if (qkappal > 9998.999d0 .and. qmul > 9998.999d0) cycle
          K_x = K_x_store(i,j,ispec_PML)
          d_x = d_x_store(i,j,ispec_PML)
          alpha_x = alpha_x_store(i,j,ispec_PML)

          K_z = K_z_store(i,j,ispec_PML)
          d_z = d_z_store(i,j,ispec_PML)
          alpha_z = alpha_z_store(i,j,ispec_PML)

          if (ATTENUATION_VISCOELASTIC) then
            if (region_CPML(ispec) == CPML_XZ) then
              if (ispec_is_elastic(ispec)) then
                do i_sls = 1,N_SLS
                  tauinvnu(i_sls) = inv_tau_sigma_nu1(i,j,ispec,i_sls)
                  tauinvnu(i_sls+N_SLS) = inv_tau_sigma_nu2(i,j,ispec,i_sls)
                enddo

                call tauinvnu_arange_from_lt_to_gt(2*N_SLS,tauinvnu)

                do i_sls = 1,2*N_SLS
                  if (abs(alpha_x - tauinvnu(i_sls)) < min_distance_between_CPML_parameter) then
                    alpha_x = tauinvnu(i_sls) + const_for_separation_two
                  endif
                  if (abs(alpha_x - tauinvnu(i_sls)) < min_distance_between_CPML_parameter) then
                    call stop_the_code('error in separation of alpha_x, tauinvnu')
                  endif
                enddo
                do i_sls = 1,2*N_SLS
                  tauinvplusone(i_sls) = tauinvnu(i_sls)
                enddo
                tauinvplusone(2*N_SLS + 1) = alpha_x

                call tauinvnu_arange_from_lt_to_gt(2 * N_SLS + 1,tauinvplusone)

                do i_sls = 1,2*N_SLS + 1
                  if (abs(alpha_z - tauinvplusone(i_sls)) < min_distance_between_CPML_parameter) then
                    alpha_z = tauinvplusone(i_sls) + const_for_separation_two
                  endif
                  if (abs(alpha_z - tauinvplusone(i_sls)) < min_distance_between_CPML_parameter) then
                    call stop_the_code('error in separation of alpha_z, alpha_x,tauinvnu')
                  endif
                enddo

                beta_z = alpha_z + d_z / K_z

                do i_sls = 1,2*N_SLS + 1
                  if (abs(beta_z - tauinvplusone(i_sls)) < min_distance_between_CPML_parameter) then
                    beta_z = tauinvplusone(i_sls) + const_for_separation_two
                  endif
                  if (abs(beta_z - tauinvplusone(i_sls)) < min_distance_between_CPML_parameter) then
                    call stop_the_code('error in separation of beta_z, alpha_x,tauinvnu')
                  endif
                enddo

                do i_sls = 1,2*N_SLS
                  tauinvplusone(i_sls) = tauinvnu(i_sls)
                enddo
                tauinvplusone(2*N_SLS + 1) = alpha_z

                call tauinvnu_arange_from_lt_to_gt(2 * N_SLS + 1,tauinvplusone)
                beta_x = alpha_x + d_x / K_x
                do i_sls = 1,2*N_SLS + 1
                  if (abs(beta_x - tauinvplusone(i_sls)) < min_distance_between_CPML_parameter) then
                    beta_x = tauinvplusone(i_sls) + const_for_separation_two
                  endif
                  if (abs(beta_x - tauinvplusone(i_sls)) < min_distance_between_CPML_parameter) then
                    call stop_the_code('error in separation of beta_x, alpha_z,tauinvnu')
                  endif
                enddo

                d_x = (beta_x - alpha_x) * K_x
                d_z = (beta_z - alpha_z) * K_z

                d_x_store(i,j,ispec_PML) = d_x
                alpha_x_store(i,j,ispec_PML) = alpha_x
                d_z_store(i,j,ispec_PML) = d_z
                alpha_z_store(i,j,ispec_PML) = alpha_z

              endif
            endif

            if (region_CPML(ispec) == CPML_X_ONLY) then
              do i_sls = 1,2*N_SLS
                if (abs(alpha_x - tauinvnu(i_sls)) < min_distance_between_CPML_parameter) then
                  alpha_x = tauinvnu(i_sls) + const_for_separation_two
                endif
                if (abs(alpha_x - tauinvnu(i_sls)) < min_distance_between_CPML_parameter) then
                  call stop_the_code('error in separation of alpha_x, tauinvnu')
                endif
              enddo
              beta_x = alpha_x + d_x / K_x
              do i_sls = 1,2*N_SLS
                if (abs(beta_x - tauinvnu(i_sls)) < min_distance_between_CPML_parameter) then
                  beta_x = tauinvnu(i_sls) + const_for_separation_two
                endif
                if (abs(beta_x - tauinvnu(i_sls)) < min_distance_between_CPML_parameter) then
                  call stop_the_code('error in separation of beta_x, tauinvnu')
                endif
              enddo

              d_x = (beta_x - alpha_x) * K_x
              d_x_store(i,j,ispec_PML) = d_x
              alpha_x_store(i,j,ispec_PML) = alpha_x

            endif

            if (region_CPML(ispec) == CPML_Z_ONLY) then
              do i_sls = 1,2*N_SLS
                if (abs(alpha_z - tauinvnu(i_sls)) < min_distance_between_CPML_parameter) then
                  alpha_z = tauinvnu(i_sls) + const_for_separation_two
                endif
                if (abs(alpha_z - tauinvnu(i_sls)) < min_distance_between_CPML_parameter) then
                  call stop_the_code('error in separation of alpha_z, tauinvnu')
                endif
              enddo
              beta_z = alpha_z + d_z / K_z
              do i_sls = 1,2*N_SLS
                if (abs(beta_z - tauinvnu(i_sls)) < min_distance_between_CPML_parameter) then
                  beta_z = tauinvnu(i_sls) + const_for_separation_two
                endif
                if (abs(beta_z - tauinvnu(i_sls)) < min_distance_between_CPML_parameter) then
                  call stop_the_code('error in separation of beta_z, tauinvnu')
                endif
              enddo

              d_z = (beta_z - alpha_z) * K_z
              d_z_store(i,j,ispec_PML) = d_z
              alpha_z_store(i,j,ispec_PML) = alpha_z

            endif
          endif
        enddo
      enddo
    endif
  enddo

  contains

    subroutine tauinvnu_arange_from_lt_to_gt(siz,tauinvnu)

    implicit none
    integer, intent(in) :: siz
    double precision, dimension(siz), intent(inout) :: tauinvnu

    !local parameters
    integer :: i,j
    double precision :: temp

    do i= 1,siz
      do j= i+1,siz
        if (tauinvnu(i) > tauinvnu(j)) then
          temp = tauinvnu(i)
          tauinvnu(i) = tauinvnu(j)
          tauinvnu(j) =  temp
        endif
      enddo
    enddo
    end subroutine tauinvnu_arange_from_lt_to_gt

  end subroutine prepare_attenuation_with_PML



