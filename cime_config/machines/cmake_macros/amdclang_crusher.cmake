string(APPEND SLIBS " -L$ENV{PNETCDF_PATH}/lib -lpnetcdf -L$ENV{CRAY_LIBSCI_PREFIX_DIR}/lib -lsci_amd")
set(PNETCDF_PATH "$ENV{PNETCDF_DIR}")
set(CRAY_LIBSCI_PREFIX_DIR "$ENV{CRAY_LIBSCI_PREFIX_DIR}")
set(PIO_FILESYSTEM_HINTS "gpfs")
#if (COMP_NAME STREQUAL gptl)
#  string(APPEND CPPDEFS " -DFORTRANUNDERSCORE")
#endif()
