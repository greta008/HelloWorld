! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.io/license.html
!
module sw_advection

   use mpas_kind_types
   use mpas_derived_types
   use mpas_pool_routines
   use mpas_constants
   use mpas_log


   contains


   subroutine sw_initialize_advection_rk( meshPool )
                                      
!
! compute the cell coefficients for the polynomial fit.
! this is performed during setup for model integration.
! WCS, 31 August 2009
!
      implicit none

      type (mpas_pool_type), intent(in) :: meshPool

      real (kind=RKIND), dimension(:,:,:), pointer :: deriv_two
      integer, dimension(:,:), pointer :: advCells

!  local variables

      real (kind=RKIND), dimension(:,:), allocatable :: thetae
      real (kind=RKIND), dimension(:), allocatable :: xe, ye
      real (kind=RKIND), dimension(:), allocatable :: theta_abs

      real (kind=RKIND), dimension(25) :: xc, yc, zc ! cell center coordinates
      real (kind=RKIND), dimension(25) :: thetav, thetat, dl_sphere
      real (kind=RKIND) :: xm, ym, zm, dl, xec, yec, zec
      real (kind=RKIND) :: thetae_tmp, xe_tmp, ye_tmp
      real (kind=RKIND) :: xv1, xv2, yv1, yv2, zv1, zv2
      integer :: i, j, k, ip1, ip2, m, n, ip1a, ii
      integer :: iCell, iEdge
      real (kind=RKIND) :: pii
      real (kind=RKIND) :: x0, y0, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5
      real (kind=RKIND) :: pdx1, pdx2, pdx3, pdy1, pdy2, pdy3, dx1, dx2, dy1, dy2
      real (kind=RKIND) :: angv1, angv2, dl1, dl2
      real (kind=RKIND), dimension(25) :: dxe, dye, x2v, y2v, xp, yp
      
      real (kind=RKIND) :: amatrix(25,25), bmatrix(25,25), wmatrix(25,25)
      real (kind=RKIND) :: length_scale
      integer :: ma,na, cell_add, mw, nn
      integer, dimension(25) :: cell_list

      integer :: cell1, cell2
      integer, pointer :: maxEdges, nEdges, nCells
      integer, parameter :: polynomial_order = 2
!      logical, parameter :: debug = .true.
      logical, parameter :: debug = .false.
!      logical, parameter :: least_squares = .false.
      logical, parameter :: least_squares = .true.
      logical :: add_the_cell, do_the_cell

      logical, parameter :: reset_poly = .true.

      real (kind=RKIND) :: rcell, cos2t, costsint, sin2t
      real (kind=RKIND), dimension(:), allocatable :: angle_2d

      logical, pointer :: on_a_sphere
      real (kind=RKIND), pointer :: sphere_radius

      integer, dimension(:), pointer :: nEdgesOnCell
      integer, dimension(:,:), pointer :: cellsOnCell, edgesOnCell, cellsOnEdge, verticesOnEdge

      real (kind=RKIND), dimension(:), pointer :: xCell, yCell, zCell, angleEdge
      real (kind=RKIND), dimension(:), pointer :: dcEdge, xVertex, yVertex, zVertex

!---

      call mpas_pool_get_config(meshPool, 'on_a_sphere', on_a_sphere)
      call mpas_pool_get_config(meshPool, 'sphere_radius', sphere_radius)

      call mpas_pool_get_dimension(meshPool, 'maxEdges', maxEdges)
      call mpas_pool_get_dimension(meshPool, 'nEdges', nEdges)
      call mpas_pool_get_dimension(meshPool, 'nCells', nCells)

      allocate(angle_2d(maxEdges))
      allocate(thetae(2, nEdges))
      allocate(xe(nEdges))
      allocate(ye(nEdges))
      allocate(theta_abs(nCells))

      pii = 2.*asin(1.0)

      call mpas_pool_get_array(meshPool, 'advCells', advCells)
      call mpas_pool_get_array(meshPool, 'deriv_two', deriv_two)
      call mpas_pool_get_array(meshPool, 'nEdgesOnCell', nEdgesOnCell)
      call mpas_pool_get_array(meshPool, 'cellsOnCell', cellsOnCell)
      call mpas_pool_get_array(meshPool, 'edgesOnCell', edgesOnCell)
      call mpas_pool_get_array(meshPool, 'cellsOnEdge', cellsOnEdge)
      call mpas_pool_get_array(meshPool, 'xCell', xCell)
      call mpas_pool_get_array(meshPool, 'yCell', yCell)
      call mpas_pool_get_array(meshPool, 'zCell', zCell)
      call mpas_pool_get_array(meshPool, 'angleEdge', angleEdge)
      call mpas_pool_get_array(meshPool, 'dcEdge', dcEdge)

      call mpas_pool_get_dimension(meshPool, 'nCells', nCells)
      deriv_two(:,:,:) = 0.

      do iCell = 1, nCells !  is this correct? - we need first halo cell also...

         cell_list(1) = iCell
         do i = 2, nEdgesOnCell(iCell)+1
            cell_list(i) = cellsOnCell(i-1,iCell)
         end do
         n = nEdgesOnCell(iCell) + 1

         if ( polynomial_order > 2 ) then
            do i = 2, nEdgesOnCell(iCell) + 1
               do j = 1, nEdgesOnCell( cell_list(i) )
                  cell_add = CellsOnCell(j,cell_list(i))
                  add_the_cell = .true.
                  do k=1,n
                     if ( cell_add == cell_list(k) ) add_the_cell = .false.
                  end do
                  if (add_the_cell) then
                     n = n+1
                     cell_list(n) = cell_add
                  end if
               end do
            end do
         end if
 
         advCells(1,iCell) = n

