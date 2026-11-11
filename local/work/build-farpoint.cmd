@echo off
rem Builds Farpoint PC VR from C:\Games\Farpoint-us, a worktree of C:\Games\Farpoint-src on branch us-support
rem (evertec82 Farpoint v0.9.6 + US release, Steam Frame, AF16, MLAA + shadPS4 main of 2026-11-10). Super Stardust
rem Ultra VR builds from C:\Games\Farpoint-src itself (C:\Games\ssuvr-work\build-ssuvr.cmd). clang-cl from LLVM 23.1.4,
rem MSVC 14.44 + Windows SDK via vcvars64, VS-bundled CMake/Ninja. HAVE_ENDIAN_H=0: LLVM 23 ships its own endian.h, which
rem libressl then uses instead of its shim. Idle priority, 4 jobs by default, so an RDP session stays responsive.
rem usage: build-farpoint.cmd [configure|build] [jobs]
setlocal
set "SRC=C:\Games\Farpoint-us"
set "BLD=C:\Games\Farpoint-us\build\win-us"
set "JOBS=%~2"
if "%JOBS%"=="" set "JOBS=4"
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set "PATH=C:\Games\SDKs\clang+llvm-23.1.4-x86_64-pc-windows-msvc\bin;C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
set "VULKAN_SDK="
if "%~1"=="configure" (
  cmake -S "%SRC%" -B "%BLD%" -G Ninja -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl -DCMAKE_LINKER=lld-link -DCMAKE_RC_COMPILER=llvm-rc ^
    -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL -DENABLE_DISCORD_RPC=OFF -DENABLE_UPDATER=OFF -DENABLE_OPENXR=ON ^
    -DALSOFT_UPDATE_BUILD_VERSION=OFF -DHAVE_ENDIAN_H=0 ^
    -DPython3_EXECUTABLE=C:\Users\<user>/envs/python-3.13.16/python.exe || exit /b 1
)
start "" /low /b /wait cmake --build "%BLD%" --target shadps4 --parallel %JOBS% || exit /b 1
