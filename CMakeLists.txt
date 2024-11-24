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

# TODO this should actually be optional
find_package(verilator REQUIRED)

# Flags for verilating
set(VERILATOR_FLAGS "-Wall" "-Wno-EOFNEWLINE" "-Wno-UNUSEDSIGNAL")

# This function adds a Verilator testbench target to the project
#   target_name: Name of the CMake target to generate
#   rtl_src: Source to the RTL module
#   cpp_src: Source to the C++ testbench file
#   top_module: Name of the module to verilate, i.e. the DUT
function(add_testbench target_name rtl_src cpp_src top_module)
    message(STATUS "Adding testbench target ${target_name}, rtl_src: ${rtl_src}, cpp_src: ${cpp_src}, \
top_module: ${top_module}")
    add_executable(${target_name} ${cpp_src})
    verilate(${target_name}
        SOURCES ${rtl_src}
        TRACE_FST
        COVERAGE
        VERILATOR_ARGS ${VERILATOR_ARGS}
        INCLUDE_DIRS "${CMAKE_SOURCE_DIR}/rtl"
        TOP_MODULE ${top_module}
        VERILATOR_ARGS "--timing" "--public-flat-rw" "--prof-cfuncs"
    )
    # Debug flags
    target_compile_options(${target_name} PRIVATE ${TESTBENCH_CXX_FLAGS} "-fsanitize=address")
    target_link_options(${target_name} PRIVATE "-flto" "-fsanitize=address")
    target_compile_definitions(${target_name} PRIVATE "VL_DEBUG")

    # Release flags
    # target_compile_options(${target_name} PRIVATE ${TESTBENCH_CXX_FLAGS} "-O3" "-march=native" "-mtune=native")
    # target_link_options(${target_name} PRIVATE "-flto")
endfunction()

add_library(tamara SHARED
    src/tamara_tmr_pass.cpp
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

# Add cxxrtl tests
add_executable(not_dff_tmr_cxxrtl
    tests/cxxrtl/not_dff_tmr_cxxrtl.cpp
)
target_include_directories(not_dff_tmr_cxxrtl PRIVATE tests/cxxrtl)

# Add verilator tests
add_testbench(not_dff_tmr_verilator
    tests/debugging/not_dff_tmr_tb.v
    tests/debugging/not_dff_tmr_verilator.cpp
    not_dff_tmr
)

message(STATUS "Checking if LLD is available")
execute_process(COMMAND "lld" ERROR_VARIABLE LLD_RESULT)

if (LLD_RESULT MATCHES "lld is a generic driver")
    message(STATUS "LLD is available, it will be used")
    target_link_options(tamara PRIVATE "-fuse-ld=lld")
    target_link_options(not_dff_tmr_cxxrtl PRIVATE "-fuse-ld=lld")
else()
    message(STATUS "LLD is NOT available, so we'll use the system default linker")
endif()