!  check to see if we are reaching outside the halo

         do_the_cell = .true.
         do i = 1, n
            if (cell_list(i) > nCells) do_the_cell = .false.
         end do


         if ( .not. do_the_cell ) cycle


!  compute poynomial fit for this cell if all needed neighbors exist
         if ( on_a_sphere ) then

            do i = 1, n
               advCells(i+1,iCell) = cell_list(i)
               xc(i) = xCell(advCells(i+1,iCell)) / sphere_radius
               yc(i) = yCell(advCells(i+1,iCell)) / sphere_radius
               zc(i) = zCell(advCells(i+1,iCell)) / sphere_radius
            end do

            theta_abs(iCell) =  pii/2. - sphere_angle( xc(1), yc(1), zc(1),  &
                                                       xc(2), yc(2), zc(2),  &
                                                       0.0_RKIND, 0.0_RKIND, 1.0_RKIND ) 

! angles from cell center to neighbor centers (thetav)

            do i = 1, n-1
   
               ip2 = i+2
               if (ip2 > n) ip2 = 2
    
               thetav(i) = sphere_angle( xc(1),   yc(1),   zc(1),    &
                                         xc(i+1), yc(i+1), zc(i+1),  &
                                         xc(ip2), yc(ip2), zc(ip2)   )

               dl_sphere(i) = a*arc_length( xc(1),   yc(1),   zc(1),  &
                                            xc(i+1), yc(i+1), zc(i+1) )
            end do

            length_scale = 1.
            do i = 1, n-1
               dl_sphere(i) = dl_sphere(i) / length_scale
            end do

!            thetat(1) = 0.  !  this defines the x direction, cell center 1 -> 
            thetat(1) = theta_abs(iCell)  !  this defines the x direction, longitude line
            do i=2,n-1
               thetat(i) = thetat(i-1) + thetav(i-1)
            end do
   
            do i=1,n-1
               xp(i) = cos(thetat(i)) * dl_sphere(i)
               yp(i) = sin(thetat(i)) * dl_sphere(i)
            end do

         else     ! On an x-y plane

            do i = 1, n-1

               iEdge = edgesOnCell(i,iCell)
               angle_2d(i) = angleEdge(iEdge)
               if ( iCell .ne. cellsOnEdge(1,iEdge)) &
                  angle_2d(i) = angle_2d(i) - pii

