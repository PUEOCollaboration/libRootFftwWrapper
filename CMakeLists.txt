cmake_minimum_required(VERSION 3.19)
project(RootFftwWrapper VERSION 3.0.1)

#================================================================================================
#                                       HOUSEKEEPING
#================================================================================================

if(NOT WIN32)
  string(ASCII 27 Esc)
  set(ColourReset "${Esc}[m")
  set(ColourBold  "${Esc}[1m")
  set(Red         "${Esc}[31m")
  set(Green       "${Esc}[32m")
  set(Yellow      "${Esc}[33m")
  set(Blue        "${Esc}[34m")
  set(Magenta     "${Esc}[35m")
  set(Cyan        "${Esc}[36m")
  set(White       "${Esc}[37m")
  set(BoldRed     "${Esc}[1;31m")
  set(BoldGreen   "${Esc}[1;32m")
  set(BoldYellow  "${Esc}[1;33m")
  set(BoldBlue    "${Esc}[1;34m")
  set(BoldMagenta "${Esc}[1;35m")
  set(BoldCyan    "${Esc}[1;36m")
  set(BoldWhite   "${Esc}[1;37m")
endif()

# set(compatlibname "RootFftwWrapperCompat")

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
#                                       BUILDING
#================================================================================================

file(GLOB HEADER_FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/*.h")
file(GLOB SOURCE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cxx")
# set (COMPAT_SOURCE_FILES src/FFTtools.cxx src/FFTWComplex.cxx src/RFSignal.cxx src/RFFilter.cxx ) 
# set (COMPAT_HEADER_FILES include/FFTtools.h include/FFTWComplex.h include/RFSignal.h include/RFFilter.h ) 

add_library(${PROJECT_NAME} SHARED ${SOURCE_FILES})
# add_library(${compatlibname} SHARED ${COMPAT_SOURCE_FILES} ${DICTNAMECOMPAT}.cxx) 
# target_compile_definitions(${compatlibname} PUBLIC FFTTOOLS_COMPAT_MODE) 

set_target_properties(${PROJECT_NAME} PROPERTIES 
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR})

target_include_directories(${PROJECT_NAME}
  PUBLIC  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> # note: do not use quotes here, expansion leads to errors...
          $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/vectorclass>
          $<INSTALL_INTERFACE:include>
          $<INSTALL_INTERFACE:vectorclass>
  PRIVATE $<BUILD_INTERFACE:${ROOT_INCLUDE_DIRS}>
          $<BUILD_INTERFACE:${FFTW_INCLUDES}>
)

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

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

configure_package_config_file("${CMAKE_CURRENT_SOURCE_DIR}/Config.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
  INSTALL_DESTINATION "lib/cmake/${PROJECT_NAME}"
)

write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY AnyNewerVersion
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
  DESTINATION "lib/cmake/${PROJECT_NAME}"
)

install(TARGETS ${PROJECT_NAME} EXPORT ${PROJECT_NAME}Targets)

install(EXPORT ${PROJECT_NAME}Targets
    NAMESPACE RootFftwWrapper::
    FILE ${PROJECT_NAME}Targets.cmake
    DESTINATION lib/cmake/${PROJECT_NAME})

                              # note: this trailing "/" is important, otherwise install dir will have a weird "includes/includes" structure
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/ DESTINATION include)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/vectorclass DESTINATION include)
# TODO: not sure if pcm files should be installed, or how
# (https://root-forum.cern.ch/t/cmake-not-installing-pcm-and-rootmap/50997)

#================================================================================================
#                                       BINARIES
#================================================================================================

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

#================================================================================================
#                                       OPTIONS
#================================================================================================

#------------------------ END OF DECEMBER 2024 CMAKELIST UPDATES   ------------------------


### The default build configuration is INSANE. No optimization? What is this 1971? 

message (" Adding new build type") 

set(CMAKE_CXX_FLAGS_DEFAULT 
  "-Os -g -Wall" 
  CACHE STRING "c++ Flags used during default libRootFftwWrapper builds" 
  FORCE ) 

set(CMAKE_C_FLAGS_DEFAULT 
  "-Os -g -Wall"
  CACHE STRING "c Flags used during default libRootFftwWrapper builds" 
  FORCE ) 

set(CMAKE_EXE_LINKER_FLAGS_DEFAULT 
  "-g"
  CACHE STRING "ld Flags used during default libRootFftwWrapper builds" 
  FORCE ) 

set(CMAKE_SHARED_LINKER_FLAGS_DEFAULT 
  "-g"
  CACHE STRING "ld Flags used during default libRootFftwWrapper builds" 
  FORCE ) 


mark_as_advanced ( CMAKE_CXX_FLAGS_DEFAULT  CMAKE_C_FLAGS_DEFAULT CMAKE_EXE_LINKER_FLAGS_DEFAULT CMAKE_SHARED_LINKER_FLAGS_DEFAULT) 

if (NOT CMAKE_BUILD_TYPE) 
  set (CMAKE_BUILD_TYPE Default
    CACHE STRING "Choose tye type of build: None Debug Release RelWithDebInfo MinSizeRel Default"
    FORCE ) 
endif()



#################################################################################
###  Manual vectorization option 
###  Maybe in the future this can be made a CMake module or something 
################################################################################# 

option(VECTORIZE "Enable Manual SIMD Vectorization" ON) 
if (VECTORIZE) #defined in anitaBuildTool, default on
  add_definitions( -DENABLE_VECTORIZE ) 

  if(CMAKE_COMPILER_IS_GNUCXX) 

    ### someone should do this for clang if they want it to be as fast as possible 
    if (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 4.1)
      if(NATIVE_ARCH) #define in anitaBuildTool, default on
	add_definitions(-march=native)
      endif()
    endif()

    if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 5.0)
      # Vectorize docs...
      # If you are using the Gnu compiler version 3.x or 4.x then you must
      # set the ABI version to 4 or more, or 0 for a reasonable default
      add_definitions(-fabi-version=0)
    endif()
  endif() 

endif (VECTORIZE) 



##################################################################
###  Linear algebra options 
##################################################################

option(USE_EIGEN "Use Eigen3 for certain linear algebra options" OFF) 
set (EIGEN3_INCLUDE_DIR "/usr/include/eigen3" CACHE STRING "Eigen3 include path") 
option(USE_ARMADILLO "Use Armadillo for certain linear algebra options" OFF) 

if (USE_EIGEN AND USE_ARMADILLO) 

  message(FATAL_ERROR "USE_EIGEN and USE_ARMADILLO are mutually exclusive") 

elseif(USE_EIGEN) 
  add_definitions ( -DUSE_EIGEN) 
  include_directories (  ${EIGEN3_INCLUDE_DIR} ) 
elseif(USE_ARMADILLO) 

  add_definitions( -DUSE_ARMADILLO) 
  target_link_libraries(${PROJECT_NAME} armadillo) 

endif() 


###############################################################################
#### Multithread options 
################################################################################
option(FFTTOOLS_ENABLE_OPENMP "Enable OpenMP support (experimenta, mutually exclusive with FFTTOOLS_ENABLE_THREAD_SAFE) for doFft and doInvFft" OFF) 
option(FFTTOOLS_ENABLE_THREAD_SAFE "Make fft methods threadsafe (mutually exclusive with FFTTOOLS_ENABLE_OPEMP)" OFF) 

if (FFTTOOLS_ENABLE_OPENMP AND FFTTOOLS_ENABLE_THREAD_SAFE)

  message(FATAL_ERROR "FFTTOOLS_ENABLE_THREAD_SAFE and FFTTOOLS_ENABLE_OPENMP are mutually exclusive") 

elseif(FFTTOOLS_ENABLE_THREAD_SAFE) 
  add_definitions( -DFFTTOOLS_THREAD_SAFE )
elseif(FFTTOOLS_ENABLE_OPENMP) 

  FIND_PACKAGE( OpenMP REQUIRED)
  if(OPENMP_FOUND)
    message("OPENMP FOUND")
    add_definitions (-DFFTTOOLS_USE_OMP) 
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${OpenMP_EXE_LINKER_FLAGS}")

    do_binary(testOpenMP) 
  else() 
    message(FATAL_ERROR "you tried to use openmp but Cmake couldn't find compiler support") 
  endif() 
endif() 


#### api compatibility 

option ( FORCE_OLD_GPP_ABI " Force old g++ ABI; this might be necessary if using new g++ with ROOT compiled with older g++ or other similar situations" OFF ) 
if (FORCE_OLD_GPP_ABI) 
  add_definitions( -D_GLIBCXX_USE_CXX11_ABI=0 ) 
endif() 



### Let's see if this works 
macro(stupid_option option_name option_description) 
  option (${option_name} ${option_description} OFF) 
  if (${option_name}) 
    add_definitions ( -D${option_name} )
  endif()
endmacro() 



#### Random Sine Subtraction options #### 
stupid_option(SINE_SUBTRACT_USE_FLOATS  "Use floats for vectorized sine subtraction") 
mark_as_advanced(SINE_SUBTRACT_USE_FLOATS)
stupid_option(SINE_SUBTRACT_PROFILE  "Enable Sine Subtraction profiling (you probably don't want to do this)") 
mark_as_advanced(SINE_SUBTRACT_PROFILE)

#option ( SINE_SUBTRACT_USE_FLOATS "Use floats for vectorized Sine Subtraction" OFF)
#mark_as_advanced( SINE_SUBTRACT_USE_FLOATS) 
#if ( SINE_SUBTRACT_USE_FLOATS) 
#  add_definitions ( -DSINE_SUBTRACT_USE_FLOATS)
#endif()
#
#option ( SINE_SUBTRACT_PROFILE "Enable Sine Subtraction profiling (you probably don't want to do this) " OFF)
#mark_as_advanced( SINE_SUBTRACT_PROFILE) 
#if ( SINE_SUBTRACT_PROFILE) 
#  add_definitions ( -DSINE_SUBTRACT_PROFILE)
#endif()
#
#

#### Misc options  #### 

stupid_option(FFTW_USE_PATIENT  "Use FFTW Patient plans... not recommended unless you are good about saving wisdom")
mark_as_advanced(FFTW_USE_PATIENT) 

#option(USE_PATIENT_PLANS "Use FFTW_PATIENT" OFF) 
#mark_as_advanced( USE_PATIENT_PLANS) 
#
#if (USE_PATIENT_PLANS) 
#  add_definitions ( -DFFTW_USE_PATIENT ) 
#endif() 






