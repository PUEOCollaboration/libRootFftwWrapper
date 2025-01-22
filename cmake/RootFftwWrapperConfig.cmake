include("${CMAKE_CURRENT_LIST_DIR}/RootFftwWrapperTargets.cmake")

include(CMakeFindDependencyMacro)
# find_dependency(FFTW REQUIRED) # TODO CONFIG MODE???
find_dependency(ROOT CONFIG REQUIRED COMPONENTS FitPanel MathMore Spectrum Minuit Minuit2)
find_dependency(Threads REQUIRED)

# TODO Handle find_dependency(...) for optionally included packages
