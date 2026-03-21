cmake_minimum_required(VERSION 3.22.1)
project(voicevox_bridge)

add_library(voicevox_core SHARED IMPORTED)
set_target_properties(
    voicevox_core
    PROPERTIES
    IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libvoicevox_core.so
    IMPORTED_NO_SONAME TRUE
)

add_library(
    voicevox_bridge
    SHARED
    voicevox_bridge.cpp
)

target_include_directories(
    voicevox_bridge
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

find_library(log-lib log)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

target_link_libraries(
    voicevox_bridge
    voicevox_core
    ${log-lib}
)
