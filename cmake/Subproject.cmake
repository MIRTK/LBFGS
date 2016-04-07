# ==============================================================================
# Utility CMake functions for standalone or subproject build configuration.
#
# This CMake source file is released into the public domain.
#
# Author: Andreas Schuh (andreas.schuh.84@gmail.com)
# ==============================================================================

include(CMakeParseArguments)

# ----------------------------------------------------------------------------
## Start (sub-)project
#
# This macro is for CMake versions 2.8.12 which did not have the VERSION
# argument yet. It additionally sets the PROJECT_SOVERSION to either the
# project major version number or ${PROJECT_NAME}_SOVERSION if set.
# When ${PROJECT_NAME}_IS_SUBPROJECT is not defined, PROJECT_IS_SUBPROJECT
# is set to TRUE when the source directory of this project is not the
# top-level source directory, and FALSE otherwise.
#
# Besides the PROJECT_NAME variable, this macro also sets PROJECT_NAME_LOWER
# and PROJECT_NAME_UPPER to the respective all lower- or uppercase strings.
macro (subproject name)
  cmake_parse_arguments("" "" "VERSION;SOVERSION" "LANGUAGES" ${ARGN})
  if (_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "Unrecognized arguments: ${_UNPARSED_ARGUMENTS}")
  endif ()
  if (NOT _VERSION)
    set(_VERSION 0.0.0) # invalid version number
  endif ()
  unset(PROJECT_VERSION)
  unset(PROJECT_VERSION_MAJOR)
  unset(PROJECT_VERSION_MINOR)
  unset(PROJECT_VERSION_PATCH)
  unset(${name}_VERSION)
  unset(${name}_VERSION_MAJOR)
  unset(${name}_VERSION_MINOR)
  unset(${name}_VERSION_PATCH)
  project(${name} ${_LANGUAGES})
  set(PROJECT_VERSION "${_VERSION}")
  split_version_numbers(${PROJECT_VERSION}
    PROJECT_VERSION_MAJOR
    PROJECT_VERSION_MINOR
    PROJECT_VERSION_PATCH
  )
  set(${name}_VERSION       ${PROJECT_VERSION})
  set(${name}_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
  set(${name}_VERSION_MINOR ${PROJECT_VERSION_MINOR})
  set(${name}_VERSION_PATCH ${PROJECT_VERSION_PATCH})
  if (NOT _SOVERSION)
    set(_SOVERSION ${PROJECT_VERSION_MAJOR})
  endif ()
  set_abi_version(PROJECT_SOVERSION ${_SOVERSION})
  set(${name}_SOVERSION ${PROJECT_SOVERSION})
  check_if_subproject()
  string(TOLOWER ${PROJECT_NAME} PROJECT_NAME_LOWER)
  string(TOUPPER ${PROJECT_NAME} PROJECT_NAME_UPPER)
  unset(_VERSION)
  unset(_SOVERSION)
  unset(_LANGUAGES)
  unset(_UNPARSED_ARGUMENTS)
  if (${PROJECT_NAME}_EXPORT_NAME)
    set(PROJECT_EXPORT_NAME ${${PROJECT_NAME}_EXPORT_NAME})
  else ()
    set(PROJECT_EXPORT_NAME ${PROJECT_NAME})
  endif ()
  set_property(GLOBAL PROPERTY ${PROJECT_NAME}_HAVE_EXPORT FALSE)
endmacro ()

# ----------------------------------------------------------------------------
## Convert boolean value to 0 or 1
macro (bool_to_int VAR)
  if (${VAR})
    set(${VAR} 1)
  else ()
    set(${VAR} 0)
  endif ()
endmacro ()

# ----------------------------------------------------------------------------
## Extract version numbers from version string
function (split_version_numbers version major minor patch)
  if (version MATCHES "([0-9]+)(\\.[0-9]+)?(\\.[0-9]+)?(rc[1-9][0-9]*|[a-z]+)?")
    if (CMAKE_MATCH_1)
      set(_major ${CMAKE_MATCH_1})
    else ()
      set(_major 0)
    endif ()
    if (CMAKE_MATCH_2)
      set(_minor ${CMAKE_MATCH_2})
      string (REGEX REPLACE "^\\." "" _minor "${_minor}")
    else ()
      set(_minor 0)
    endif ()
    if (CMAKE_MATCH_3)
      set(_patch ${CMAKE_MATCH_3})
      string(REGEX REPLACE "^\\." "" _patch "${_patch}")
    else ()
      set(_patch 0)
    endif ()
  else ()
    set(_major 0)
    set(_minor 0)
    set(_patch 0)
  endif ()
  set("${major}" "${_major}" PARENT_SCOPE)
  set("${minor}" "${_minor}" PARENT_SCOPE)
  set("${patch}" "${_patch}" PARENT_SCOPE)
endfunction ()

# ----------------------------------------------------------------------------
## Set ABI version number
#
# When the variable ${PROJECT_NAME}_SOVERSION is set, it overrides the ABI
# version number argument.
macro (set_abi_version varname number)
  if (${PROJECT_NAME}_SOVERSION)
    set(${varname} "${${PROJECT_NAME}_SOVERSION}")
  else ()
    set(${varname} "${number}")
  endif ()
endmacro ()

# ----------------------------------------------------------------------------
## Determine if project is build as subproject
#
# When included as subproject (e.g., as Git submodule/subtree) in the source
# tree of a project that uses it, no variables should be added to the CMake cache;
# users may set the (non-cached) variable ${PROJECT_NAME}_IS_SUBPROJECT before
# the add_subdirectory command that adds this subdirectory to the build.
#
# @returns Sets PROJECT_IS_SUBPROJECT to either TRUE or FALSE.
macro (check_if_subproject)
  if (DEFINED ${PROJECT_NAME}_IS_SUBPROJECT)
    set(PROJECT_IS_SUBPROJECT ${PROJECT_NAME}_IS_SUBPROJECT)
  elseif ("^${CMAKE_SOURCE_DIR}$" STREQUAL "^${PROJECT_SOURCE_DIR}$")
    set(PROJECT_IS_SUBPROJECT FALSE)
  else ()
    set(PROJECT_IS_SUBPROJECT TRUE)
  endif ()
endmacro ()

# ----------------------------------------------------------------------------
## Determine if cache entry exists
macro (check_if_cached retvar varname)
  if (DEFINED ${varname})
    get_property(${retvar} CACHE ${varname} PROPERTY TYPE SET)
  else ()
    set(${retvar} FALSE)
  endif ()
endmacro ()

# ----------------------------------------------------------------------------
## Add configuration variable
#
# The default value of the (cached) configuration value can be overridden
# either on the CMake command-line or the super-project by setting the
# ${PROJECT_NAME}_${varname} variable. When this project is a subproject
# of another project, i.e., PROJECT_IS_SUBPROJECT is TRUE, the variable
# is not added to the CMake cache and set to the value of
# ${PROJECT_NAME}_${varname} regardless if the parent project defines
# a (cached) variable of the same name. Otherwise, when this project is
# a standalone project, the variable is cached.
macro (define type varname docstring default)
  if (ARGC GREATER 5)
    message (FATAL_ERROR "Too many macro arguments")
  endif ()
  if (NOT PROJECT_NAME)
    message (FATAL_ERROR "project() command must be called before to set PROJECT_NAME")
  endif ()
  if (NOT DEFINED ${PROJECT_NAME}_${varname})
    if (PROJECT_IS_SUBPROJECT AND ARGC EQUAL 5)
      set(${PROJECT_NAME}_${varname} "${ARGV4}")
    else ()
      set(${PROJECT_NAME}_${varname} "${default}")
    endif ()
  endif ()
  if (PROJECT_IS_SUBPROJECT)
    set(${varname} "${${PROJECT_NAME}_${varname}}")
  else ()
    set(${varname} "${${PROJECT_NAME}_${varname}}" CACHE ${type} "${docstring}")
  endif ()
endmacro ()

# ----------------------------------------------------------------------------
## Set property of cached configuration variable
#
# This command does nothing when the previously defined variable was not added
# to the CMake cache because this project is build as subproject.
#
# @see define
macro (set_cache_property varname property value)
  check_if_cached(_is_cached ${varname})
  if (_is_cached)
    if (property STREQUAL ADVANCED)
      if (${value})
        mark_as_advanced(FORCE ${varname})
      else ()
        mark_as_advanced(CLEAR ${varname})
      endif ()
    else ()
      set_property(CACHE ${varname} PROPERTY "${property}" "${value}")
    endif ()
  endif ()
  unset(_is_cached)
endmacro ()

# ----------------------------------------------------------------------------
## Modify value of defined configuration variable
macro (set_value varname value)
  check_if_cached (_is_cached ${varname})
  if (_is_cached)
    set_property(CACHE ${varname} PROPERTY VALUE "${value}")
  else ()
    set(${varname} "${value}")
  endif ()
  unset(_is_cached)
endmacro ()

# ----------------------------------------------------------------------------
## Install library
function (install_library target)
  # parse arguments
  if (NOT TARGET ${target})
    message(FATAL_ERROR "Unknown target: ${target}")
  endif ()
  get_target_property(type ${target} TYPE)
  if (NOT PROJECT_IS_SUBPROJECT OR
      NOT "^${type}$" STREQUAL "^STATIC_LIBRARY$" OR
      ${PROJECT_NAME}_INSTALL_STATIC_LIBS)
    cmake_parse_arguments(""
      ""
      "INCLUDE_DESTINATION;LIBRARY_DESTINATION;RUNTIME_DESTINATION"
      "PUBLIC_HEADER_FILES"
      ${ARGN}
    )
    if (_UNPARSED_ARGUMENTS)
      message(FATAL_ERROR "Too many or unrecognized arguments: ${_UNPARSED_ARGUMENTS}")
    endif ()
    # override (default) arguments
    if (${PROJECT_NAME}_INSTALL_RUNTIME_DIR)
      set(_RUNTIME_DESTINATION "${${PROJECT_NAME}_INSTALL_RUNTIME_DIR}")
    elseif (NOT _RUNTIME_DESTINATION)
      set(_RUNTIME_DESTINATION bin)
    endif ()
    if (${PROJECT_NAME}_INSTALL_INCLUDE_DIR)
      set(_INCLUDE_DESTINATION "${${PROJECT_NAME}_INSTALL_INCLUDE_DIR}")
    elseif (NOT _INCLUDE_DESTINATION)
      set(_INCLUDE_DESTINATION include)
    endif ()
    if (${PROJECT_NAME}_INSTALL_LIBRARY_DIR)
      set(_LIBRARY_DESTINATION "${${PROJECT_NAME}_INSTALL_LIBRARY_DIR}")
    elseif (NOT _LIBRARY_DESTINATION)
      set(_LIBRARY_DESTINATION lib)
    endif ()
    # skip installation of static subproject library
    if (_PUBLIC_HEADER_FILES)
      install(FILES ${_PUBLIC_HEADER_FILES} DESTINATION ${_INCLUDE_DESTINATION} COMPONENT Development)
      target_include_directories(${target} INTERFACE "$<INSTALL_INTERFACE:${_INCLUDE_DESTINATION}>")
    endif ()
    install(TARGETS ${target} EXPORT ${PROJECT_EXPORT_NAME}
      RUNTIME DESTINATION ${_RUNTIME_DESTINATION} COMPONENT RuntimeLibraries
      LIBRARY DESTINATION ${_LIBRARY_DESTINATION} COMPONENT RuntimeLibraries
      ARCHIVE DESTINATION ${_LIBRARY_DESTINATION} COMPONENT Development
    )
    set_property(GLOBAL PROPERTY ${PROJECT_NAME}_HAVE_EXPORT TRUE)
  endif ()
endfunction ()

# ----------------------------------------------------------------------------
## Install package configuration files
function (install_package_config_files)
  if (NOT PROJECT_IS_SUBPROJECT OR NOT DEFINED ${PROJECT_NAME}_INSTALL_CONFIG OR ${PROJECT_NAME}_INSTALL_CONFIG)
    # parse arguments
    cmake_parse_arguments("" "" "DESTINATION" "FILES" ${ARGN})
    if (_UNPARSED_ARGUMENTS)
      message(FATAL_ERROR "Unrecognized arguments: ${_UNPARSED_ARGUMENTS}")
    endif ()
    # override (default) arguments
    if (${PROJECT_NAME}_INSTALL_CONFIG_DIR)
      set(_DESTINATION "${${PROJECT_NAME}_INSTALL_CONFIG_DIR}")
    elseif (NOT _DESTINATION)
      set(_DESTINATION "lib/cmake/${PROJECT_NAME_LOWER}")
    endif ()
    # install package configuration files if not overriden
    install(FILES ${_FILES} DESTINATION ${_DESTINATION} COMPONENT Development)
  endif ()
endfunction ()

# ----------------------------------------------------------------------------
## Install exported targets configuration files
function (install_exports)
  if (NOT PROJECT_IS_SUBPROJECT OR NOT DEFINED ${PROJECT_NAME}_INSTALL_CONFIG OR ${PROJECT_NAME}_INSTALL_CONFIG)
    cmake_parse_arguments("" "" "DESTINATION;NAMESPACE" "" ${ARGN})
    if (_UNPARSED_ARGUMENTS)
      message(FATAL_ERROR "Unrecognized arguments: ${_UNPARSED_ARGUMENTS}")
    endif ()
    # override (default) arguments
    if (${PROJECT_NAME}_INSTALL_CONFIG_DIR)
      set(_DESTINATION "${${PROJECT_NAME}_INSTALL_CONFIG_DIR}")
    elseif (NOT _DESTINATION)
      set(_DESTINATION "lib/cmake/${PROJECT_NAME_LOWER}")
    endif ()
    # install export sets
    get_property(have_export GLOBAL PROPERTY ${PROJECT_NAME}_HAVE_EXPORT)
    if (have_export)
      install(EXPORT ${PROJECT_EXPORT_NAME}
        NAMESPACE   "${_NAMESPACE}"
        DESTINATION "${_DESTINATION}"
        FILE        "${PROJECT_NAME}Targets.cmake"
        COMPONENT   Development
      )
    endif ()
  endif ()
endfunction ()
