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
    echo Error: Multiple .jl files found in the specified directory. You should only have one .jl file in your src.
    exit /b 1
)

if not defined JL_FILE (
    echo Error: No .jl file found in the specified directory. You should have one .jl file in your src folder.
    exit /b 1
)

REM Create a string with all current environment variables
set "ENV_VARIABLES="
for /f "usebackq tokens=1,* delims==" %%a in (`set`) do (
    set "ENV_VARIABLES=!ENV_VARIABLES!;ENV[\"%%a\"] = \"%%b\""
)

REM Execute the found .jl file
julia --compile=min -e "push!(LOAD_PATH, \"@\"); push!(LOAD_PATH, \"@v#.#\"); push!(LOAD_PATH, \"@stdlib\"); include(\"%JL_FILE%\")"

cd "%CURRENT_PATH%"
REM push!(LOAD_PATH, \"@\"); \"@v#.#\"); push!(LOAD_PATH, \"@stdlib\");