#include <iostream>
#include <fstream>
#include <string>
#include <dirent.h>
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>
#include <vector>

const std::vector< std::string > pattern[3] { {"// Begin [Example ", "/* Begin [Example "}, // C++
                                              {"// Begin [Example ", "/* Begin [Example " }, // Angelscript
                                              {"-- Begin [Example " } }; // Lua

enum class Language: unsigned {
    CPP = 0,
    AS,
    Lua
};

const char* languageStrings[3] { "C++",
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

    const unsigned patternSize = pattern[(unsigned)lang].size();

    // Pattern match counters
    std::vector<unsigned> p;
    p.resize(patternSize);
    for (unsigned i = 0; i < patternSize; ++i)
        p[i] = 0;

    // The character being read
    char c;
    // The class name being extracted.
    std::string className{ "" };

    // Read through the file, one character at a time:
    while (fs.get(c))
    {
        // Match multiple patterns at once:
        for (unsigned i = 0; i < patternSize; ++i)
        {
            const std::string& patternString = pattern[(unsigned)lang][i];

            if (p[i] == patternString.length())
            {
                // The beginning pattern matched, extract class name:
                // Note, we allow the side effect of collecting 'class names' with spaces, which will allow
                // multiple matches of the same class within the same document, with extra annotation, eg:
                // Begin [Example SomeClass Initialization] ... // Begin [Example SomeClass Usage]
                // This will be formatted as: \class SomeClass Usage, however doxygen will only consider
                // the class without spaces.
                if (c != ']')
                    className += c;
                else
                {
                    // Hit a ']', indicating end of class name.
                    // Write output:
                    std::cout << "Found snippet, class: " << className << ", in: " << filePath << std::endl;
                    out <<
                        "/**\n" <<
                        "    \\class " << className << "\n" <<
                        "    \\htmlonly <div class=\"examplecode " << languageStrings[(unsigned)lang] << "\"> \\endhtmlonly\n"
                        "    Example (" << languageStrings[(unsigned)lang] << "), from " << filePath << ":\n" <<
                        "    \\snippet " << filePath << " Example " << className << "\n" <<
                        "    \\htmlonly </div> \\endhtmlonly" <<
                        "*/\n\n";

                    // Reset the match counter to: '// Begin'< , allowing matches to:
                    // Begin [Example Class1] [Example Class2]
                    p[i] = 8;
                    className = "";
                }

            }
            else
            {
                // Trying to match the beginning pattern:
                const char patternChar = patternString[p[i]];

                // Ignore white spaces
                
                if (patternChar == ' ')
                {
                    const bool isWS = (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f');

                    if (!isWS)
                    {
                        // Hit a non-whitespace character

                        if (p[i] == patternString.length() - 1)
                        {
                            // End of the pattern
                            ++p[i];

                            // Capture the first character of the class:
                            className = c;
                        }
                        else
                        {
                            // Check if next pattern character matches with c:
                            const char patternCharNext = patternString[++p[i]];

                            if (c != patternCharNext)
                            {
                                // Not a match - reset the pattern counter
                                p[i] = c == patternString[0] ? 1 : 0;
                            }
                            else
                            {
                                // Increment past the already checked pattern character
                                ++p[i];
                            }
                        }
                    }
                }
                else
                {
                    ++p[i];
                    if (c != patternChar)
                    {
                        // Not a match - reset the pattern counter
                        p[i] = c == patternString[0] ? 1 : 0;
                    }
                }
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

    out << "}\n";
    out.close();

    return 0;
}
