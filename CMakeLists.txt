cmake_minimum_required(VERSION 3.19)
project(RootFftwWrapper VERSION 3.0.1)
# set(compatlibname "RootFftwWrapperCompat")

file(GLOB SOURCE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cxx")
# set (COMPAT_SOURCE_FILES src/FFTtools.cxx src/FFTWComplex.cxx src/RFSignal.cxx src/RFFilter.cxx ) 
add_library(${PROJECT_NAME} SHARED ${SOURCE_FILES})
# add_library(${compatlibname} SHARED ${COMPAT_SOURCE_FILES}) 

#================================================================================================
#                                       HOUSEKEEPING
#================================================================================================
if(NOT CMAKE_BUILD_TYPE) 
  set(CMAKE_BUILD_TYPE Default
    CACHE STRING "Choose tye type of build: Debug or Default"
    FORCE) 
endif()

if(NOT WIN32)
  string(ASCII 27 Esc)
  set(ColourReset "${Esc}[m")
  set(BoldGreen   "${Esc}[1;32m")
  set(BoldYellow  "${Esc}[1;33m")
  set(BoldBlue    "${Esc}[1;34m")
endif()

find_package(ROOT CONFIG REQUIRED COMPONENTS FitPanel MathMore Spectrum Minuit Minuit2)

if( ${ROOT_VERSION} VERSION_LESS "6.16")
  message(FATAL_ERROR "Please update ROOT to at least 6.16")
endif()

# TODO: FFTW didn't ship with a finder?
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules/")
find_package(FFTW REQUIRED)
message(STATUS "${BoldGreen}FFTW_INCLUDES is set to ${FFTW_INCLUDES}${ColourReset}")

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

## API compatibility
option(
  FORCE_OLD_GPP_ABI
  "Force old g++ ABI;
   this might be necessary if using new g++ with ROOT compiled with older g++ or other similar situations"
   OFF
)
if(FORCE_OLD_GPP_ABI)
  target_compile_options(${PROJECT_NAME} PUBLIC -D_GLIBCXX_USE_CXX11_ABI=0)
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

file(GLOB HEADER_FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/*.h")
# set (COMPAT_HEADER_FILES include/FFTtools.h include/FFTWComplex.h include/RFSignal.h include/RFFilter.h ) 

set_target_properties(${PROJECT_NAME} PROPERTIES 
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR})

target_include_directories(${PROJECT_NAME} PUBLIC  
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> # note: do not use quotes here, expansion leads to errors...
  $<BUILD_INTERFACE:${FFTW_INCLUDES}>
  $<INSTALL_INTERFACE:include/${PROJECT_NAME}>
  $<INSTALL_INTERFACE:include/${PROJECT_NAME}/fftw>)

if(VECTORIZE)
  target_include_directories(${PROJECT_NAME} PUBLIC  
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/vectorclass>
    $<INSTALL_INTERFACE:include/${PROJECT_NAME}/vectorclass>)
endif()

# only use warning flags in debug mode
target_compile_options(${PROJECT_NAME} PRIVATE $<$<CONFIG:Debug>:-Wall -Wextra>)

# target_compile_definitions(${compatlibname} PUBLIC FFTTOOLS_COMPAT_MODE) 

target_link_libraries(${PROJECT_NAME} 
  PUBLIC ${FFTW_LIBRARIES} 
  PRIVATE  ROOT::FitPanel ROOT::MathMore  ROOT::Spectrum  ROOT::Minuit ROOT::Minuit2)
# target_link_libraries(${compatlibname} PUBLIC ${ROOT_LIBRARIES} ${FFTW_LIBRARIES} )

set(DICTNAME G__${PROJECT_NAME})
# set(DICTNAMECOMPAT G__${compatlibname})

root_generate_dictionary(${DICTNAME} ${HEADER_FILES} MODULE ${PROJECT_NAME} LINKDEF LinkDef.h OPTIONS ${DICTIONARY_OPTIONS})
# root_generate_dictionary(${DICTNAMECOMPAT} ${COMPAT_HEADER_FILES} MODULE ${compatlibname} LINKDEF LinkDef.h OPTIONS -DFFTTOOLS_COMPAT_MODE)

#================================================================================================
#                                       INSTALLING
#================================================================================================
                                   # note: trailing "/" is important
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/ DESTINATION include/${PROJECT_NAME})
if(VECTORIZE)
  install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/vectorclass DESTINATION include/${PROJECT_NAME})
endif()

file(GLOB FFTW_HEADERS "${FFTW_INCLUDES}/fftw3*")
# installing the fftw3 header files, in case downstream projects forget to use the FindFFTW.cmake module
install(FILES ${FFTW_HEADERS} DESTINATION include/${PROJECT_NAME}/fftw)
# installing the FindFFTW.cmake module
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules/FindFFTW.cmake
        DESTINATION ${CMAKE_INSTALL_PREFIX}/share/cmake/modules)

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
install(FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/${PROJECT_NAME}Config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
  DESTINATION "lib/cmake/${PROJECT_NAME}"
)

# installing the libraries
install(TARGETS ${PROJECT_NAME} EXPORT ${PROJECT_NAME}Targets LIBRARY DESTINATION lib)

# installing CERN ROOT's _rdict.pcm file
install(
  FILES "${CMAKE_CURRENT_BINARY_DIR}/lib${PROJECT_NAME}_rdict.pcm"
  DESTINATION DESTINATION lib
)

# installing the target file
install(EXPORT ${PROJECT_NAME}Targets
    FILE ${PROJECT_NAME}Targets.cmake
    NAMESPACE RootFftwWrapper::
    DESTINATION lib/cmake/${PROJECT_NAME})

#================================================================================================
#                                       BINARIES
#================================================================================================

if(FFTTOOLS_ENABLE_OPENMP) 
  add_executable(testOpenMP "${CMAKE_CURRENT_SOURCE_DIR}/test/testOpenMP.cxx")
  target_link_libraries(testOpenMP 
    PRIVATE ${PROJECT_NAME} ROOT::FitPanel ROOT::MathMore ROOT::Spectrum ROOT::Minuit ROOT::Minuit2)
endif() 

set(BINLIST testFFTtools testSubtract)
foreach(b IN LISTS BINLIST) 
  add_executable(${b} "${CMAKE_CURRENT_SOURCE_DIR}/test/${b}.cxx") 
  target_link_libraries(${b} 
    PRIVATE ${PROJECT_NAME} ROOT::FitPanel ROOT::MathMore ROOT::Spectrum ROOT::Minuit ROOT::Minuit2)
endforeach()
