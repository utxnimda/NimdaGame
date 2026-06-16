cmake_minimum_required(VERSION 3.22)

project(nimdagame_core LANGUAGES CXX)

add_library(nimdagame_core STATIC
    src/battle/combat_simulation.cpp
)

target_include_directories(nimdagame_core
    PUBLIC
        include
)

target_compile_features(nimdagame_core PUBLIC cxx_std_20)
