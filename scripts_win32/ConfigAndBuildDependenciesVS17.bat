cd ..
git submodule update --init --recursive

cd dependencies/glslang
mkdir build
cd build

cmake .. -G"Visual Studio 17 2022"
call cmake --build . --config Release
call cmake --build . --config Debug

cd ..\..\..\scripts_win32
