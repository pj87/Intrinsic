cd ..
mkdir build
cd build

cmake -DINTR_FINAL_BUILD:BOOL=ON -G"Visual Studio 18 2026" -A x64 ..

cd ..\scripts_win32
