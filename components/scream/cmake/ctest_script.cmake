cmake_minimum_required(VERSION 3.9)

set(CTEST_BUILD_NAME "scream_unit_tests${BUILD_NAME_MOD}")

get_filename_component(working_dir ${CMAKE_CURRENT_LIST_DIR} DIRECTORY)
set(CTEST_SOURCE_DIRECTORY "${working_dir}")
set(CTEST_BINARY_DIRECTORY "${working_dir}/ctest-build")

if(NOT DEFINED dashboard_model)
  set(dashboard_model Experimental)
endif()
if(NOT DEFINED dashboard_track)
  set(dashboard_track E3SM_SCREAM)
endif()

set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_CONFIGURE_COMMAND "${CMAKE_COMMAND} ${CTEST_SOURCE_DIRECTORY}")

ctest_start(${dashboard_model} TRACK ${dashboard_track})

ctest_configure()

if (DEFINED ENV{CTEST_PARALLEL_LEVEL})
  ctest_build(FLAGS "-j$ENV{CTEST_PARALLEL_LEVEL}" RETURN_VALUE BUILD_SUCCESS)
else()
  ctest_build(FLAGS "-j8" RETURN_VALUE BUILD_SUCCESS)
endif()

# Need this code so that build errors don't get buried
message("JGF BUILD_SUCCESS IS: ${BUILD_SUCCESS}")
if (NOT BUILD_SUCCESS STREQUAL "0")
  set(TEST_FAILS True)
  message("JGF HERE 1, checking glob ${CMAKE_BINARY_DIR}/Testing/Temporary/LastBuild*.log")
  file(GLOB MATCHES "${CMAKE_BINARY_DIR}/Testing/Temporary/LastBuild*.log")
    if (MATCHES)
      foreach (MATCH IN LISTS MATCHES)
        file(READ ${MATCH} BUILD_OUTPUT)
        message("Build failed with output:")
        message("${BUILD_OUTPUT}")
    endif()
else()
  if (NOT BUILD_ONLY)
    ctest_test(RETURN_VALUE TEST_RESULTS)
    if (NOT TEST_RESULTS EQUAL 0)
      set(TEST_FAILS True)
    endif()
  endif()
endif()

if (NOT NO_SUBMIT)
  ctest_submit(RETRY_COUNT 10 RETRY_DELAY 60)
endif()

if (TEST_FAILS)
  message(FATAL_ERROR "Test had fails")
endif()