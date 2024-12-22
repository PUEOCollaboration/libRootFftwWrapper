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
    CACHE STRING "Choose tye type of build: None Debug Release RelWithDebInfo MinSizeRel Default"
    FORCE) 
endif()

if(NOT WIN32)
  string(ASCII 27 Esc)
  set(ColourReset "${Esc}[m")
  set(BoldGreen   "${Esc}[1;32m")
  set(BoldYellow  "${Esc}[1;33m")
  set(BoldBlue    "${Esc}[1;34m")
endif()


find_package(ROOT CONFIG REQUIRED COMPONENTS MathMore MathCore RIO Hist Tree Net Minuit Spectrum Minuit2)
message(STATUS "${BoldGreen}Found ROOT ${ROOT_VERSION}${ColourReset}")
message(STATUS "${BoldGreen}ROOT_INCLUDE_DIRS is set to ${ROOT_INCLUDE_DIRS}${ColourReset}")
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

## Manual vectorization option; maybe in the future this can be made a CMake module or something 
option(VECTORIZE "Enable Manual SIMD Vectorization" ON) 
# This option is defined in pueoBuilder, default on here but off there
if(VECTORIZE)
  target_compile_definitions(${PROJECT_NAME} PRIVATE ENABLE_VECTORIZE ) 

  # TODO someone should do this for clang if they want it to be as fast as possible 
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU") 
    if (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 4.1)
      if(NATIVE_ARCH) # defined in pueoBuilder, default on
        target_compile_options(${PROJECT_NAME} PRIVATE -march=native)
      endif()
    endif()

    if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 5.0)
      # Vectorize docs...
      # If you are using the Gnu compiler version 3.x or 4.x then you must
      # set the ABI version to 4 or more, or 0 for a reasonable default
      target_compile_options(${PROJECT_NAME} PRIVATE -fabi-version=0)
    endif()
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

elseif(FFTTOOLS_ENABLE_OPENMP)  # TODO OpenMP currently broken (for Fedora Linux at least)
  find_package(OpenMP REQUIRED)
  target_compile_definitions(${PROJECT_NAME} PRIVATE FFTTOOLS_USE_OMP ${OpenMP_CXX_FLAGS})
endif()


## API compatibility
option(
  FORCE_OLD_GPP_ABI
  "Force old g++ ABI;
   this might be necessary if using new g++ with ROOT compiled with older g++ or other similar situations"
   OFF
)
if(FORCE_OLD_GPP_ABI)
  target_compile_options(${PROJECT_NAME} PRIVATE -D_GLIBCXX_USE_CXX11_ABI=0)
endif() 


macro(stupid_option option_name option_description) 
  option (${option_name} ${option_description} OFF) 
  if (${option_name}) 
    target_compile_definitions(${PROJECT_NAME} PRIVATE ${option_name} )
  endif()
endmacro() 

## Random Sine Subtraction options
stupid_option(SINE_SUBTRACT_USE_FLOATS  "Use floats for vectorized sine subtraction") 
mark_as_advanced(SINE_SUBTRACT_USE_FLOATS)

stupid_option(SINE_SUBTRACT_PROFILE  "Enable Sine Subtraction profiling (you probably don't want to do this)") 
mark_as_advanced(SINE_SUBTRACT_PROFILE)

## Miscellaneous options
stupid_option(FFTW_USE_PATIENT  "Use FFTW Patient plans... not recommended unless you are good about saving wisdom")
mark_as_advanced(FFTW_USE_PATIENT) 


#================================================================================================
#                                       BUILDING
#================================================================================================