!               xp(i) = grid % xCell % array(cell_list(i)) - grid % xCell % array(iCell)
!               yp(i) = grid % yCell % array(cell_list(i)) - grid % yCell % array(iCell)

               xp(i) = dcEdge(iEdge) * cos(angle_2d(i))
               yp(i) = dcEdge(iEdge) * sin(angle_2d(i))

            end do

         end if


         ma = n-1
         mw = nEdgesOnCell(iCell)

         bmatrix = 0.
         amatrix = 0.
         wmatrix = 0.

         if (polynomial_order == 2) then
            na = 6
            ma = ma+1
  
            amatrix(1,1) = 1.
            wmatrix(1,1) = 1.
            do i=2,ma
               amatrix(i,1) = 1.
               amatrix(i,2) = xp(i-1)
               amatrix(i,3) = yp(i-1)
               amatrix(i,4) = xp(i-1)**2
               amatrix(i,5) = xp(i-1) * yp(i-1)
               amatrix(i,6) = yp(i-1)**2
   
               wmatrix(i,i) = 1.
            end do
 
         else if (polynomial_order == 3) then
            na = 10
            ma = ma+1
  
            amatrix(1,1) = 1.
            wmatrix(1,1) = 1.
            do i=2,ma
               amatrix(i,1) = 1.
               amatrix(i,2) = xp(i-1)
               amatrix(i,3) = yp(i-1)
   
               amatrix(i,4) = xp(i-1)**2
               amatrix(i,5) = xp(i-1) * yp(i-1)
               amatrix(i,6) = yp(i-1)**2
   
               amatrix(i,7) = xp(i-1)**3
               amatrix(i,8) = yp(i-1) * (xp(i-1)**2)
               amatrix(i,9) = xp(i-1) * (yp(i-1)**2)
               amatrix(i,10) = yp(i-1)**3
   
               wmatrix(i,i) = 1.
 
            end do

         else
            na = 15
            ma = ma+1
  
            amatrix(1,1) = 1.
            wmatrix(1,1) = 1.
            do i=2,ma
               amatrix(i,1) = 1.
               amatrix(i,2) = xp(i-1)
               amatrix(i,3) = yp(i-1)
   
               amatrix(i,4) = xp(i-1)**2
               amatrix(i,5) = xp(i-1) * yp(i-1)
               amatrix(i,6) = yp(i-1)**2
   
               amatrix(i,7) = xp(i-1)**3
               amatrix(i,8) = yp(i-1) * (xp(i-1)**2)
               amatrix(i,9) = xp(i-1) * (yp(i-1)**2)
               amatrix(i,10) = yp(i-1)**3
   
               amatrix(i,11) = xp(i-1)**4
               amatrix(i,12) = yp(i-1) * (xp(i-1)**3)
               amatrix(i,13) = (xp(i-1)**2)*(yp(i-1)**2)
               amatrix(i,14) = xp(i-1) * (yp(i-1)**3)
               amatrix(i,15) = yp(i-1)**4
   
               wmatrix(i,i) = 1.
  
            end do
 
            do i=1,mw
               wmatrix(i,i) = 1.
            end do
 
         end if
 
         call sw_poly_fit_2( amatrix, bmatrix, wmatrix, ma, na, 25 )

         do i = 1, nEdgesOnCell(iCell)
            ip1 = i+1
            if (ip1 > n-1) ip1 = 1
  
            iEdge = edgesOnCell(i,iCell)
            xv1 = xVertex(verticesOnEdge(1, iEdge)) / sphere_radius
            yv1 = yVertex(verticesOnEdge(1, iEdge)) / sphere_radius
            zv1 = zVertex(verticesOnEdge(1, iEdge)) / sphere_radius
            xv2 = xVertex(verticesOnEdge(2, iEdge)) / sphere_radius
            yv2 = yVertex(verticesOnEdge(2, iEdge)) / sphere_radius
            zv2 = zVertex(verticesOnEdge(2, iEdge)) / sphere_radius
  
            if ( on_a_sphere ) then
               call sw_arc_bisect( xv1, yv1, zv1,  &
                                xv2, yv2, zv2,  &
                                xec, yec, zec   )
  
               thetae_tmp = sphere_angle( xc(1),   yc(1),   zc(1),    &
                                          xc(i+1), yc(i+1), zc(i+1),  &
                                          xec,     yec,     zec       )
               thetae_tmp = thetae_tmp + thetat(i)
               if (iCell == cellsOnEdge(1,iEdge)) then
                  thetae(1, iEdge) = thetae_tmp
               else
                  thetae(2, iEdge) = thetae_tmp
               end if
!            else
!
!               xe(iEdge) = 0.5 * (xv1 + xv2)
!               ye(iEdge) = 0.5 * (yv1 + yv2)

            end if
  
         end do

!  fill second derivative stencil for rk advection 

         do i = 1, nEdgesOnCell(iCell)
            iEdge = edgesOnCell(i,iCell)
  
  
            if ( on_a_sphere ) then
               if (iCell == cellsOnEdge(1,iEdge)) then
  
                  cos2t = cos(thetae(1, iEdge))
                  sin2t = sin(thetae(1, iEdge))
                  costsint = cos2t*sin2t
                  cos2t = cos2t**2
                  sin2t = sin2t**2
   
                  do j = 1, n
                     deriv_two(j,1,iEdge) =   2.*cos2t*bmatrix(4,j)  &
                                            + 2.*costsint*bmatrix(5,j)  &
                                            + 2.*sin2t*bmatrix(6,j)
                  end do
               else
     
                  cos2t = cos(thetae(2, iEdge))
                  sin2t = sin(thetae(2, iEdge))
                  costsint = cos2t*sin2t
                  cos2t = cos2t**2
                  sin2t = sin2t**2
      
                  do j=1,n
                     deriv_two(j,2,iEdge) =   2.*cos2t*bmatrix(4,j)  &
                                            + 2.*costsint*bmatrix(5,j)  &
                                            + 2.*sin2t*bmatrix(6,j)
                  end do
               end if

            else

               cos2t = cos(angle_2d(i))
               sin2t = sin(angle_2d(i))
               costsint = cos2t*sin2t
               cos2t = cos2t**2
               sin2t = sin2t**2

