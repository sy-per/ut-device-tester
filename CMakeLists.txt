cmake_minimum_required(VERSION 3.5)
project(devicetester CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_AUTOMOC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

find_package(Qt5 REQUIRED COMPONENTS Core Qml Multimedia DBus)

if(NOT CLICK_ARCH)
    execute_process(COMMAND dpkg-architecture -qDEB_HOST_ARCH
                    OUTPUT_VARIABLE CLICK_ARCH OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()
configure_file(manifest.json.in ${CMAKE_CURRENT_BINARY_DIR}/manifest.json)

# Plugin QML "DeviceBackend" (micro, batterie, scan Wi-Fi)
add_library(devicebackendplugin SHARED
    backend/backend.h backend/backend.cpp
    backend/plugin.h backend/plugin.cpp)
target_link_libraries(devicebackendplugin Qt5::Core Qt5::Qml Qt5::Multimedia Qt5::DBus)

set(QML_DEST ${CMAKE_INSTALL_PREFIX}/qml)
install(TARGETS devicebackendplugin LIBRARY DESTINATION ${QML_DEST}/DeviceBackend)
install(FILES backend/qmldir DESTINATION ${QML_DEST}/DeviceBackend)

install(DIRECTORY qml/ DESTINATION ${QML_DEST})

# Translations: po/<lang>.po -> share/locale/<lang>/LC_MESSAGES/devicetester.jimmy.mo
find_program(MSGFMT msgfmt)
file(GLOB PO_FILES ${CMAKE_SOURCE_DIR}/po/*.po)
if(MSGFMT)
    foreach(po ${PO_FILES})
        get_filename_component(lang ${po} NAME_WE)
        set(mo ${CMAKE_CURRENT_BINARY_DIR}/${lang}.mo)
        add_custom_command(OUTPUT ${mo} COMMAND ${MSGFMT} -o ${mo} ${po} DEPENDS ${po})
        add_custom_target(mo-${lang} ALL DEPENDS ${mo})
        install(FILES ${mo} DESTINATION ${CMAKE_INSTALL_PREFIX}/share/locale/${lang}/LC_MESSAGES
                RENAME devicetester.jimmy.mo)
    endforeach()
else()
    message(WARNING "msgfmt not found: translations will not be installed")
endif()
install(DIRECTORY assets DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/manifest.json
              devicetester.apparmor devicetester.desktop
        DESTINATION ${CMAKE_INSTALL_PREFIX})
