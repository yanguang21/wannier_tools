! calculate bulk's energy band using wannier TB method
  subroutine fermisurface

     use mpi
     use para

     implicit none

     integer :: ik, i, j
	  integer :: knv3
     integer :: nkx
     integer :: nky

     integer :: ierr
     real(dp) :: kz
     real(Dp) :: k(3)
     
     ! Hamiltonian of bulk system
     complex(Dp) :: Hamk_bulk(Num_wann,Num_wann) 

     real(dp) :: kxmin, kxmax, kymin, kymax, omega
     real(dp) :: kxmin_shape, kxmax_shape, kymin_shape, kymax_shape

     real(dp), allocatable :: kxy(:,:)
     real(dp), allocatable :: kxy_shape(:,:)
     
     real(dp), allocatable :: dos(:)
     real(dp), allocatable :: dos_mpi(:)

     complex(dp), allocatable :: ones(:,:)

     nkx= Nk
     nky= Nk
     allocate( kxy(2, nkx*nky))
     allocate( kxy_shape(2, nkx*nky))
     kxy=0d0
     kxy_shape=0d0

     kymin=-0.20d0/1d0
     kymax= 0.20d0/1d0
     kxmin=-0.20d0/1d0
     kxmax= 0.20d0/1d0
     kz= 0d0
     ik =0
     do i= 1, nkx
     do j= 1, nky
        ik =ik +1
        kxy(1, ik)=kxmin+ (i-1)*(kxmax-kxmin)/dble(nkx-1)
        kxy(2, ik)=kymin+ (j-1)*(kymax-kymin)/dble(nky-1)
     enddo
     enddo


     knv3= nkx*nky
     allocate( dos    (knv3))
     allocate( dos_mpi(knv3))
     dos    = 0d0
     dos_mpi= 0d0

     allocate(ones(Num_wann, Num_wann))
     ones= 0d0
     do i=1, Num_wann
        ones(i, i)= 1d0
     enddo
     do ik= 1+cpuid, knv3, num_cpu
	     if (cpuid==0) print * , ik

        k(1) = kxy(1, ik)
        k(2) = kxy(2, ik)
        k(3) = kz

        ! calculation bulk hamiltonian
        Hamk_bulk= 0d0
        call ham_bulk(k, Hamk_bulk)

        Hamk_bulk= (E_arc -zi* eta_arc)* ones - Hamk_bulk
        call inv(Num_wann, Hamk_bulk)
        do i=1, Num_wann
           dos(ik)= dos(ik)+ aimag(Hamk_bulk(i, i))/pi
        enddo

     enddo

     call mpi_allreduce(dos,dos_mpi,size(dos),&
                       mpi_dp,mpi_sum,mpi_cmw,ierr)

     if (cpuid==0)then
        open(unit=14, file='fs.dat')
   
        do ik=1, knv3
           write(14, '(3f16.8)')kxy(:, ik), log(dos_mpi(ik))
           if (mod(ik, nky)==0) write(14, *)' '
        enddo
        close(14)
     endif

     !> minimum and maximum value of energy bands

     !> write script for gnuplot
     if (cpuid==0) then
        open(unit=101, file='fs.gnu')
        write(101, '(a)')'#set terminal  postscript enhanced color'
        write(101, '(a)')"#set output 'fs.eps'"
        write(101, '(3a)')'set terminal  png truecolor enhanced', &
           ' transparent font Monaco giant size 1920, 1680'
        write(101, '(a)')"set output 'fs.png'"
        write(101,'(2a)') '#set palette defined ( -10 "green", ', &
           '0 "yellow", 10 "red" )'
        write(101, '(a)')'set palette rgbformulae 33,13,10'
        write(101, '(a)')'unset ztics'
        write(101, '(a)')'unset key'
        write(101, '(a)')'set pm3d'
        write(101, '(a)')'set view equal xyz'
        write(101, '(a)')'set view map'
        write(101, '(a)')'#set xtics font ",24"'
        write(101, '(a)')'#set ytics font ",24"'
        write(101, '(a)')'unset xtics'
        write(101, '(a)')'unset ytics'
        write(101, '(a)')'unset colorbox'
        write(101, '(a, f8.5, a, f8.5, a)')'set xrange [', kxmin, ':', kxmax, ']'
        write(101, '(a, f8.5, a, f8.5, a)')'set yrange [', kymin, ':', kymax, ']'
        write(101, '(a)')'set pm3d interpolate 2,2'
        write(101, '(2a)')"splot 'fs.dat' u 1:2:3 w pm3d"

     endif


   return
   end subroutine fermisurface
