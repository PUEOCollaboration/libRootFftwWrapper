# @file     NewCMakeLists.cmake
# @purpose  Makes this library into a target for ease of use downstream
#           See the PR description: https://github.com/PUEOCollaboration/libRootFftwWrapper/pull/1
# @warning  NO LONGER BUILDING COMPAT VERSION OF libRootFftwWrapper IF YOU USE THIS FILE 
# @note     Reference: https://blog.vito.nyc/posts/cmake-pkg/#fnref:4

add_library(${PROJECT_NAME} SHARED)

#================================================================================================
#                                       HOUSEKEEPING
#================================================================================================
if(NOT CMAKE_BUILD_TYPE) 
  set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "" FORCE) 
endif()

find_package(ROOT CONFIG REQUIRED COMPONENTS FitPanel MathMore Spectrum Minuit Minuit2)

if( ${ROOT_VERSION} VERSION_LESS "6.16")
  message(FATAL_ERROR "Please update ROOT to at least 6.16")
endif()

# TODO: FFTW didn't ship with a finder?
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules/")
find_package(FFTW REQUIRED)
message(STATUS "FFTW_INCLUDES is set to ${FFTW_INCLUDES}")

#================================================================================================
#                                       OPTIONS
#================================================================================================
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND NATIVE_ARCH AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 4.1) 
  target_compile_options(${PROJECT_NAME} PUBLIC -march=native)
endif() 

# Use VCL (header files in vectorclass) written by Agner Fog for performance gain.
option(VECTORIZE "Enable Manual SIMD Vectorization. This will install the header files in vectorclass as well" ON) 

if(VECTORIZE)
  target_compile_definitions(${PROJECT_NAME} PUBLIC ENABLE_VECTORIZE ) 
  # From VCL documentation:
  #   If you are using the Gnu compiler version 3.x or 4.x then you must
  #   set the ABI version to 4 or more, or 0 for a reasonable default
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 5.0)
    target_compile_options(${PROJECT_NAME} PUBLIC -fabi-version=0)
  endif() 
endif() 

##  Linear algebra options 
option(USE_EIGEN "Use Eigen3 for certain linear algebra options" OFF) 
option(USE_ARMADILLO "Use Armadillo for certain linear algebra options" OFF) 

if (USE_EIGEN AND USE_ARMADILLO) 
  message(FATAL_ERROR "USE_EIGEN and USE_ARMADILLO are mutually exclusive") 

elseif(USE_EIGEN) # note: dnf install eigen3-devel (Fedora linux)
  find_package(Eigen3 CONFIG REQUIRED) 
  target_compile_definitions(${PROJECT_NAME} PRIVATE USE_EIGEN) 
  target_link_libraries(${PROJECT_NAME} PRIVATE Eigen3::Eigen) 

elseif(USE_ARMADILLO) #note: dnf install armadillo-devel
  find_package(Armadillo REQUIRED)
  target_compile_definitions(${PROJECT_NAME} PRIVATE USE_ARMADILLO) 
  target_include_directories(${PROJECT_NAME} PRIVATE ${ARMADILLO_INCLUDE_DIRS})
  target_link_libraries(${PROJECT_NAME} PRIVATE ${ARMADILLO_LIBRARIES}) 
endif() 

## Multithread options 
option(
  FFTTOOLS_ENABLE_OPENMP 
  "Enable OpenMP support (experimental, mutually exclusive with FFTTOOLS_ENABLE_THREAD_SAFE) for doFft and doInvFft" 
  OFF
) 
option(
  FFTTOOLS_ENABLE_THREAD_SAFE 
  "Make fft methods threadsafe (mutually exclusive with FFTTOOLS_ENABLE_OPEMP)" 
  OFF
)

if (FFTTOOLS_ENABLE_OPENMP AND FFTTOOLS_ENABLE_THREAD_SAFE)
  message(FATAL_ERROR "FFTTOOLS_ENABLE_THREAD_SAFE and FFTTOOLS_ENABLE_OPENMP are mutually exclusive")

elseif(FFTTOOLS_ENABLE_THREAD_SAFE)
  target_compile_definitions(${PROJECT_NAME} PRIVATE FFTTOOLS_THREAD_SAFE)

elseif(FFTTOOLS_ENABLE_OPENMP)
  find_package(OpenMP REQUIRED)
  target_compile_definitions(${PROJECT_NAME} PRIVATE FFTTOOLS_USE_OMP)
  target_link_libraries(${PROJECT_NAME} PRIVATE OpenMP::OpenMP_CXX)
endif()


macro(stupid_option option_name option_description) 
  option (${option_name} ${option_description} OFF) 
  if (${option_name}) 
    target_compile_definitions(${PROJECT_NAME} PRIVATE ${option_name} )
  endif()
endmacro() 

## Random Sine Subtraction options
# stupid_option(SINE_SUBTRACT_USE_FLOATS  "Use floats for vectorized sine subtraction") 
# mark_as_advanced(SINE_SUBTRACT_USE_FLOATS)

# stupid_option(SINE_SUBTRACT_PROFILE  "Enable Sine Subtraction profiling (you probably don't want to do this)") 
# mark_as_advanced(SINE_SUBTRACT_PROFILE)

## Miscellaneous options
# stupid_option(FFTW_USE_PATIENT  "Use FFTW Patient plans... not recommended unless you are good about saving wisdom")
# mark_as_advanced(FFTW_USE_PATIENT) 


#================================================================================================
#                                       CERN ROOT FLAGS
#================================================================================================
# change log: https://github.com/PUEOCollaboration/libRootFftwWrapper/pull/1

