if (COMP_NAME STREQUAL gptl)
  string(APPEND CPPDEFS " -DHAVE_SLASHPROC")
endif()
string(APPEND CFLAGS " -static-intel")
string(APPEND CFLAGS " -march=core-avx2")
if (NOT DEBUG)
  string(APPEND CFLAGS " -O3")
endif()
string(APPEND CXXFLAGS " -static-intel")
string(APPEND CXXFLAGS " -axCORE-AVX2")
if (NOT DEBUG)
  string(APPEND CXXFLAGS " -O3")
endif()
string(APPEND FFLAGS " -static-intel")
string(APPEND FFLAGS " -axCORE-AVX2")
if (NOT DEBUG)
  string(APPEND FFLAGS " -O3 -qno-opt-dynamic-align")
endif()
set(PIO_FILESYSTEM_HINTS "gpfs")
execute_process(COMMAND $ENV{NETCDF_FORTRAN_PATH}/bin/nf-config --flibs OUTPUT_VARIABLE SHELL_CMD_OUTPUT_BUILD_INTERNAL_IGNORE0 OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND $ENV{NETCDF_C_PATH}/bin/nc-config --libs OUTPUT_VARIABLE SHELL_CMD_OUTPUT_BUILD_INTERNAL_IGNORE1 OUTPUT_STRIP_TRAILING_WHITESPACE)
string(APPEND SLIBS " ${SHELL_CMD_OUTPUT_BUILD_INTERNAL_IGNORE0} ${SHELL_CMD_OUTPUT_BUILD_INTERNAL_IGNORE1} -mkl")
if (NOT MPILIB STREQUAL mpi-serial)
  string(APPEND SLIBS " -L$ENV{ADIOS2_DIR}/lib64 -ladios2_c_mpi -ladios2_c -ladios2_core_mpi -ladios2_core -ladios2_evpath -ladios2_ffs -ladios2_dill -ladios2_atl -ladios2_enet")
endif()
set(NETCDF_C_PATH "$ENV{NETCDF_C_PATH}")
set(NETCDF_FORTRAN_PATH "$ENV{NETCDF_FORTRAN_PATH}")
set(PNETCDF_PATH "$ENV{PNETCDF_PATH}")
string(APPEND LDFLAGS " -static-intel")
if (MPILIB STREQUAL impi)
  set(MPICC "mpiicc")
  set(MPICXX "mpiicpc")
  set(MPIFC "mpiifort")
endif()