!               do j=1,n
!
!                  deriv_two(j,1,iEdge) =   2.*xe(iEdge)*xe(iEdge)*bmatrix(4,j)  &
!                                         + 2.*xe(iEdge)*ye(iEdge)*bmatrix(5,j)  &
!                                         + 2.*ye(iEdge)*ye(iEdge)*bmatrix(6,j)
!               end do

               if (iCell == cellsOnEdge(1,iEdge)) then
                  do j = 1, n
                     deriv_two(j,1,iEdge) =   2.*cos2t*bmatrix(4,j)  &
                                            + 2.*costsint*bmatrix(5,j)  &
                                            + 2.*sin2t*bmatrix(6,j)
                  end do
               else
                  do j = 1, n
                     deriv_two(j,2,iEdge) =   2.*cos2t*bmatrix(4,j)  &
                                            + 2.*costsint*bmatrix(5,j)  &
                                            + 2.*sin2t*bmatrix(6,j)
                  end do
               end if

            end if
         end do
 
      end do ! end of loop over cells

      if (debug) stop


!      write(0,*) ' check for deriv2 coefficients, iEdge 4 '
!
!      iEdge = 4
!      j = 1
!      iCell = grid % cellsOnEdge % array(1,iEdge)
!      write(0,*) ' j, icell, coef ',j,iCell,deriv_two(j,1,iEdge)
!      do j=2,7
!         write(0,*) ' j, icell, coef ',j,grid % CellsOnCell % array(j-1,iCell),deriv_two(j,1,iEdge)
!      end do
!
!      j = 1
!      iCell = grid % cellsOnEdge % array(2,iEdge)
!      write(0,*) ' j, icell, coef ',j,iCell,deriv_two(j,2,iEdge)
!      do j=2,7
!         write(0,*) ' j, icell, coef ',j,grid % CellsOnCell % array(j-1,iCell),deriv_two(j,2,iEdge)
!      end do
!      stop

   end subroutine sw_initialize_advection_rk


   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   ! FUNCTION SPHERE_ANGLE
   !
   ! Computes the angle between arcs AB and AC, given points A, B, and C
   ! Equation numbers w.r.t. http://mathworld.wolfram.com/SphericalTrigonometry.html
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   real (kind=RKIND) function sphere_angle(ax, ay, az, bx, by, bz, cx, cy, cz)
   
      implicit none
   
      real (kind=RKIND), intent(in) :: ax, ay, az, bx, by, bz, cx, cy, cz
   
      real (kind=RKIND) :: a, b, c          ! Side lengths of spherical triangle ABC
   
      real (kind=RKIND) :: ABx, ABy, ABz    ! The components of the vector AB
      real (kind=RKIND) :: mAB              ! The magnitude of AB
      real (kind=RKIND) :: ACx, ACy, ACz    ! The components of the vector AC
      real (kind=RKIND) :: mAC              ! The magnitude of AC
   
      real (kind=RKIND) :: Dx               ! The i-components of the cross product AB x AC
      real (kind=RKIND) :: Dy               ! The j-components of the cross product AB x AC
      real (kind=RKIND) :: Dz               ! The k-components of the cross product AB x AC
   
      real (kind=RKIND) :: s                ! Semiperimeter of the triangle
      real (kind=RKIND) :: sin_angle
   
      a = acos(max(min(bx*cx + by*cy + bz*cz,1.0_RKIND),-1.0_RKIND))      ! Eqn. (3)
      b = acos(max(min(ax*cx + ay*cy + az*cz,1.0_RKIND),-1.0_RKIND))      ! Eqn. (2)
      c = acos(max(min(ax*bx + ay*by + az*bz,1.0_RKIND),-1.0_RKIND))      ! Eqn. (1)
   
      ABx = bx - ax
      ABy = by - ay
      ABz = bz - az
   
      ACx = cx - ax
      ACy = cy - ay
      ACz = cz - az
   
      Dx =   (ABy * ACz) - (ABz * ACy)
      Dy = -((ABx * ACz) - (ABz * ACx))
      Dz =   (ABx * ACy) - (ABy * ACx)
   
      s = 0.5*(a + b + c)
