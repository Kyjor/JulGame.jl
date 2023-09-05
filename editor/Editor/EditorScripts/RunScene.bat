@echo off
set PROJECT_PATH=%~1
set "CURRENT_PATH=%CD%"
cd /d %PROJECT_PATH%
julia -e "push!(LOAD_PATH, \"@\"); push!(LOAD_PATH, \"@v#.#\"); push!(LOAD_PATH, \"@stdlib\"); include(\"Entry.jl\")"

cd %CURRENT_PATH%