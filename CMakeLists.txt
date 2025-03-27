cmake_minimum_required(VERSION 3.23)
project(RootFftwWrapper VERSION 3.0.1)

option(NEW_CMAKELISTS "Use the new CMakeLists.txt" OFF)
if(NEW_CMAKELISTS)
  include("cmake/NewCMakeLists.cmake")
else()
  include("cmake/OldCMakeLists.cmake")
endif()
