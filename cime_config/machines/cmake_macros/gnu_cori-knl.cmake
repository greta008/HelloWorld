if (NOT DEBUG)
  string(APPEND CFLAGS " -O2")
  string(APPEND FFLAGS " -O2")
endif()
if (NOT MPILIB STREQUAL mpi-serial)
  string(APPEND SLIBS " -L$ENV{ADIOS2_DIR}/lib64 -ladios2_c_mpi -ladios2_c -ladios2_core_mpi -ladios2_core -ladios2_evpath -ladios2_ffs -ladios2_dill -ladios2_atl -ladios2_enet")
endif()
string(APPEND CXX_LIBS " -lstdc++")
