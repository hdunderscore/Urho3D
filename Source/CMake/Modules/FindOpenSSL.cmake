
#
# Copyright (c) 2008-2014 the Urho3D project.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

if (NOT SSL_FOUND)
    if (CMAKE_CL_64)
        if (WIN32)
            if (MINGW)
                set (SSL_LIB_SEARCH_PATH
                    "$ENV{OPENSSL_ROOT_DIR}"
                    "$ENV{OPENSSL_ROOT_DIR}/lib/MinGW")
                find_path (SSL_LIB_STATIC libssl.a ${SSL_LIB_SEARCH_PATH})
            else ()
                set (SSL_LIB_SEARCH_PATH
                    "$ENV{OPENSSL_ROOT_DIR}"
                    "$ENV{OPENSSL_ROOT_DIR}/lib")
                find_path (SSL_LIB_STATIC libssl.lib ${SSL_LIB_SEARCH_PATH})
            endif ()
        else ()
            set (SSL_LIB_SEARCH_PATH
                "$ENV{OPENSSL_ROOT_DIR}"
                "$ENV{OPENSSL_ROOT_DIR}/lib")
            find_path (SSL_LIB_STATIC libssl.a ${SSL_LIB_SEARCH_PATH})
        endif ()
    else ()
        if (WIN32)
            if (MINGW)
                set (SSL_LIB_SEARCH_PATH
                    "$ENV{OPENSSL_ROOT_DIR}"
                    "$ENV{OPENSSL_ROOT_DIR}/lib/MinGW")
                find_file (SSL_LIB_STATIC libssl.a ${SSL_LIB_SEARCH_PATH})
            else ()
                set (SSL_LIB_SEARCH_PATH
                    "$ENV{OPENSSL_ROOT_DIR}"
                    "$ENV{OPENSSL_ROOT_DIR}/lib")
                find_file (SSL_LIB_STATIC libssl.lib ${SSL_LIB_SEARCH_PATH})
            endif ()
        else ()
            set (SSL_LIB_SEARCH_PATH
                "$ENV{OPENSSL_ROOT_DIR}"
                "$ENV{OPENSSL_ROOT_DIR}/lib")
            find_path (SSL_LIB_STATIC libssl.a ${SSL_LIB_SEARCH_PATH})
        endif ()
    endif ()

    if (SSL_LIB_STATIC)
        set (SSL_FOUND 1)
    endif ()

    if (SSL_FOUND)
        include (FindPackageMessage)
        FIND_PACKAGE_MESSAGE (SSL "Found SSL static lib: ${SSL_LIB_STATIC}" "[${SSL_LIB_STATIC}]")
    else ()
        message (STATUS "SSL static lib not found. ${SSL_LIB_STATIC}")
    endif ()
endif ()

if (NOT SSL_CRYPTO_FOUND)
    if (CMAKE_CL_64)
        if (WIN32)
            if (MINGW)
                set (SSL_CRYPTO_LIB_SEARCH_PATH
                    "$ENV{OPENSSL_ROOT_DIR}"
                    "$ENV{OPENSSL_ROOT_DIR}/lib/MinGW")
                find_path (SSL_CRYPTO_LIB_STATIC libcrypto.a ${SSL_CRYPTO_LIB_SEARCH_PATH})
            else ()
                set (SSL_CRYPTO_LIB_SEARCH_PATH
                    "$ENV{OPENSSL_ROOT_DIR}"
                    "$ENV{OPENSSL_ROOT_DIR}/lib")
                find_path (SSL_CRYPTO_LIB_STATIC libcrypto.lib ${SSL_CRYPTO_LIB_SEARCH_PATH})
            endif ()
        else ()
            set (SSL_CRYPTO_LIB_SEARCH_PATH
                "$ENV{OPENSSL_ROOT_DIR}"
                "$ENV{OPENSSL_ROOT_DIR}/lib")
            find_path (SSL_CRYPTO_LIB_STATIC libcrypto.a ${SSL_CRYPTO_LIB_SEARCH_PATH})
        endif ()
    else ()
        if (WIN32)
            if (MINGW)
                set (SSL_CRYPTO_LIB_SEARCH_PATH
                    "$ENV{OPENSSL_ROOT_DIR}"
                    "$ENV{OPENSSL_ROOT_DIR}/lib/MinGW")
                find_file (SSL_CRYPTO_LIB_STATIC libcrypto.a ${SSL_CRYPTO_LIB_SEARCH_PATH})
            else ()
                set (SSL_CRYPTO_LIB_SEARCH_PATH
                    "$ENV{OPENSSL_ROOT_DIR}"
                    "$ENV{OPENSSL_ROOT_DIR}/lib")
                find_file (SSL_CRYPTO_LIB_STATIC libcrypto.lib ${SSL_CRYPTO_LIB_SEARCH_PATH})
            endif ()
        else ()
            set (SSL_CRYPTO_LIB_SEARCH_PATH
                "$ENV{OPENSSL_ROOT_DIR}"
                "$ENV{OPENSSL_ROOT_DIR}/lib")
            find_path (SSL_CRYPTO_LIB_STATIC libcrypto.a ${SSL_CRYPTO_LIB_SEARCH_PATH})
        endif ()
    endif ()

    if (SSL_CRYPTO_LIB_STATIC)
        set (SSL_CRYPTO_FOUND 1)
    endif ()

    if (SSL_CRYPTO_FOUND)
        include (FindPackageMessage)
        FIND_PACKAGE_MESSAGE (SSL_CRYPTO "Found SSL Crypto static lib: ${SSL_CRYPTO_LIB_STATIC}" "[${SSL_CRYPTO_LIB_STATIC}]")
    else ()
        message (STATUS "SSL static lib not found. ${SSL_CRYPTO_LIB_STATIC}")
    endif ()
endif ()
