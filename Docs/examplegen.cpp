#include <iostream>
#include <fstream>
#include <string>
#include <dirent.h>
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>

const std::string pattern[3] { "//! Begin [Example ", // C++
                               "//! Begin [Example ", // Angelscript
                               "--! Begin [Example "}; // Lua

enum class Language : unsigned{
    CPP = 0,
    AS,
    Lua
};

const char* languageStrings[3]{ "C++",
                                "Angelscript",
                                "Lua" };

void scanFile(std::fstream& out, std::fstream& fs, const char* filePath)
{
    // Determine language from file extension:
    Language lang;

    int len = strlen(filePath);
    for (int i = len - 1; i > 0; --i)
    {
        if (filePath[i] == '.')
        {
            if (filePath[i + 1] == 'l')
                lang = Language::Lua;
            else if (filePath[i + 1] == 'a')
                lang = Language::AS;
            else
                lang = Language::CPP;

            break;
        }
    }

    // Scan File:
    unsigned p = 0;
    char c;
    std::string className{ "" };

    while (fs.get(c))
    {
        if (p == pattern[(unsigned)lang].length())
        {
            if (c != ']')
                className += c;
            else
            {
                std::cout << "Found snippet, class: " << className << ", in: " << filePath << std::endl;
                out <<
                    "/**\n" <<
                    "    \\class " << className << "\n" <<
                    "    Example (" << languageStrings[(unsigned)lang] << "), from " << filePath << ":\n" <<
                    "    \\snippet " << filePath << " Example " << className << "\n*/\n\n";
                p = 0;
                className = "";
            }

        }
        else
        {
            if (c != pattern[(unsigned)lang][p++])
            {
                p = 0;
                continue;
            }
        }
    }

}

void scanPath(std::fstream& out, const char* path)
{
    DIR* dir;
    struct dirent* dp;

    dir = opendir(path);

    if (dir == NULL)
        goto isFile;

    dp = readdir(dir);

    if (dp == NULL)
    {
        closedir(dir);
        goto isFile;
    }

    struct stat info;

    stat(dp->d_name, &info);
    if (!S_ISDIR(info.st_mode))
    {
        closedir(dir);
        goto isFile;
    }

    while (dp != NULL)
    {
        if (strcmp(dp->d_name, ".") == 0 || strcmp(dp->d_name, "..") == 0)
        {
            dp = readdir(dir);
            continue;
        }

        std::string subPath = std::string(path) + "/" + std::string(dp->d_name);
        //std::cout << "Recursing path: " << subPath << std::endl;
        scanPath(out, subPath.c_str());

        dp = readdir(dir);
    }
    
    closedir(dir);

    return;

isFile:
    std::fstream fs(path, std::fstream::in);
    if (fs)
    {
        //std::cout << "Searching file: " << path << std::endl;
        scanFile(out, fs, path);
        fs.close();
    }
}

int main(int argc, char** args)
{
    std::fstream out;
    out.open("ExamplesGen.dox", std::fstream::out);
    out << "namespace Urho3D\n{\n";

    for (int i = 1; i < argc; ++i)
    {
        scanPath(out, args[i]);
    }

    out << "}";
    out.close();

    return 0;
}
