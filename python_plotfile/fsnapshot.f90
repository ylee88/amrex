!------------------------------------------------------------------------------
! fplotfile_get_size
!------------------------------------------------------------------------------
subroutine fplotfile_get_size(pltfile, nx, ny, nz)

  use bl_IO_module
  use plotfile_module

  implicit none

  character (len=*), intent(in) :: pltfile
  integer, intent(out) :: nx, ny, nz

!f2py intent(in) :: pltfile
!f2py intent(out) :: nx, ny, nz
!f2py note return the dimensions of the data at the finest level of refinement
  type(plotfile) :: pf
  integer :: unit

  integer, allocatable :: flo(:), fhi(:)

  integer :: max_level


  ! build the plotfile to get the level information
  unit = unit_new()
  call build(pf, pltfile, unit)

  max_level = pf%flevel

  if (pf%dim == 2) then
     
     ! 2-d -- return maximum size of finest level
     allocate(flo(2), fhi(2))

     flo = lwb(plotfile_get_pd_box(pf, max_level))
     fhi = upb(plotfile_get_pd_box(pf, max_level))

     nx = fhi(1) - flo(1) + 1
     ny = fhi(2) - flo(2) + 1
     nz = -1

  else if (pf%dim == 3) then

     ! 3-d -- return maximum size of finest level
     allocate(flo(3), fhi(3))

     flo = lwb(plotfile_get_pd_box(pf, max_level))
     fhi = upb(plotfile_get_pd_box(pf, max_level))

     nx = fhi(1) - flo(1) + 1
     ny = fhi(2) - flo(2) + 1
     nz = fhi(3) - flo(3) + 1

  endif

  deallocate(flo, fhi)
  call destroy(pf)

end subroutine fplotfile_get_size


!------------------------------------------------------------------------------
! fplotfile_get_time
!------------------------------------------------------------------------------
subroutine fplotfile_get_time(pltfile, time)

  use bl_IO_module
  use plotfile_module

  implicit none

  character (len=*), intent(in) :: pltfile
  double precision, intent(out) :: time

!f2py intent(in) :: pltfile
!f2py intent(out) :: time

  type(plotfile) :: pf
  integer :: unit


  ! build the plotfile to get the level information
  unit = unit_new()
  call build(pf, pltfile, unit)

  time = pf%tm

  call destroy(pf)

end subroutine fplotfile_get_time


!------------------------------------------------------------------------------
! fplotfile_get_limits
!------------------------------------------------------------------------------
subroutine fplotfile_get_limits(pltfile, xmin, xmax, ymin, ymax, zmin, zmax)

  use bl_IO_module
  use plotfile_module

  implicit none

  character (len=*), intent(in) :: pltfile
  double precision, intent(out) :: xmin, xmax, ymin, ymax, zmin, zmax

!f2py intent(in) :: pltfile
!f2py intent(out) :: xmin, xmax, ymin, ymax, zmin, zmax

  type(plotfile) :: pf
  integer :: unit

  integer :: max_level


  ! build the plotfile to get the level information
  unit = unit_new()
  call build(pf, pltfile, unit)

  xmin = pf%plo(1)
  xmax = pf%phi(1)
  ymin = pf%plo(2)
  ymax = pf%phi(2)
  if (pf%dim == 3) then
     zmin = pf%plo(3)
     zmax = pf%phi(3)
  else
     zmin = -1.0
     zmax = -1.0
  endif

  call destroy(pf)

end subroutine fplotfile_get_limits


!------------------------------------------------------------------------------
! fplotfile_get_data_2d
!------------------------------------------------------------------------------
subroutine fplotfile_get_data_2d(pltfile, component, mydata, nx, ny, ierr)

  use bl_IO_module
  use plotfile_module
  use filler_module

  implicit none

  character (len=*), intent(in) :: pltfile
  character (len=*), intent(in) :: component
  integer, intent(in) :: nx, ny
  double precision, intent(inout) :: mydata(nx, ny)
  integer, intent(out) :: ierr

!f2py intent(in) :: pltfile, component
!f2py intent(in,out) :: mydata
!f2py intent(hide) :: nx, ny
!f2py intent(out) :: ierr

  type(plotfile) :: pf
  integer ::unit

  integer :: comp

  integer :: flo(2), fhi(2)
  real(kind=dp_t), allocatable :: c_fab(:,:,:)

  integer :: max_level

  ierr = 0

  ! build the plotfile to get the level and component information
  unit = unit_new()
  call build(pf, pltfile, unit)

  ! figure out the variable indices
  comp = plotfile_var_index(pf, component)
  if (comp < 0) then
     print *, "ERROR: component ", trim(component), " not found in plotfile"
     ierr = 1
     return
  endif

  max_level = pf%flevel

  ! for 2-d, we will put the dataset onto a uniform grid 
  flo = lwb(plotfile_get_pd_box(pf, max_level))
  fhi = upb(plotfile_get_pd_box(pf, max_level))
  allocate(c_fab(flo(1):fhi(1), flo(2):fhi(2), 1))

  if ( (nx /= (fhi(1) - flo(1) + 1)) .or. &
       (ny /= (fhi(2) - flo(2) + 1)) ) then
     print *, "ERROR: input array wrong dimensions"
     deallocate(c_fab)
     ierr = 1
     return
  endif

  call blow_out_to_fab(c_fab, flo, pf, (/comp/), max_level)

  
  mydata(:,:) = c_fab(:,:,1)

  deallocate(c_fab)

  call destroy(pf)

