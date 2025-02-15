﻿cmake_minimum_required(VERSION 3.10)

#foreach(LIB_NAME IN ITEMS ${LIB_NAMES})
macro(build_library LIB_NAME LIB_DEPENDENCY)
    set(LIB_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/${LIB_NAME}")

    file(                                                                           
        GLOB_RECURSE LIB_SRC
        LIST_DIRECTORIES false
        CONFIGURE_DEPENDS
        "${LIB_SRC_DIR}/*.c*"
        "${LIB_SRC_DIR}/*.h*"
    )

    if(WIN32)
        add_library(${LIB_NAME} SHARED ${LIB_SRC})
    elseif(UNIX)
        add_library(${LIB_NAME} SHARED ${LIB_SRC}) 
    endif()

    foreach(SRC IN ITEMS ${LIB_SRC}) 
        get_filename_component(SRC_PATH "${SRC}" PATH)
        file(RELATIVE_PATH SRC_PATH_REL "${LIB_SRC_DIR}" "${SRC_PATH}")
        string(REPLACE "/" "\\" GROUP_PATH "${SRC_PATH_REL}")
        source_group("${GROUP_PATH}" FILES "${SRC}")
    endforeach()

    if(WIN32)
        target_compile_options(${LIB_NAME} PRIVATE -Xcompiler "/wd 4819") 
    endif()
    file(RELATIVE_PATH PROJECT_PATH_REL "${PROJECT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}")
    set_target_properties(${LIB_NAME} PROPERTIES FOLDER "Engine/Plugin")
    set_target_properties(${LIB_NAME} PROPERTIES CUDA_RESOLVE_DEVICE_SYMBOLS ON)
    set_target_properties(${LIB_NAME} PROPERTIES CUDA_ARCHITECTURES ${CUDA_ARCH_FLAGS})
    set_target_properties(${LIB_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/plugin)
    

    set_target_properties(${LIB_NAME} PROPERTIES
        OUTPUT_NAME "dyno${LIB_NAME}-${PERIDYNO_LIBRARY_VERSION}")
    set_target_properties(${LIB_NAME} PROPERTIES
        CUDA_SEPARABLE_COMPILATION OFF)

    add_compile_definitions(PERIDYNO_API_EXPORTS)

    target_include_directories(${LIB_NAME} PUBLIC 
        $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/src>
        $<INSTALL_INTERFACE:${PERIDYNO_INC_INSTALL_DIR}>)

    #To disable the warning "calling a constexpr __host__ function("***") from a __host__ __device__ function("***") is not allowed."
    target_compile_options(${LIB_NAME} PRIVATE $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr;--expt-extended-lambda>)

    target_link_libraries(${LIB_NAME} PUBLIC ${${LIB_DEPENDENCY}})

    # install(TARGETS ${LIB_NAME}
    #     EXPORT ${LIB_NAME}Targets
    #     RUNTIME  DESTINATION  ${PERIDYNO_RUNTIME_INSTALL_DIR}
    #     LIBRARY  DESTINATION  ${PERIDYNO_LIBRARY_INSTALL_DIR}
    #     ARCHIVE  DESTINATION  ${PERIDYNO_ARCHIVE_INSTALL_DIR}
    #     )

    # install(EXPORT ${LIB_NAME}Targets DESTINATION ${PERIDYNO_CMAKE_CONFIG_INSTALL_DIR}
    #     FILE ${LIB_NAME}Targets.cmake)

    # #Append ${LIB_NAME}Targets.cmake to the global list, which will be include in PeridynoConfig.cmake
    # get_property(LOCAL_CMAKES_NAMES GLOBAL PROPERTY "GLOBAL_CMAKES_NAMES")
    # list(APPEND LOCAL_CMAKES_NAMES "${LIB_NAME}Targets.cmake")    
    # set_property(GLOBAL PROPERTY GLOBAL_CMAKES_NAMES ${LOCAL_CMAKES_NAMES})

    # file(GLOB FILE_DYNAMICS_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/${LIB_NAME}/*.h")
    # install(FILES ${FILE_DYNAMICS_HEADER}  DESTINATION ${PERIDYNO_INC_INSTALL_DIR}/Plugin/${LIB_NAME})
endmacro()
       
if(PERIDYNO_LIBRARY_ALEMBIC)
    set(LIB_DEPENDENCY Core Framework Topology Alembic)
    build_library(ABCExporter LIB_DEPENDENCY)
endif()

if(PERIDYNO_LIBRARY_GMSH)
    if(WIN32)
        set(LIB_DEPENDENCY Core Framework GmshLib Topology winmm wsock32 ws2_32 psapi)
    elseif(UNIX)
        set(LIB_DEPENDENCY Core Framework GmshLib Topology)
    endif()

    include_directories("${CMAKE_SOURCE_DIR}/external/gmsh-fork/api")

    build_library(GmshIO LIB_DEPENDENCY)
endif()

if(PERIDYNO_LIBRARY_FBX)
    set(LIB_DEPENDENCY Core Framework Topology)
    build_library(SkeletonLoader LIB_DEPENDENCY)
endif()
