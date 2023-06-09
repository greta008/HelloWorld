string(APPEND CONFIG_ARGS " --host=cray")
if (COMP_NAME STREQUAL gptl)
  string(APPEND CPPDEFS " -DHAVE_NANOTIME -DBIT64 -DHAVE_SLASHPROC -DHAVE_GETTIMEOFDAY")
endif()
string(APPEND SLIBS " -L$ENV{CRAY_HDF5_PARALLEL_PREFIX}/lib -lhdf5_hl -lhdf5 -L$ENV{CRAY_NETCDF_HDF5PARALLEL_PREFIX} -L$ENV{CRAY_PARALLEL_NETCDF_PREFIX}/lib -lpnetcdf -lnetcdf -lnetcdff")
string(APPEND SLIBS " -lblas -llapack")
if (NOT MPILIB STREQUAL mpi-serial)
  string(APPEND SLIBS " -L$ENV{ADIOS2_DIR}/lib64 -ladios2_c_mpi -ladios2_c -ladios2_core_mpi -ladios2_core -ladios2_evpath -ladios2_ffs -ladios2_dill -ladios2_atl -ladios2_enet")
endif()
set(CXX_LINKER "FORTRAN")
set(NETCDF_PATH "$ENV{CRAY_NETCDF_HDF5PARALLEL_PREFIX}")
set(NETCDF_C_PATH "$ENV{CRAY_NETCDF_HDF5PARALLEL_PREFIX}")
set(NETCDF_FORTRAN_PATH "$ENV{CRAY_NETCDF_HDF5PARALLEL_PREFIX}")
set(HDF5_PATH "$ENV{CRAY_HDF5_PARALLEL_PREFIX}")
set(PNETCDF_PATH "$ENV{CRAY_PARALLEL_NETCDF_PREFIX}")
if (NOT DEBUG)
  string(APPEND CFLAGS " -O2")
endif()
if (NOT DEBUG)
  string(APPEND CXXFLAGS " -O2")
endif()
if (NOT DEBUG)
  string(APPEND FFLAGS " -g")
endif()
if (compile_threaded)
  string(APPEND KOKKOS_OPTIONS " -DKokkos_ENABLE_OPENMP=Off") # work-around for nvidia as kokkos is not passing "-mp" for threaded build
endif()
set(MPICC "cc")
set(MPICXX "CC")
set(MPIFC "ftn")
set(SCC "cc")
set(SCXX "CC")
set(SFC "ftn")