end subroutine fplotfile_get_data_2d


!------------------------------------------------------------------------------
! fplotfile_get_data_3d
!------------------------------------------------------------------------------
subroutine fplotfile_get_data_3d(pltfile, component, &
                                 indir, origin, mydata, m, n, ierr)

  use bl_constants_module, ONLY: ZERO
  use bl_IO_module
  use plotfile_module
  use filler_module

  implicit none

  character (len=*), intent(in) :: pltfile
  character (len=*), intent(in) :: component
  integer, intent(in) :: indir     ! normal direction
  integer, intent(in) :: origin    ! pass through origin (1), or center
  integer, intent(in) :: m, n
  double precision, intent(inout) :: mydata(m, n)
  integer, intent(out) :: ierr

!f2py intent(in) :: pltfile, component
!f2py intent(in) :: indir
!f2py intent(in) :: origin
!f2py intent(in,out) :: mydata
!f2py intent(hide) :: m, n
!f2py intent(out) :: ierr

  real (kind=dp_t), allocatable :: slicedata(:,:)

  type(plotfile) :: pf
  integer ::unit

  integer :: comp

  integer ::  lo(3),  hi(3)
  integer :: flo(3), fhi(3)

  integer :: rr, r1

  integer :: i, j
  integer :: ii, jj, kk
  integer :: iloc, jloc, kloc

  real(kind=dp_t) :: dx(3), dx_fine(3)

  real(kind=dp_t), pointer :: p(:,:,:,:)

  logical, allocatable :: imask(:,:)

  integer :: max_level


  ierr = 0

  ! build the plotfile to get the level and component information
  unit = unit_new()
  call build(pf, pltfile, unit)

  ! figure out the variable indices
  comp = plotfile_var_index(pf, component)
  if (comp < 0) then
     print *, "ERROR: component ", trim(component), " not found in plotfile"
     ierr = 1
     return
  endif


  ! get the index bounds and dx for the coarse level.  Note, lo and
  ! hi are ZERO based indicies
  lo = lwb(plotfile_get_pd_box(pf, 1))
  hi = upb(plotfile_get_pd_box(pf, 1))

  dx = plotfile_get_dx(pf, 1)

  ! get the index bounds for the finest level
  flo = lwb(plotfile_get_pd_box(pf, pf%flevel))
  fhi = upb(plotfile_get_pd_box(pf, pf%flevel))

  dx_fine = minval(plotfile_get_dx(pf, pf%flevel))


  ! sanity checks
  select case (indir)

  case (1)
     if ( (m /= (fhi(2) - flo(2) + 1)) .or. &
          (n /= (fhi(3) - flo(3) + 1)) ) then
        print *, "ERROR: input array wrong dimensions"
        ierr = 1
        return
     endif

  case (2)
     if ( (m /= (fhi(1) - flo(1) + 1)) .or. &
          (n /= (fhi(3) - flo(3) + 1)) ) then
        print *, "ERROR: input array wrong dimensions"
        ierr = 1
        return
     endif

  case (3)
     if ( (m /= (fhi(1) - flo(1) + 1)) .or. &
          (n /= (fhi(2) - flo(2) + 1)) ) then
        print *, "ERROR: input array wrong dimensions"
        ierr = 1
        return
     endif

  case default

     print *, "ERROR: invalid indir"
     ierr = 1
     return

  end select



  ! determine the location of the slices -- either through the center
  ! or through the origin -- these are with respect to the coarse grid
  if (origin == 1) then
     iloc = lo(1)
     jloc = lo(2)
     kloc = lo(3)
  else
     iloc = (hi(1)-lo(1)+1)/2 + lo(1)
     jloc = (hi(2)-lo(2)+1)/2 + lo(2)
     kloc = (hi(3)-lo(3)+1)/2 + lo(3)
  endif


  ! imask will be set to false if we've already output the data.
  ! Note, imask is defined in terms of the finest level.  As we loop
  ! over levels, we will compare to the finest level index space to
  ! determine if we've already output here
  select case (indir)

  case (1)
     allocate(imask(flo(2):fhi(2),flo(3):fhi(3)))
     allocate(slicedata(flo(2):fhi(2),flo(3):fhi(3)))

  case (2)
     allocate(imask(flo(1):fhi(1),flo(3):fhi(3)))
     allocate(slicedata(flo(1):fhi(1),flo(3):fhi(3)))

  case (3)
     allocate(imask(flo(1):fhi(1),flo(2):fhi(2)))
     allocate(slicedata(flo(1):fhi(1),flo(2):fhi(2)))

  end select

  imask(:,:) = .true.


  slicedata(:,:) = ZERO


  !-------------------------------------------------------------------------
  ! loop over the data, starting at the finest grid, and if we haven't       
  ! already store data in that grid location (according to imask),           
  ! store it.                                                                
  !-------------------------------------------------------------------------

  ! r1 is the factor between the current level grid spacing and the          
  ! FINEST level                                                             
  r1  = 1

  do i = pf%flevel, 1, -1
        
     ! rr is the factor between the COARSEST level grid spacing and          
     ! the current level                                                     
     rr = product(pf%refrat(1:i-1,1))

     do j = 1, nboxes(pf, i)

        call fab_bind_comp_vec(pf, i, j, (/comp/) )

        lo = lwb(get_box(pf, i, j))
        hi = upb(get_box(pf, i, j))


        select case (indir)

        case (1)
           ! produce a slice perpendicular to the x-axis

           ! if the current patch stradles our slice plane, then get a data  
           ! pointer to it                                                   
           if (rr*iloc >= lo(1) .and. rr*iloc <= hi(1)) then

              p => dataptr(pf, i, j)
              ii = iloc*rr

              ! loop over all of the zones in the patch.  Here, we convert   
              ! the cell-centered indices at the current level into the      
              ! corresponding RANGE on the finest level, and test if we've   
              ! stored data in any of those locations.  If we haven't then   
              ! we store this level's data and mark that range as filled.    
              do kk = lbound(p,dim=3), ubound(p,dim=3)
                 do jj = lbound(p,dim=2), ubound(p,dim=2)

                    if ( any(imask(jj*r1:(jj+1)*r1-1, &
                                   kk*r1:(kk+1)*r1-1) ) ) then

                       ! since we've only bound one component to pf, we      
                       ! index p with 1 for the component                    
                       slicedata(jj*r1:(jj+1)*r1-1, &
                                 kk*r1:(kk+1)*r1-1) = p(ii,jj,kk,1)

                       imask(jj*r1:(jj+1)*r1-1, &
                             kk*r1:(kk+1)*r1-1) = .false.

                    end if

                 end do
              enddo

           endif

        case (2)
           ! produce a slice perpendicular to the y-axis                     

           ! if the current patch stradles our slice plane, then get a data  
           ! pointer to it                                                   
           if (rr*jloc >= lo(2) .and. rr*jloc <= hi(2)) then

              p => dataptr(pf, i, j)
              jj = jloc*rr

              ! loop over all of the zones in the patch.  Here, we convert   
              ! the cell-centered indices at the current level into the      
              ! corresponding RANGE on the finest level, and test if we've   
              ! stored data in any of those locations.  If we haven't then   
              ! we store this level's data and mark that range as filled.    
              do kk = lbound(p,dim=3), ubound(p,dim=3)
                 do ii = lbound(p,dim=1), ubound(p,dim=1)

                    if ( any(imask(ii*r1:(ii+1)*r1-1, &
                                   kk*r1:(kk+1)*r1-1) ) ) then

                       ! since we've only bound one component to pf, we      
                       ! index p with 1 for the component                    
                       slicedata(ii*r1:(ii+1)*r1-1, &
                                 kk*r1:(kk+1)*r1-1) = p(ii,jj,kk,1)

                       imask(ii*r1:(ii+1)*r1-1, &
                             kk*r1:(kk+1)*r1-1) = .false.

                    endif

                 end do
              enddo
              
           endif

        case (3)
           ! produce a slice perpendicular to the z-axis

           ! if the current patch stradles our slice plane, then get a data  
           ! pointer to it                                                   
           if (rr*kloc >= lo(3) .and. rr*kloc <= hi(3)) then

              p => dataptr(pf, i, j)
              kk = kloc*rr

              ! loop over all of the zones in the patch.  Here, we convert   
              ! the cell-centered indices at the current level into the      
              ! corresponding RANGE on the finest level, and test if we've   
              ! stored data in any of those locations.  If we haven't then   
              ! we store this level's data and mark that range as filled.    
              do jj = lbound(p,dim=2), ubound(p,dim=2)
                 do ii = lbound(p,dim=1), ubound(p,dim=1)

                    if ( any(imask(ii*r1:(ii+1)*r1-1, &
                                   jj*r1:(jj+1)*r1-1) ) ) then

                       ! since we've only bound one component to pf, we      
                       ! index p with 1 for the component                    
                       slicedata(ii*r1:(ii+1)*r1-1, &
                                 jj*r1:(jj+1)*r1-1) = p(ii,jj,kk,1)

                       imask(ii*r1:(ii+1)*r1-1, &
                             jj*r1:(jj+1)*r1-1) = .false.

                    end if

                 enddo
              enddo

           endif

        end select

        call fab_unbind(pf, i, j)

     enddo

     ! adjust r1 for the next lowest level                                   
     if ( i /= 1 ) r1 = r1*pf%refrat(i-1,1)

  end do

  mydata(:,:) = slicedata(:,:)

  deallocate(imask)
  deallocate(slicedata)

  call destroy(pf)

end subroutine fplotfile_get_data_3d