file(GLOB HEADER_FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/*.h")
# set (COMPAT_HEADER_FILES include/FFTtools.h include/FFTWComplex.h include/RFSignal.h include/RFFilter.h ) 

set_target_properties(${PROJECT_NAME} PROPERTIES 
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR})

target_include_directories(${PROJECT_NAME}
  PUBLIC  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> # note: do not use quotes here, expansion leads to errors...
          $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/vectorclass>
          $<INSTALL_INTERFACE:include>
          $<INSTALL_INTERFACE:include/vectorclass>
  PRIVATE $<BUILD_INTERFACE:${ROOT_INCLUDE_DIRS}>
          $<BUILD_INTERFACE:${FFTW_INCLUDES}>
)

# Propagating these C/C++ compiler flags to downstream projects when they link against this library
target_compile_options(${PROJECT_NAME} PUBLIC "-Os" "-g" "-Wall" "-Wextra")
# target_compile_definitions(${compatlibname} PUBLIC FFTTOOLS_COMPAT_MODE) 

# Propagating this linker option to downstream projects when they link against this library
# TODO: Not sure if this is really needed, since "-g" is already set during compilation
target_link_options(${PROJECT_NAME} PUBLIC "-g")

# TODO: do we really need to link all of the ROOT libraries?
target_link_libraries(${PROJECT_NAME} PRIVATE ${ROOT_LIBRARIES} ${FFTW_LIBRARIES} )
# target_link_libraries(${compatlibname} ${ROOT_LIBRARIES} ${FFTW_LIBRARIES} )

set(DICTNAME G__${PROJECT_NAME})
# set(DICTNAMECOMPAT G__${compatlibname})

root_generate_dictionary(${DICTNAME} ${HEADER_FILES} MODULE ${PROJECT_NAME} LINKDEF LinkDef.h OPTIONS ${DICTIONARY_OPTIONS})
# root_generate_dictionary(${DICTNAMECOMPAT} ${COMPAT_HEADER_FILES} MODULE ${compatlibname} LINKDEF LinkDef.h OPTIONS -DFFTTOOLS_COMPAT_MODE)


#================================================================================================
#                                       INSTALLING
#================================================================================================

# installing headers
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/vectorclass DESTINATION include)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/ DESTINATION include)
                              # note: this trailing "/" is important, otherwise install dir will have a weird "includes/includes" structure
# Config files and such
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Generating RootFftwWrapperConfig.cmake
configure_package_config_file("${CMAKE_CURRENT_SOURCE_DIR}/Config.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
  INSTALL_DESTINATION "lib/cmake/${PROJECT_NAME}"
)
# Generating RootFftwWrapperConfigVersion.cmake
write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY AnyNewerVersion
)
# Installing these two config files
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
  DESTINATION "lib/cmake/${PROJECT_NAME}"
)

# installing the libraries
install(TARGETS ${PROJECT_NAME} EXPORT ${PROJECT_NAME}Targets LIBRARY DESTINATION lib)
# TODO: not sure if pcm files should be installed, or how (https://root-forum.cern.ch/t/cmake-not-installing-pcm-and-rootmap/50997)
# installing the target file
install(EXPORT ${PROJECT_NAME}Targets
    FILE ${PROJECT_NAME}Targets.cmake
    DESTINATION lib/cmake/${PROJECT_NAME})

#================================================================================================
#                                       BINARIES
#================================================================================================

if(FFTTOOLS_ENABLE_OPENMP) 
  add_executable(testOpenMP "${CMAKE_CURRENT_SOURCE_DIR}/test/testOpenMP.cxx")
  target_include_directories(testOpenMP PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(testOpenMP 
    PRIVATE ${ROOT_LIBRARIES} 
            ${FFTW_LIBRARIES} 
            ${PROJECT_NAME}
  )
endif() 

set(BINLIST testFFTtools testSubtract)
foreach(b IN LISTS BINLIST) 
  add_executable(${b}
    "${CMAKE_CURRENT_SOURCE_DIR}/test/${b}.cxx"
  ) 
  target_include_directories(${b} 
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include
  )
  target_link_libraries(${b} 
    PRIVATE ${ROOT_LIBRARIES} 
            ${FFTW_LIBRARIES} 
            ${PROJECT_NAME}
  )
endforeach()