# obtain the C++ standard that ROOT is compiled with
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules/getRootStandard.cmake)
# setting C++ standard (https://cliutils.gitlab.io/modern-cmake/chapters/features/cpp11.html)
target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_${ROOT_CXX_STANDARD})
set_target_properties(${PROJECT_NAME} PROPERTIES CXX_EXTENSIONS OFF) # turns -std=gnu++17 -> -std=c++17
# note that the flag -std=cxx_std_* may be omitted by CMake if requested standard < default standard
# see (https://cmake.org/cmake/help/latest/prop_gbl/CMAKE_CXX_KNOWN_FEATURES.html#high-level-meta-features-indicating-c-standard-support)

# pretty sure pthread is not actually needed, but I guess it doesn't hurt to keep this
set(THREADS_PREFER_PTHREAD_FLAG ON) # CMake Doc: https://cmake.org/cmake/help/latest/module/FindThreads.html
find_package(Threads REQUIRED) 	    # Usage:     https://stackoverflow.com/a/29871891/21955752
target_link_libraries(${PROJECT_NAME} PUBLIC Threads::Threads)

target_compile_options(${PROJECT_NAME} PUBLIC -pipe)
target_compile_options(${PROJECT_NAME} PUBLIC -fsigned-char) # without this flag pueoSim segfaults (on mac)
#================================================================================================
#                                       BUILDING
#================================================================================================
target_sources(${PROJECT_NAME} PRIVATE
  src/AnalyticSignal.cxx
  src/Averager.cxx
  src/CWT.cxx
  src/DigitalFilter.cxx
  src/FFTWComplex.cxx
  src/FFTWindow.cxx
  src/FFTtools.cxx
  src/FFTtoolsRev.cxx
  src/Periodogram.cxx
  src/RFFilter.cxx
  src/RFInterpolate.cxx
  src/RFSignal.cxx
  src/SineSubtract.cxx
)
set(HEADER_FILES
  include/AnalyticSignal.h
  include/Averager.h
  include/CWT.h
  include/DigitalFilter.h
  include/FFTWComplex.h
  include/FFTWindow.h
  include/FFTtools.h
  include/FFTtoolsRev.h
  include/RFFilter.h
  include/RFInterpolate.h
  include/RFSignal.h
  include/SineSubtract.h
)
target_sources(${PROJECT_NAME} PUBLIC
  FILE_SET HEADERS
  BASE_DIRS include      # <-- Everything in BASE_DIRS is available during the build
  FILES ${HEADER_FILES}  # <-- But only FILES will be installed, although these two are currently the same
)

# gonna cheat by using generator expressions here because I don't want to list all the files in vectorclass
if(VECTORIZE)
  target_include_directories(${PROJECT_NAME} PUBLIC  
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/vectorclass>
    $<INSTALL_INTERFACE:include/${PROJECT_NAME}/vectorclass>)
endif()

# use warning flags in RelWithDebInfo mode, which is set to be the default mode
target_compile_options(${PROJECT_NAME} PRIVATE $<$<CONFIG:RelWithDebInfo>:-Wall -Wextra>)

target_link_libraries(${PROJECT_NAME} 
  PRIVATE ${FFTW_LIBRARIES} 
  PRIVATE ROOT::FitPanel ROOT::MathMore ROOT::Spectrum ROOT::Minuit ROOT::Minuit2)

set(DICTNAME G__${PROJECT_NAME})

root_generate_dictionary(${DICTNAME} ${HEADER_FILES} MODULE ${PROJECT_NAME} LINKDEF LinkDef.h OPTIONS ${DICTIONARY_OPTIONS})

#================================================================================================
#                                       INSTALLING
#================================================================================================
# the price of not using FILE_SET: manual installation :)
if(VECTORIZE)
  install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/vectorclass DESTINATION include/${PROJECT_NAME})
endif()

# Config files and such
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Generating RootFftwWrapperConfigVersion.cmake
write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY AnyNewerVersion
)
# Installing these two config files
install(
  FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/${PROJECT_NAME}Config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
  DESTINATION ${CMAKE_INSTALL_DATADIR}/${PROJECT_NAME}
)

# Exporting the project as a CMake Target as well as installing the library and headers
install(
  TARGETS ${PROJECT_NAME} 
  EXPORT ${PROJECT_NAME}Targets 
  FILE_SET HEADERS DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME}
)

# installing CERN ROOT's _rdict.pcm file
install(
  FILES "${CMAKE_CURRENT_BINARY_DIR}/lib${PROJECT_NAME}_rdict.pcm"
  DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# This will generate a Targets.cmake file and install it
install(
  EXPORT ${PROJECT_NAME}Targets
  NAMESPACE RootFftwWrapper::
  DESTINATION ${CMAKE_INSTALL_DATADIR}/${PROJECT_NAME}
)

#================================================================================================
#                                       BINARIES
#================================================================================================

if(FFTTOOLS_ENABLE_OPENMP) 
  add_executable(testOpenMP "${CMAKE_CURRENT_SOURCE_DIR}/test/testOpenMP.cxx")
  target_link_libraries(testOpenMP 
    PRIVATE ${PROJECT_NAME} ROOT::FitPanel ROOT::MathMore ROOT::Spectrum ROOT::Minuit ROOT::Minuit2
            OpenMP::OpenMP_CXX          
  )
endif() 

set(BINLIST testFFTtools testSubtract)
foreach(b IN LISTS BINLIST) 
  add_executable(${b} "${CMAKE_CURRENT_SOURCE_DIR}/test/${b}.cxx") 
  target_link_libraries(${b} 
    PRIVATE ${PROJECT_NAME} ROOT::FitPanel ROOT::MathMore ROOT::Spectrum ROOT::Minuit ROOT::Minuit2)
endforeach()