!      sin_angle = sqrt((sin(s-b)*sin(s-c))/(sin(b)*sin(c)))   ! Eqn. (28)
      sin_angle = sqrt(min(1.0_RKIND,max(0.0_RKIND,(sin(s-b)*sin(s-c))/(sin(b)*sin(c)))))   ! Eqn. (28)
   
      if ((Dx*ax + Dy*ay + Dz*az) >= 0.0) then
         sphere_angle =  2.0 * asin(max(min(sin_angle,1.0_RKIND),-1.0_RKIND))
      else
         sphere_angle = -2.0 * asin(max(min(sin_angle,1.0_RKIND),-1.0_RKIND))
      end if
   
   end function sphere_angle
   

   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   ! FUNCTION PLANE_ANGLE
   !
   ! Computes the angle between vectors AB and AC, given points A, B, and C, and
   !   a vector (u,v,w) normal to the plane.
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   real (kind=RKIND) function plane_angle(ax, ay, az, bx, by, bz, cx, cy, cz, u, v, w)
   
      implicit none
   
      real (kind=RKIND), intent(in) :: ax, ay, az, bx, by, bz, cx, cy, cz, u, v, w
   
      real (kind=RKIND) :: ABx, ABy, ABz    ! The components of the vector AB
      real (kind=RKIND) :: mAB              ! The magnitude of AB
      real (kind=RKIND) :: ACx, ACy, ACz    ! The components of the vector AC
      real (kind=RKIND) :: mAC              ! The magnitude of AC
   
      real (kind=RKIND) :: Dx               ! The i-components of the cross product AB x AC
      real (kind=RKIND) :: Dy               ! The j-components of the cross product AB x AC
      real (kind=RKIND) :: Dz               ! The k-components of the cross product AB x AC
   
      real (kind=RKIND) :: cos_angle
   
      ABx = bx - ax
      ABy = by - ay
      ABz = bz - az
      mAB = sqrt(ABx**2.0 + ABy**2.0 + ABz**2.0)
   
      ACx = cx - ax
      ACy = cy - ay
      ACz = cz - az
      mAC = sqrt(ACx**2.0 + ACy**2.0 + ACz**2.0)
   
   
      Dx =   (ABy * ACz) - (ABz * ACy)
      Dy = -((ABx * ACz) - (ABz * ACx))
      Dz =   (ABx * ACy) - (ABy * ACx)
   
      cos_angle = (ABx*ACx + ABy*ACy + ABz*ACz) / (mAB * mAC)
   
      if ((Dx*u + Dy*v + Dz*w) >= 0.0) then
         plane_angle =  acos(max(min(cos_angle,1.0_RKIND),-1.0_RKIND))
      else
         plane_angle = -acos(max(min(cos_angle,1.0_RKIND),-1.0_RKIND))
      end if
   
   end function plane_angle


   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   ! FUNCTION ARC_LENGTH
   !
   ! Returns the length of the great circle arc from A=(ax, ay, az) to 
   !    B=(bx, by, bz). It is assumed that both A and B lie on the surface of the
   !    same sphere centered at the origin.
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   real (kind=RKIND) function arc_length(ax, ay, az, bx, by, bz)
   
      implicit none
   
      real (kind=RKIND), intent(in) :: ax, ay, az, bx, by, bz
   
      real (kind=RKIND) :: r, c
      real (kind=RKIND) :: cx, cy, cz
   
      cx = bx - ax
      cy = by - ay
      cz = bz - az

!      r = ax*ax + ay*ay + az*az
!      c = cx*cx + cy*cy + cz*cz
!
!      arc_length = sqrt(r) * acos(1.0 - c/(2.0*r))

      r = sqrt(ax*ax + ay*ay + az*az)
      c = sqrt(cx*cx + cy*cy + cz*cz)
!      arc_length = sqrt(r) * 2.0 * asin(c/(2.0*r))
      arc_length = r * 2.0 * asin(c/(2.0*r))

   end function arc_length
   
   
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   ! subroutine sw_arc_bisect
   !
   ! Returns the point C=(cx, cy, cz) that bisects the great circle arc from
   !   A=(ax, ay, az) to B=(bx, by, bz). It is assumed that A and B lie on the
   !   surface of a sphere centered at the origin.
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   subroutine sw_arc_bisect(ax, ay, az, bx, by, bz, cx, cy, cz)
   
      implicit none
   
      real (kind=RKIND), intent(in) :: ax, ay, az, bx, by, bz
      real (kind=RKIND), intent(out) :: cx, cy, cz
   
      real (kind=RKIND) :: r           ! Radius of the sphere
      real (kind=RKIND) :: d           
   
      r = sqrt(ax*ax + ay*ay + az*az)
   
      cx = 0.5*(ax + bx)
      cy = 0.5*(ay + by)
      cz = 0.5*(az + bz)
   
      if (cx == 0. .and. cy == 0. .and. cz == 0.) then
         call mpas_log_write('arc_bisect: A and B are diametrically opposite', MPAS_LOG_ERR)
      else
         d = sqrt(cx*cx + cy*cy + cz*cz)
         cx = r * cx / d
         cy = r * cy / d
         cz = r * cz / d
      end if
   
   end subroutine sw_arc_bisect


   subroutine sw_poly_fit_2(a_in,b_out,weights_in,m,n,ne)

      implicit none

      integer, intent(in) :: m,n,ne
      real (kind=RKIND), dimension(ne,ne), intent(in) :: a_in, weights_in
      real (kind=RKIND), dimension(ne,ne), intent(out) :: b_out
   
      ! local storage
   
      real (kind=RKIND), dimension(m,n)  :: a
      real (kind=RKIND), dimension(n,m)  :: b
      real (kind=RKIND), dimension(m,m)  :: w,wt,h
      real (kind=RKIND), dimension(n,m)  :: at, ath
      real (kind=RKIND), dimension(n,n)  :: ata, ata_inv, atha, atha_inv
      integer, dimension(n) :: indx
      integer :: i,j
   
      if ( (ne<n) .or. (ne<m) ) then
         call mpas_log_write(' error in poly_fit_2 inversion $i $i $i', MPAS_LOG_ERR, intArgs=(/m,n,ne/))
         stop
      end if
   
