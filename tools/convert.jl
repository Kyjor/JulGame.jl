#!/usr/bin/env julia
# Julia → TypeScript stub emitter (extend later).
#
#   julia convert.jl
#
# Output path rule: <REPO_ROOT>/_generated/<mirror-of-relative-path>.ts

const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))

default_out_dir() = joinpath(REPO_ROOT, "_generated")

"""
    ts_output_path(jl_path; repo_root, generated_dir)

Build the `.ts` path as: `joinpath(repo_root, generated_dir, <same relative dirs as jl_path>, <stem>.ts)`.

Example: `repo/src/engine/Foo.jl` → `repo/_generated/src/engine/Foo.ts`

You cannot “edit” a `joinpath` result in place — strings are immutable. Split with `splitdir` / `relpath`, then `joinpath` again.
"""
function ts_output_path(
    jl_path::AbstractString;
    repo_root::AbstractString = REPO_ROOT,
    generated_dir::AbstractString = "_generated",
)::String
    abs_jl = abspath(jl_path)
    abs_root = abspath(repo_root)
    rel = try
        relpath(abs_jl, abs_root)
    catch
        splitdir(abs_jl)[2]  # basename-only fallback
    end
    rel_dir, rel_file = splitdir(rel)
    stem = splitext(rel_file)[1]
    isempty(rel_dir) && return joinpath(abs_root, generated_dir, stem * ".ts")
    joinpath(abs_root, generated_dir, rel_dir, stem * ".ts")
end

function transpile_file(path_jl::AbstractString)
    path_ts = ts_output_path(path_jl)
    return parse_file(path_jl, path_ts)
end

function parse_file(path_jl::AbstractString, path_ts::AbstractString)
    mkpath(dirname(path_ts))
    data = read(path_jl, String)
    data = replace_module(data)
    open(path_ts, "w") do io
        print(io, data)
    end
    path_ts
end

function replace_module(data::AbstractString)
    data = replace(data, r"module " => "")
    # `findlast("end", s)` returns a `UnitRange` of indices, not one integer
    r = findlast("end", data)
    r === nothing && return data
    head = data[1:prevind(data, first(r))]
    return head * "}"
end

function main()
    files = [joinpath(REPO_ROOT, "src", "engine", "Component", "Animation.jl")]
    mkpath(default_out_dir())
    for f in files
        isfile(f) || error("not a file: $f")
        println(transpile_file(f))
    end
end

main()
