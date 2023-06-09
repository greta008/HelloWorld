set(ALBANY_PATH "/global/homes/m/mperego/e3sm-software/albany-trilinos/albany-install-2021-10-01")
string(APPEND CONFIG_ARGS " --host=cray")
if (MPILIB STREQUAL impi)
  string(APPEND CFLAGS " -axMIC-AVX512 -xCORE-AVX2")
endif()
string(APPEND CPPDEFS " -DARCH_MIC_KNL")
string(APPEND FFLAGS " -fp-model consistent -fimf-use-svml")
if (NOT DEBUG)
  string(APPEND FFLAGS " -qno-opt-dynamic-align")
endif()
if (MPILIB STREQUAL impi)
  string(APPEND FFLAGS " -xMIC-AVX512")
endif()
string(APPEND FFLAGS " -DHAVE_ERF_INTRINSICS")
string(APPEND CXXFLAGS " -fp-model consistent")
if (MPILIB STREQUAL impi)
  set(MPICC "mpiicc")
  set(MPICXX "mpiicpc")
  set(MPIFC "mpiifort")
  set(MPI_LIB_NAME "impi")
endif()
set(PETSC_PATH "$ENV{PETSC_DIR}")
set(SCC "icc")
set(SCXX "icpc")
set(SFC "ifort")
string(APPEND SLIBS " -L$ENV{NETCDF_DIR} -lnetcdff -Wl,--as-needed,-L$ENV{NETCDF_DIR}/lib -lnetcdff -lnetcdf")
string(APPEND SLIBS " -mkl -lpthread")
if (NOT MPILIB STREQUAL mpi-serial)
  string(APPEND SLIBS " -L$ENV{ADIOS2_DIR}/lib64 -ladios2_c_mpi -ladios2_c -ladios2_core_mpi -ladios2_core -ladios2_evpath -ladios2_ffs -ladios2_dill -ladios2_atl -ladios2_enet")
endif()