!      a(1:m,1:n) = a_in(1:n,1:m) 
      a(1:m,1:n) = a_in(1:m,1:n)
      w(1:m,1:m) = weights_in(1:m,1:m) 
      b_out(:,:) = 0.   

      wt = transpose(w)
      h = matmul(wt,w)
      at = transpose(a)
      ath = matmul(at,h)
      atha = matmul(ath,a)
      
      ata = matmul(at,a)

!      if (m == n) then
!         call sw_migs(a,n,b,indx)
!      else

         call sw_migs(atha,n,atha_inv,indx)

         b = matmul(atha_inv,ath)

!         call sw_migs(ata,n,ata_inv,indx)
!         b = matmul(ata_inv,at)
!      end if
      b_out(1:n,1:m) = b(1:n,1:m)

!     do i=1,n
!        write(6,*) ' i, indx ',i,indx(i)
!     end do
!
!     write(6,*) ' '

   end subroutine sw_poly_fit_2


! Updated 10/24/2001.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!   Program 4.4   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!                                                                       !
! Please Note:                                                          !
!                                                                       !
! (1) This computer program is written by Tao Pang in conjunction with  !
!     his book, "An Introduction to Computational Physics," published   !
!     by Cambridge University Press in 1997.                            !
!                                                                       !
! (2) No warranties, express or implied, are made for this program.     !
!                                                                       !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
subroutine sw_migs (A,N,X,INDX)
!
! subroutine to invert matrix A(N,N) with the inverse stored
! in X(N,N) in the output.  Copyright (c) Tao Pang 2001.
!
  IMPLICIT NONE
  INTEGER, INTENT (IN) :: N
  INTEGER :: I,J,K
  INTEGER, INTENT (OUT), DIMENSION (N) :: INDX
  REAL (kind=RKIND), INTENT (INOUT), DIMENSION (N,N):: A
  REAL (kind=RKIND), INTENT (OUT), DIMENSION (N,N):: X
  REAL (kind=RKIND), DIMENSION (N,N) :: B
!
  DO I = 1, N
    DO J = 1, N
      B(I,J) = 0.0
    END DO
  END DO
  DO I = 1, N
    B(I,I) = 1.0
  END DO
!
  call sw_elgs (A,N,INDX)
!
  DO I = 1, N-1
    DO J = I+1, N
      DO K = 1, N
        B(INDX(J),K) = B(INDX(J),K)-A(INDX(J),I)*B(INDX(I),K)
      END DO
    END DO
  END DO
!
  DO I = 1, N
    X(N,I) = B(INDX(N),I)/A(INDX(N),N)
    DO J = N-1, 1, -1
      X(J,I) = B(INDX(J),I)
      DO K = J+1, N
        X(J,I) = X(J,I)-A(INDX(J),K)*X(K,I)
      END DO
      X(J,I) =  X(J,I)/A(INDX(J),J)
    END DO
  END DO
end subroutine sw_migs


subroutine sw_elgs (A,N,INDX)
!
! subroutine to perform the partial-pivoting Gaussian elimination.
! A(N,N) is the original matrix in the input and transformed matrix
! plus the pivoting element ratios below the diagonal in the output.
! INDX(N) records the pivoting order.  Copyright (c) Tao Pang 2001.
!
  IMPLICIT NONE
  INTEGER, INTENT (IN) :: N
  INTEGER :: I,J,K,ITMP
  INTEGER, INTENT (OUT), DIMENSION (N) :: INDX
  REAL (kind=RKIND) :: C1,PI,PI1,PJ
  REAL (kind=RKIND), INTENT (INOUT), DIMENSION (N,N) :: A
  REAL (kind=RKIND), DIMENSION (N) :: C
!
! Initialize the index
!
  DO I = 1, N
    INDX(I) = I
  END DO
!
! Find the rescaling factors, one from each row
!
  DO I = 1, N
    C1= 0.0
    DO J = 1, N
      C1 = MAX(C1,ABS(A(I,J)))
    END DO
    C(I) = C1
  END DO
!
! Search the pivoting (largest) element from each column
!
  DO J = 1, N-1
    PI1 = 0.0
    DO I = J, N
      PI = ABS(A(INDX(I),J))/C(INDX(I))
      IF (PI.GT.PI1) THEN
        PI1 = PI
        K   = I
      ENDIF
    END DO
!
! Interchange the rows via INDX(N) to record pivoting order
!
    ITMP    = INDX(J)
    INDX(J) = INDX(K)
    INDX(K) = ITMP
    DO I = J+1, N
      PJ  = A(INDX(I),J)/A(INDX(J),J)
