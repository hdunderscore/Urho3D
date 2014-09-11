# Define target name
set (TARGET_NAME OpenSSL)

# Define source files
#include_directories (include)
file (GLOB CPP_FILES src/*.cpp)
file (GLOB H_FILES include/*.h)
set (SOURCE_FILES ${CPP_FILES} ${H_FILES})

# Define include directory
set (INCLUDE_DIRS_ONLY include)

if (SSL_LIB_STATIC)
#    add_definitions (-l"${SSL_LIB_STATIC}")
    #set (ABSOLUTE_PATH_LIBS "${SSL_LIB_STATIC}")
endif ()

if (SSL_CRYPTO_LIB_STATIC)
#    add_definitions (-l"${SSL_CRYPTO_LIB_STATIC}")
    #set (ABSOLUTE_PATH_LIBS "${ABSOLUTE_PATH_LIBS} ${SSL_CRYPTO_LIB_STATIC}")
endif ()

# Setup target
#target_link_libraries (${TARGET_NAME} ${ABSOLUTE_PATH_LIBS})
