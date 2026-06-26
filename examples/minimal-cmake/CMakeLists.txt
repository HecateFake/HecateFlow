cmake_minimum_required(VERSION 3.20)
project(hecateflow_minimal C)

add_executable(demo_firmware
    firmware/code/app/main.c
)

target_include_directories(demo_firmware PRIVATE
    firmware/code
    firmware/code/config
)