!
! Record pivoting ratios below the diagonal
!
      A(INDX(I),J) = PJ
!
! Modify other elements accordingly
!
      DO K = J+1, N
        A(INDX(I),K) = A(INDX(I),K)-PJ*A(INDX(J),K)
      END DO
    END DO
  END DO
!
end subroutine sw_elgs

!-------------------------------------------------------------

   subroutine sw_initialize_deformation_weights( meshPool )
                                      
!
! compute the cell coefficients for the deformation calculations
! WCS, 13 July 2010
!
      implicit none

      type (mpas_pool_type), intent(in) :: meshPool

!  local variables

      real (kind=RKIND), dimension(:,:), allocatable :: thetae
      real (kind=RKIND), dimension(:), allocatable :: xe, ye
      real (kind=RKIND), dimension(:), allocatable :: theta_abs

      real (kind=RKIND), dimension(25) :: xc, yc, zc ! cell center coordinates
      real (kind=RKIND), dimension(25) :: thetav, thetat, dl_sphere
      real (kind=RKIND) :: xm, ym, zm, dl, xec, yec, zec
      real (kind=RKIND) :: thetae_tmp, xe_tmp, ye_tmp
      real (kind=RKIND) :: xv1, xv2, yv1, yv2, zv1, zv2
      integer :: i, j, k, ip1, ip2, m, n, ip1a, ii
      integer :: iCell, iEdge
      real (kind=RKIND) :: pii
      real (kind=RKIND) :: x0, y0, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5
      real (kind=RKIND) :: pdx1, pdx2, pdx3, pdy1, pdy2, pdy3, dx1, dx2, dy1, dy2
      real (kind=RKIND) :: angv1, angv2, dl1, dl2
      real (kind=RKIND), dimension(25) :: dxe, dye, x2v, y2v, xp, yp, xpt, ypt
      
      real (kind=RKIND) :: length_scale
      integer :: ma,na, cell_add, mw, nn
      integer, dimension(25) :: cell_list

      integer :: cell1, cell2, iv
      logical :: do_the_cell
      real (kind=RKIND) :: area_cell, sint2, cost2, sint_cost, sumw1, sumw2, xptt, area_cellt

      logical, parameter :: debug = .false.

      logical, pointer :: on_a_sphere
      real (kind=RKIND), pointer :: sphere_radius

      integer, pointer :: nCells, nEdges
      real (kind=RKIND), dimension(:), pointer :: xCell, yCell, zCell
      real (kind=RKIND), dimension(:), pointer :: xVertex, yVertex, zVertex
      real (kind=RKIND), dimension(:,:), pointer :: defc_a, defc_b
      integer, dimension(:), pointer :: nEdgesOnCell
      integer, dimension(:,:), pointer :: cellsOnEdge, edgesOnCell, cellsOnCell, verticesOnCell

      if (debug) call mpas_log_write(' in def weight calc ')

      call mpas_pool_get_dimension(meshPool, 'nCells', nCells)
      call mpas_pool_get_dimension(meshPool, 'nEdges', nEdges)

      call mpas_pool_get_config(meshPool, 'on_a_sphere', on_a_sphere)
      call mpas_pool_get_config(meshPool, 'sphere_radius', sphere_radius)

      call mpas_pool_get_array(meshPool, 'xCell', xCell)
      call mpas_pool_get_array(meshPool, 'yCell', yCell)
      call mpas_pool_get_array(meshPool, 'zCell', zCell)
      call mpas_pool_get_array(meshPool, 'xVertex', xVertex)
      call mpas_pool_get_array(meshPool, 'yVertex', yVertex)
      call mpas_pool_get_array(meshPool, 'zVertex', zVertex)
      call mpas_pool_get_array(meshPool, 'defc_a', defc_a)
      call mpas_pool_get_array(meshPool, 'defc_b', defc_b)
      call mpas_pool_get_array(meshPool, 'cellsOnEdge', cellsOnEdge)
      call mpas_pool_get_array(meshPool, 'edgesOnCell', edgesOnCell)
      call mpas_pool_get_array(meshPool, 'nEdgesOnCell', nEdgesOnCell)
      call mpas_pool_get_array(meshPool, 'cellsOnCell', cellsOnCell)

      allocate(thetae(2, nEdges))
      allocate(xe(nEdges))
      allocate(ye(nEdges))
      allocate(theta_abs(nCells))

      defc_a(:,:) = 0.
      defc_b(:,:) = 0.

      pii = 2.*asin(1.0)

      if (debug) call mpas_log_write(' beginning cell loop ')

      do iCell = 1, nCells

         if (debug) call mpas_log_write(' cell loop $i', intArgs=(/iCell/))

         cell_list(1) = iCell
         do i = 2, nEdgesOnCell(iCell)+1
            cell_list(i) = CellsOnCell(i-1,iCell)
         end do
         n = nEdgesOnCell(iCell) + 1

