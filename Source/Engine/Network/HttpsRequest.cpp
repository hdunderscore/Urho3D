//
// Copyright (c) 2008-2014 the Urho3D project.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "Precompiled.h"
#include "HttpsRequest.h"
#include "Log.h"
#include "Profiler.h"
#include "Timer.h"
#include "File.h"
#include "Ptr.h"
#include "ResourceCache.h"

#include <openssl/bio.h>
#include <openssl/ssl.h>
#include <openssl/err.h>

#include "DebugNew.h"

namespace Urho3D
{

static const unsigned ERROR_BUFFER_SIZE = 256;
static const unsigned READ_BUFFER_SIZE = 65536; // Must be a power of two

HttpsRequest::HttpsRequest(const String& url, const String& verb, const Vector<String>& headers, const String& postData) :
    url_(url.Trimmed()),
    verb_(!verb.Empty() ? verb : "GET"),
    headers_(headers),
    postData_(postData),
    state_(HTTP_INITIALIZING),
    httpReadBuffer_(new unsigned char[READ_BUFFER_SIZE]),
    readBuffer_(new unsigned char[READ_BUFFER_SIZE]),
    readPosition_(0),
    writePosition_(0),
    storeType_(HTTPS_CRED_NONE)
{
    // Size of response is unknown, so just set maximum value. The position will also be changed
    // to maximum value once the request is done, signaling end for Deserializer::IsEof().
    size_ = M_MAX_UNSIGNED;

    LOGDEBUG("HTTP " + verb_ + " request to URL " + url_);

    // Start the worker thread to actually create the connection and read the response data.
    Run();
}

HttpsRequest::HttpsRequest(const SharedPtr<File>& storeResourceFile, const String& url, const String& verb, const Vector<String>& headers, const String& postData) :
    url_(url.Trimmed()),
    verb_(!verb.Empty() ? verb : "GET"),
    headers_(headers),
    postData_(postData),
    state_(HTTP_INITIALIZING),
    httpReadBuffer_(new unsigned char[READ_BUFFER_SIZE]),
    readBuffer_(new unsigned char[READ_BUFFER_SIZE]),
    readPosition_(0),
    writePosition_(0),
    storeType_(HTTPS_CRED_RESOURCE)
{
    // Size of response is unknown, so just set maximum value. The position will also be changed
    // to maximum value once the request is done, signaling end for Deserializer::IsEof().
    size_ = M_MAX_UNSIGNED;

    if (storeResourceFile.Null())
    {
        LOGDEBUG("Error loading SSL Credentials");
        state_ = HTTP_ERROR;
        error_ = "Error loading SSL Credentials";
        return;
    }

    String s = storeResourceFile->ReadString();
    size_t len = s.Length() + 1;
    storeData_ = new char[len];
    strcpy(storeData_.Get(), s.CString());

    LOGDEBUG("HTTP " + verb_ + " request to URL " + url_);
    //LOGDEBUG(storeData_.Get());

    // Start the worker thread to actually create the connection and read the response data.
    Run();
}

HttpsRequest::HttpsRequest(const char* storeFilePath, const String& url, const String& verb, const Vector<String>& headers, const String& postData) :
    url_(url.Trimmed()),
    verb_(!verb.Empty() ? verb : "GET"),
    headers_(headers),
    postData_(postData),
    state_(HTTP_INITIALIZING),
    httpReadBuffer_(new unsigned char[READ_BUFFER_SIZE]),
    readBuffer_(new unsigned char[READ_BUFFER_SIZE]),
    readPosition_(0),
    writePosition_(0),
    storeType_(HTTPS_CRED_FILEPATH)
{
    // Size of response is unknown, so just set maximum value. The position will also be changed
    // to maximum value once the request is done, signaling end for Deserializer::IsEof().
    size_ = M_MAX_UNSIGNED;

    size_t len = strlen(storeFilePath) + 1;
    storeData_ = new char[len];
    strcpy(storeData_.Get(), storeFilePath);

    LOGDEBUG("HTTP " + verb_ + " request to URL " + url_);
    //LOGDEBUG(storeData_.Get());

    // Start the worker thread to actually create the connection and read the response data.
    Run();
}

HttpsRequest::HttpsRequest(const String& storeData, const String& url, const String& verb, const Vector<String>& headers, const String& postData) :
    url_(url.Trimmed()),
    verb_(!verb.Empty() ? verb : "GET"),
    headers_(headers),
    postData_(postData),
    state_(HTTP_INITIALIZING),
    httpReadBuffer_(new unsigned char[READ_BUFFER_SIZE]),
    readBuffer_(new unsigned char[READ_BUFFER_SIZE]),
    readPosition_(0),
    writePosition_(0),
    storeType_(HTTPS_CRED_DATA)
{
    // Size of response is unknown, so just set maximum value. The position will also be changed
    // to maximum value once the request is done, signaling end for Deserializer::IsEof().
    size_ = M_MAX_UNSIGNED;

    size_t len = storeData.Length() + 1;
    storeData_ = new char[len];
    strcpy(storeData_.Get(), storeData.CString());

    LOGDEBUG("HTTP " + verb_ + " request to URL " + url_);
    //LOGDEBUG(storeData_.Get());

    // Start the worker thread to actually create the connection and read the response data.
    Run();
}

HttpsRequest::~HttpsRequest()
{
    Stop();
}

void HttpsRequest::ThreadFunction()
{
    String protocol = "http";
    String host;
    String path = "/";
    int port = 80;

    unsigned protocolEnd = url_.Find("://");
    if (protocolEnd != String::NPOS)
    {
        protocol = url_.Substring(0, protocolEnd);
        host = url_.Substring(protocolEnd + 3);
    }
    else
        host = url_;

    unsigned pathStart = host.Find('/');
    if (pathStart != String::NPOS)
    {
        path = host.Substring(pathStart);
        host = host.Substring(0, pathStart);
    }

    unsigned portStart = host.Find(':');
    if (portStart != String::NPOS)
    {
        port = ToInt(host.Substring(portStart + 1));
        host = host.Substring(0, portStart);
    }

    char errorBuffer[ERROR_BUFFER_SIZE];
    memset(errorBuffer, 0, sizeof(errorBuffer));

    if (!postData_.Empty())
    {
        headers_ += "Content-length: " + String(postData_.Length() + 2);
        postData_ += "\r\n";
    }

    String headersStr;
    for (unsigned i = 0; i < headers_.Size(); ++i)
    {
        // Trim and only add non-empty header strings
        String header = headers_[i].Trimmed();
        if (header.Length())
            headersStr += header + "\r\n";
    }

    String request = "";
    request = ToString("%s %s HTTP/1.0\r\n"
                       "Host: %s\r\n"
                       "%s"
                       "\r\n"
                       "%s",
                       verb_.CString(),
                       path.CString(),
                       host.CString(),
                       headersStr.CString(),
                       postData_.CString());

    String host_port = host + ":" + String(port);

    BIO* bio = NULL;
    SSL* ssl = NULL;
    SSL_CTX* ctx = NULL;
    if (protocol.Compare("http", false))
    {
        // SSL Context
        SSL_CTX* ctx = SSL_CTX_new(SSLv23_client_method());

        if (storeType_ != HTTPS_CRED_NONE)
        {
            int result = 0;
            if (storeType_ == HTTPS_CRED_FILEPATH)
            {
                //ResourceCache* cache = GetContext()->GetSubsystem<ResourceCache>();

                //if (!cache->Exists(storeData_.Get()))//does path point to a directory?
                //    result = SSL_CTX_load_verify_locations(ctx, NULL, cache->GetResourceDirName(storePath_);
                //else
                    result = SSL_CTX_load_verify_locations(ctx, storeData_.Get(), NULL);
            }
            else if (storeType_ == HTTPS_CRED_DATA || storeType_ == HTTPS_CRED_RESOURCE)
            {
                X509 *cert;
                BIO *mem;

                mem = BIO_new(BIO_s_mem());
                BIO_puts(mem, storeData_.Get());

                result = 1;
                int count = 0;
                while (cert = PEM_read_bio_X509(mem, NULL, 0, NULL))
                { // Load multiple certs
                    count ++;
                    result *= X509_STORE_add_cert(SSL_CTX_get_cert_store(ctx), cert);
                }
                result *= count;

                BIO_free(mem);
            }

            if (result == 0)
            {
                MutexLock lock(mutex_);
                LOGDEBUG("Error loading SSL credentials");
                state_ = HTTP_ERROR;
                error_ = String("Error loading SSL credentials.");
                SSL_CTX_free(ctx);
                return;
            }
        }

        // OpenSSL IO connection
        bio = BIO_new_ssl_connect(ctx);

        if (bio == NULL)
        {
            MutexLock lock(mutex_);
            LOGDEBUG("Error creating connection! (https)\n");
            state_ = HTTP_ERROR;
            error_ = String("Error creating connection (https).");
            SSL_CTX_free(ctx);
            return;
        }

        BIO_get_ssl(bio, &ssl);
        SSL_set_mode(ssl, SSL_MODE_AUTO_RETRY);
        BIO_set_conn_hostname(bio, host_port.CString());

        // Connect to server
        if (BIO_do_connect(bio) <= 0)
        {
            MutexLock lock(mutex_);
            LOGDEBUG("Failed to connect! (https)");
            state_ = HTTP_ERROR;
            error_ = String("Failed to connect (https).");
            BIO_free_all(bio);
            SSL_CTX_free(ctx);
            return;
        }

        if (BIO_do_handshake(bio) <= 0)
        {
            MutexLock lock(mutex_);
            LOGDEBUG("Failed to do SSL handshake !");
            state_ = HTTP_ERROR;
            error_ = String("Failed to do SSL handshake. ");
            BIO_free_all(bio);
            SSL_CTX_free(ctx);
            return;
        }

        if (storeType_ != HTTPS_CRED_NONE)
        {
            // Check for suspicious result
            if (SSL_get_verify_result(ssl) != X509_V_OK)
            {
                MutexLock lock(mutex_);
                LOGDEBUG("Failed to verify connection !");
                state_ = HTTP_ERROR;
                error_ = String("Failed to verify connection.");
                BIO_free_all(bio);
                SSL_CTX_free(ctx);
                return;
            }
        }
    }
    else
    {
        // OpenSSL IO connection
        bio = BIO_new_connect(host_port.CString());

        if (bio == NULL)
        {
            MutexLock lock(mutex_);
            LOGDEBUG("Error creating connection! (http)\n");
            state_ = HTTP_ERROR;
            error_ = String("Error creating connection (http).");
            return;
        }

        // Connect to server
        if (BIO_do_connect(bio) <= 0)
        {
            MutexLock lock(mutex_);
            LOGDEBUG("Failed to connect! (http)");
            state_ = HTTP_ERROR;
            error_ = String("Failed to connect (http).");
            return;
        }
    }

    // Send request
    BIO_puts(bio, request.CString());

    {
        MutexLock lock(mutex_);
        state_ = HTTP_OPEN;
    }

    // Loop while should run, read data from the connection, copy to the main thread buffer if there is space
    while (shouldRun_)
    {
        // Read less than full buffer to be able to distinguish between full and empty ring buffer. Reading may block
        int bytesRead = BIO_read(bio, httpReadBuffer_.Get(), READ_BUFFER_SIZE / 4);

        if (bytesRead == 0)
        {
            break;
        }
        else if (bytesRead < 0)
        { // Error
            if (!BIO_should_retry(bio))
            { // Don't retry
                MutexLock lock(mutex_);
                LOGDEBUG("Read failed!");
                state_ = HTTP_ERROR;
                error_ = String("Read failed.");
                break;
            }
        }

        mutex_.Acquire();

        // Wait until enough space in the main thread's ring buffer
        for (;;)
        {
            unsigned spaceInBuffer = READ_BUFFER_SIZE - ((writePosition_ - readPosition_) & (READ_BUFFER_SIZE - 1));
            if ((int)spaceInBuffer > bytesRead || !shouldRun_)
                break;

            mutex_.Release();
            Time::Sleep(5);
            mutex_.Acquire();
        }

        if (!shouldRun_)
        {
            mutex_.Release();
            break;
        }

        if (writePosition_ + bytesRead <= READ_BUFFER_SIZE)
            memcpy(readBuffer_.Get() + writePosition_, httpReadBuffer_.Get(), bytesRead);
        else
        {
            // Handle ring buffer wrap
            unsigned part1 = READ_BUFFER_SIZE - writePosition_;
            unsigned part2 = bytesRead - part1;
            memcpy(readBuffer_.Get() + writePosition_, httpReadBuffer_.Get(), part1);
            memcpy(readBuffer_.Get(), httpReadBuffer_.Get() + part1, part2);
        }

        writePosition_ += bytesRead;
        writePosition_ &= READ_BUFFER_SIZE - 1;

        mutex_.Release();
    }

    // Close the connection
    BIO_free_all(bio);
    SSL_CTX_free(ctx);

    {
        MutexLock lock(mutex_);
        if (state_ == HTTP_OPEN)
            state_ = HTTP_CLOSED;
    }
}

String HttpsRequest::GetResponseBody()
{
    MutexLock lock(mutex_);
    if (state_ == HTTP_CLOSED)
    {
        unsigned s = (writePosition_ - readPosition_) & (READ_BUFFER_SIZE - 1);
        char buf[s+1];
        Read(buf, s);
        String res = String(buf);

        unsigned bodyPosition = res.Find("\r\n\r\n") + 4;

        String responseBody_ = res.Substring(bodyPosition, s - bodyPosition);
        return responseBody_;
    }
    return String("");
}

unsigned HttpsRequest::Read(void* dest, unsigned size)
{
    mutex_.Acquire();

    unsigned char* destPtr = (unsigned char*)dest;
    unsigned sizeLeft = size;
    unsigned totalRead = 0;

    for (;;)
    {
        unsigned bytesAvailable;

        for (;;)
        {
            bytesAvailable = CheckEofAndAvailableSize();
            if (bytesAvailable || IsEof())
                break;
            // While no bytes and connection is still open, block until has some data
            mutex_.Release();
            Time::Sleep(5);
            mutex_.Acquire();
        }

        if (bytesAvailable)
        {
            if (bytesAvailable > sizeLeft)
                bytesAvailable = sizeLeft;

            if (readPosition_ + bytesAvailable <= READ_BUFFER_SIZE)
                memcpy(destPtr, readBuffer_.Get() + readPosition_, bytesAvailable);
            else
            {
                // Handle ring buffer wrap
                unsigned part1 = READ_BUFFER_SIZE - readPosition_;
                unsigned part2 = bytesAvailable - part1;
                memcpy(destPtr, readBuffer_.Get() + readPosition_, part1);
                memcpy(destPtr + part1, readBuffer_.Get(), part2);
            }

            readPosition_ += bytesAvailable;
            readPosition_ &= READ_BUFFER_SIZE - 1;
            sizeLeft -= bytesAvailable;
            totalRead += bytesAvailable;
            destPtr += bytesAvailable;
        }

        if (!sizeLeft || !bytesAvailable)
            break;
    }

    // Check for end-of-file once more after reading the bytes
    CheckEofAndAvailableSize();
    mutex_.Release();
    return totalRead;
}

String HttpsRequest::GetError() const
{
    MutexLock lock(mutex_);
    const_cast<HttpsRequest*>(this)->CheckEofAndAvailableSize();
    return error_;
}

HttpsRequestState HttpsRequest::GetState() const
{
    MutexLock lock(mutex_);
    const_cast<HttpsRequest*>(this)->CheckEofAndAvailableSize();
    return state_;
}

unsigned HttpsRequest::GetAvailableSize() const
{
    MutexLock lock(mutex_);
    return const_cast<HttpsRequest*>(this)->CheckEofAndAvailableSize();
}

unsigned HttpsRequest::CheckEofAndAvailableSize()
{
    unsigned bytesAvailable = (writePosition_ - readPosition_) & (READ_BUFFER_SIZE - 1);
    if (state_ == HTTP_ERROR || (state_ == HTTP_CLOSED && !bytesAvailable))
        position_ = M_MAX_UNSIGNED;
    return bytesAvailable;
}

}
