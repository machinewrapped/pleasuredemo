# Minimum CMake version required
cmake_minimum_required(VERSION 3.16)

# Project name and version
project(AtariSTScreens)

# Set the assembler (vasmm68k_mot) and flags
set(VASM_EXEC vasmm68k_mot)
set(VASM_FLAGS -nosym -Ftos -align -noesc -no-opt -nowarn=51 -nowarn=58 -maxerrors=50)

# Output directories
set(OUT_DIR ${CMAKE_BINARY_DIR}/MAKE)
set(AUTO_DIR ${OUT_DIR}/AUTO)

# Create output directories
file(MAKE_DIRECTORY ${OUT_DIR})
file(MAKE_DIRECTORY ${AUTO_DIR})

# Define source files
set(SRC
    SHELL/NEWSHEL.S
    SHELL/DEBUGSHL.S
    INTRO/INTRO.S
    MENU/MENU24.S
    3DFORMAT/3DFORMAT.S
    CLASGLAS/CLASGLAS.S
    HELIX/HELIX.S
    LOVE/LOVEDEMO.S
    REPTHOUS/REPTHOUS.S
    REFLEXON/REFLEXON.S
    SOULPSYC/SOULPSYC.S
    SUMMER/SUMMER.S
    ULTRAMEG.A/NEWUMS.S
)

# Add a custom command for each source file
foreach(SRC_FILE ${SRC})
    get_filename_component(FILE_NAME ${SRC_FILE} NAME_WE)
    add_custom_command(
        OUTPUT ${OUT_DIR}/${FILE_NAME}.TOS
        COMMAND ${VASM_EXEC} ${VASM_FLAGS} -o ${OUT_DIR}/${FILE_NAME}.TOS ${CMAKE_SOURCE_DIR}/${SRC_FILE}
        DEPENDS ${SRC_FILE}
        COMMENT "Assembling ${SRC_FILE} to ${OUT_DIR}/${FILE_NAME}.TOS"
        VERBATIM
    )
    add_custom_target(${FILE_NAME}_build ALL DEPENDS ${OUT_DIR}/${FILE_NAME}.TOS)
endforeach()

# Special rule for NEWSHEL.PRG in AUTO subfolder
add_custom_command(
    OUTPUT ${AUTO_DIR}/NEWSHEL.PRG
    COMMAND ${CMAKE_COMMAND} -E copy ${OUT_DIR}/NEWSHEL.TOS ${AUTO_DIR}/NEWSHEL.PRG
    DEPENDS ${OUT_DIR}/NEWSHEL.TOS
    COMMENT "Copying NEWSHEL.TOS to AUTO/NEWSHEL.PRG"
    VERBATIM
)
add_custom_target(newshel_prg ALL DEPENDS ${AUTO_DIR}/NEWSHEL.PRG)

# Copy readme.txt to the output directory
add_custom_command(
    OUTPUT ${OUT_DIR}/readme.txt
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/readme.txt ${OUT_DIR}/readme.txt
    DEPENDS ${CMAKE_SOURCE_DIR}/readme.txt
    COMMENT "Copying readme.txt to ${OUT_DIR}"
    VERBATIM
)
add_custom_target(copy_readme ALL DEPENDS ${OUT_DIR}/readme.txt)

# Clean up target
add_custom_target(cleantos
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${OUT_DIR}
    COMMENT "Cleaning up build files"
)