!  check to see if we are reaching outside the halo

         if (debug) call mpas_log_write(' points $i', intArgs=(/n/))

         do_the_cell = .true.
         do i = 1, n
            if (cell_list(i) > nCells) do_the_cell = .false.
         end do


         if (.not. do_the_cell) cycle


!  compute poynomial fit for this cell if all needed neighbors exist
         if (on_a_sphere) then

            xc(1) = xCell(iCell) / sphere_radius
            yc(1) = yCell(iCell) / sphere_radius
            zc(1) = zCell(iCell) / sphere_radius


            do i = 2, n
               iv = verticesOnCell(i-1,iCell)
               xc(i) = xVertex(iv) / sphere_radius
               yc(i) = yVertex(iv) / sphere_radius
               zc(i) = zVertex(iv) / sphere_radius
            end do

            theta_abs(iCell) =  pii / 2. - sphere_angle( xc(1), yc(1), zc(1),  &
                                                       xc(2), yc(2), zc(2),  &
                                                       0.0_RKIND, 0.0_RKIND, 1.0_RKIND ) 

! angles from cell center to neighbor centers (thetav)

            do i = 1, n-1
   
               ip2 = i+2
               if (ip2 > n) ip2 = 2
    
               thetav(i) = sphere_angle( xc(1),   yc(1),   zc(1),    &
                                         xc(i+1), yc(i+1), zc(i+1),  &
                                         xc(ip2), yc(ip2), zc(ip2)   )

               dl_sphere(i) = a*arc_length( xc(1),   yc(1),   zc(1),  &
                                            xc(i+1), yc(i+1), zc(i+1) )
            end do

            length_scale = 1.
            do i = 1, n-1
               dl_sphere(i) = dl_sphere(i) / length_scale
            end do

            thetat(1) = 0.  !  this defines the x direction, cell center 1 -> 
!            thetat(1) = theta_abs(iCell)  !  this defines the x direction, longitude line
            do i = 2, n-1
               thetat(i) = thetat(i-1) + thetav(i-1)
            end do
   
            do i = 1, n-1
               xp(i) = cos(thetat(i)) * dl_sphere(i)
               yp(i) = sin(thetat(i)) * dl_sphere(i)
            end do

         else     ! On an x-y plane

            xp(1) = xCell(iCell)
            yp(1) = yCell(iCell)


            do i = 2, n
               iv = verticesOnCell(i-1,iCell)
               xp(i) = xVertex(iv)
               yp(i) = yVertex(iv)
            end do

         end if

!         thetat(1) = 0.
         thetat(1) = theta_abs(iCell)
         do i = 2, n-1
            ip1 = i+1
            if (ip1 == n) ip1 = 1
            thetat(i) = plane_angle( 0.0_RKIND, 0.0_RKIND, 0.0_RKIND,  &
                                     xp(i)-xp(i-1), yp(i)-yp(i-1), 0.0_RKIND,  &
                                     xp(ip1)-xp(i), yp(ip1)-yp(i), 0.0_RKIND,  &
                                     0.0_RKIND, 0.0_RKIND, 1.0_RKIND)
            thetat(i) = thetat(i) + thetat(i-1)
         end do

         area_cell = 0.
         area_cellt = 0.
         do i = 1, n-1
            ip1 = i+1
            if (ip1 == n) ip1 = 1
            dl = sqrt((xp(ip1)-xp(i))**2 + (yp(ip1)-yp(i))**2)
            area_cell = area_cell + 0.25*(xp(i)+xp(ip1))*(yp(ip1)-yp(i)) - 0.25*(yp(i)+yp(ip1))*(xp(ip1)-xp(i))
            area_cellt = area_cellt + (0.25*(xp(i)+xp(ip1))*cos(thetat(i)) + 0.25*(yp(i)+yp(ip1))*sin(thetat(i)))*dl
         end do
         if (debug) call mpas_log_write(' area_cell, area_cellt $r $r $r', realArgs=(/area_cell, area_cellt,area_cell-area_cellt/))

         do i = 1, n-1
            ip1 = i+1
            if (ip1 == n) ip1 = 1
            dl = sqrt((xp(ip1)-xp(i))**2 + (yp(ip1)-yp(i))**2)
            sint2 = (sin(thetat(i)))**2
            cost2 = (cos(thetat(i)))**2
            sint_cost = sin(thetat(i))*cos(thetat(i))
            defc_a(i,iCell) = dl*(cost2 - sint2)/area_cell
            defc_b(i,iCell) = dl*2.*sint_cost/area_cell
            if (cellsOnEdge(1,edgesOnCell(i,iCell)) /= iCell) then
               defc_a(i,iCell) = - defc_a(i,iCell)
               defc_b(i,iCell) = - defc_b(i,iCell)
            end if
 
         end do

      end do

      if (debug) call mpas_log_write(' exiting def weight calc ')

   end subroutine sw_initialize_deformation_weights

end module sw_advection
