@echo off
set "PROJECT_PATH=%~1"
set "CURRENT_PATH=%CD%"
cd /d "%PROJECT_PATH%"

REM Find the first .jl file in the directory
set "JL_FILE="
set "COUNT=0"
for %%i in (*.jl) do (
    set "JL_FILE=%%i"
    set /a COUNT+=1
)

if %COUNT% gtr 1 (
    echo Error: Multiple .jl files found in the specified directory.
    exit /b 1
)

if not defined JL_FILE (
    echo Error: No .jl file found in the specified directory.
    exit /b 1
)
set "JULIA_DEPOT_PATH="
set "JULIA_LOAD_PATH="

REM Execute the found .jl file with the specified julia.exe and current environment variables
start julia --compile=min -e "push!(LOAD_PATH, \"@\"); push!(LOAD_PATH, \"@v#.#\"); push!(LOAD_PATH, \"@stdlib\"); include(\"%JL_FILE%\")"

cd "%CURRENT_PATH%"