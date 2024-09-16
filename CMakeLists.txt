cmake_minimum_required(VERSION 3.20)
project(tamara
    LANGUAGES C CXX
    VERSION 1.0.0
    DESCRIPTION "Automated triple modular redundancy pass for Yosys"
    HOMEPAGE_URL "https://github.com/mattyoung101/tamara"
)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_C_STANDARD 11) # C11
set(CMAKE_CXX_STANDARD 20) # C++20
include(GNUInstallDirs)

add_library(tamara SHARED
    src/tamara_tmr_pass.cpp
    src/tamara_propagate_pass.cpp
    src/tamara_debug.cpp
    src/voter_builder.cpp
    src/logic_graph.cpp
)
target_include_directories(tamara PRIVATE include lib/yosys)
target_compile_options(tamara PRIVATE "-Wall" "-Wextra" "-Wno-unused-parameter" "-ggdb"
                                      "-fdiagnostics-color=always")
# note on diagnostic colour: https://stackoverflow.com/a/73349744/5007892

# these based on `yosys-config` on Arch
target_compile_definitions(tamara PRIVATE -DYOSYS_ENABLE_READLINE -DYOSYS_ENABLE_PLUGINS
    -DYOSYS_ENABLE_GLOB -DYOSYS_ENABLE_ZLIB -DYOSYS_ENABLE_TCL -DYOSYS_ENABLE_ABC -DYOSYS_ENABLE_COVER
    -D_YOSYS_)

# We only have a shared object as an artefact, so we can just do this
# The rest come from GNUInstallDirs
# Source: https://decovar.dev/blog/2021/03/08/cmake-cpp-library/#install-instructions
install(TARGETS tamara)
# TODO install plugin for Yosys

message(STATUS "Checking if LLD is available")
execute_process(COMMAND "lld" ERROR_VARIABLE LLD_RESULT)

if (LLD_RESULT MATCHES "lld is a generic driver")
    message(STATUS "LLD is available, it will be used")
    target_link_options(tamara PRIVATE "-fuse-ld=lld")
else()
    message(STATUS "LLD is NOT available, so we'll use the system default linker")
endif()
