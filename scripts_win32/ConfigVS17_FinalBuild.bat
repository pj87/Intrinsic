cd ..
mkdir build
cd build

cmake -DINTR_FINAL_BUILD:BOOL=ON -G"Visual Studio 17 2022 -A x64" ..

cd ..\scripts_win32
