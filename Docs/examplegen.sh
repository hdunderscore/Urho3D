#!/bin/bash
g++ examplegen.cpp -o examplegen -std=c++11
./examplegen ../Source/Urho3D/* ../Source/Samples/* ../Bin/Data/Scripts ../Bin/Data/LuaScripts
