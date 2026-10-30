cmake_minimum_required(VERSION 3.10)

project(hello LANGUAGES C)

add_executable(hello hello.c)

install(TARGETS hello RUNTIME DESTINATION bin)
