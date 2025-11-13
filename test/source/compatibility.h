/*
defines lots of microsoft specific stuff so that it this code can be compiled with a standard gcc.

needs the 3rd party files StdString.h and PortableFileClass.hpp as drop-in replacements for MFC stuff.

this version is for Intel 64 bit g++ !

urut@caltech.edu
*/

#ifndef _COMPAT_
#define _COMPAT_

#include "StdString.h"
#include <fstream>
#include <string>

#if defined(_WIN32) || defined(_WIN64) || defined(WIN32) || defined(WIN64) || defined(_MSC_VER)
// Windows version
#ifndef NOMINMAX
#define NOMINMAX  // Prevent Windows.h from defining min/max macros
#endif
#ifndef WINDOWS_IGNORE_PACKING_MISMATCH
#define WINDOWS_IGNORE_PACKING_MISMATCH  // Allow custom packing for Neuralynx data structures
#endif
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <limits.h>

// Define MAP_FAILED before use
#ifndef MAP_FAILED
#define MAP_FAILED ((void*)-1)
#endif

// Type definitions for Windows
#ifndef _OFF_T_DEFINED
#ifndef off_t
typedef __int64 off_t;
#endif
#endif
#ifndef ssize_t
typedef int ssize_t;
#endif

// Windows equivalents for Unix functions
#define O_RDONLY _O_RDONLY
// SEEK_SET is already defined in Windows headers
#define PROT_READ PAGE_READONLY
#define MAP_SHARED 0

// File descriptor type for Windows
typedef HANDLE file_descriptor_t;

// Windows memory mapping functions
// We need to store the mapping handle to properly clean up resources.
// For simplicity, we'll use a static map to store handle pointers.
#include <map>
inline std::map<void*, HANDLE>& GetMapHandles() {
    static std::map<void*, HANDLE> g_mapHandles;
    return g_mapHandles;
}

inline void* mmap(void* addr, size_t len, int prot, int flags, int fd, off_t offset) {
    (void)addr; // unused on Windows
    (void)flags; // unused on Windows
    HANDLE hFile = (HANDLE)_get_osfhandle(fd);
    if (hFile == INVALID_HANDLE_VALUE) return MAP_FAILED;
    
    HANDLE hMap = CreateFileMapping(hFile, NULL, PAGE_READONLY, 0, 0, NULL);
    if (hMap == NULL) return MAP_FAILED;
    
    // MapViewOfFile requires SIZE_T for size, and DWORD for offset parts
    SIZE_T mapSize = (len > (SIZE_T)-1) ? (SIZE_T)-1 : (SIZE_T)len;
    void* ptr = MapViewOfFile(hMap, FILE_MAP_READ, 
                              (DWORD)(((unsigned __int64)offset >> 32) & 0xFFFFFFFF), 
                              (DWORD)((unsigned __int64)offset & 0xFFFFFFFF), 
                              mapSize);
    if (ptr == NULL) {
        CloseHandle(hMap);
        return MAP_FAILED;
    }
    
    // Store the mapping handle for later cleanup
    GetMapHandles()[ptr] = hMap;
    return ptr;
}

inline int munmap(void* addr, size_t len) {
    (void)len; // unused on Windows
    if (addr == NULL || addr == MAP_FAILED) return -1;
    
    // Find and close the mapping handle
    std::map<void*, HANDLE>& mapHandles = GetMapHandles();
    std::map<void*, HANDLE>::iterator it = mapHandles.find(addr);
    if (it != mapHandles.end()) {
        CloseHandle(it->second);
        mapHandles.erase(it);
    }
    
    return UnmapViewOfFile(addr) ? 0 : -1;
}

// Define POSIX-compatible functions
// Windows UCRT defines open/read as functions with variable arguments, so we need to use inline functions
// and then use macros to redirect calls to our versions
inline int compat_close(int fd) {
    return _close(fd);
}

inline int compat_open(const char* pathname, int flags) {
    return _open(pathname, flags);
}

// Overload for CStdString (CString is defined later as CStdString)
inline int compat_open(const CStdString& pathname, int flags) {
    return _open(pathname.c_str(), flags);
}

inline off_t compat_lseek(int fd, off_t offset, int whence) {
    // Use _lseeki64 for 64-bit file offsets on Windows
    return _lseeki64(fd, offset, whence);
}

inline ssize_t compat_read(int fd, void* buf, size_t count) {
    // _read in Windows may read less than requested, so we need to read in a loop
    if (count == 0) return 0;
    
    size_t totalRead = 0;
    char* pBuf = (char*)buf;
    size_t remaining = count;
    
    // Limit to UINT_MAX per call to match _read signature
    while (remaining > 0) {
        unsigned int chunkSize = (remaining > UINT_MAX) ? UINT_MAX : (unsigned int)remaining;
        int nRead = _read(fd, pBuf + totalRead, chunkSize);
        
        if (nRead < 0) {
            // Error occurred
            return (totalRead > 0) ? (ssize_t)totalRead : -1;
        }
        if (nRead == 0) {
            // EOF reached before reading all requested bytes
            break;
        }
        
        totalRead += (size_t)nRead;
        remaining -= (size_t)nRead;
        
        // If we read less than requested, continue reading
        // This handles the case where _read reads partial data
    }
    
    return (ssize_t)totalRead;
}

// Note: We don't use macros to avoid conflicts with class methods (e.g., std::fstream::open)
// Use compat_* functions directly in code, or define them as open/read/close/lseek if needed
// For now, we'll use function pointers or direct calls

// Wrapper for fstat to avoid conflict with Windows _fstat
inline int compat_fstat(int fd, struct stat* buf) {
    if (!buf) return -1;
    // Use _fstat64 for 64-bit file sizes
    struct _stat64 st64;
    int ret = _fstat64(fd, &st64);
    if (ret == 0) {
        // Copy relevant fields to standard stat structure
        memset(buf, 0, sizeof(struct stat));
        buf->st_size = st64.st_size;
        buf->st_mode = st64.st_mode;
        buf->st_mtime = st64.st_mtime;
    }
    return ret;
}
#define fstat compat_fstat

#else
// Unix/Linux version
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h> 
#include <fcntl.h> 
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

typedef int file_descriptor_t;
#endif

//MS compatibility stuff

#define BOOL bool
#define CString CStdString
//#define CFile File

#define __int8 char
#define __int16	short
#define __int32 int 
#define __int64 long
#define ULONGLONG unsigned long long
#define UINT unsigned int

#define FALSE 0
#define TRUE 1


#endif
