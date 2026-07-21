# Build lib_desktop/libjg_static.* from Julia (no SDL).
# Pattern: functions list + .o merge + shared lib only.
#
# Usage (from this directory):
#   julia --project=. compile_library.jl desktop
#   ./build_host.sh
#
# Needs Julia 1.11 + StaticCompiler from this folder's Project.toml (not global 0.7.2).

using Pkg
const STATIC_ROOT = @__DIR__
if isfile(joinpath(STATIC_ROOT, "Project.toml"))
    Pkg.activate(STATIC_ROOT)
    Pkg.instantiate()
end

using StaticTools
using StaticCompiler

compile_file = get(ENV, "FILE", "library.jl")
include(joinpath(STATIC_ROOT, compile_file))

build_type = length(ARGS) > 0 ? lowercase(ARGS[1]) : "desktop"
build_type in ("web", "desktop") || error("Usage: julia --project=. compile_library.jl [web|desktop]")

lib_base = get(ENV, "LIB_NAME", "jg_static")
output_dir = build_type == "web" ? "lib_wasm" : "lib_desktop"
isdir(output_dir) || mkdir(output_dir)

println("📚 Compiling Julia library for $build_type")
println("   Julia $(VERSION.major).$(VERSION.minor).$(VERSION.patch)")
println("   StaticCompiler $(pkgversion(StaticCompiler))")
println("=" ^ 50)

println("🧹 Cleaning up old files...")
for file in readdir(output_dir)
    # Keep hand-maintained headers out of lib_*; jg_static.h lives in Static/
    if endswith(file, ".ll") || endswith(file, ".o") || endswith(file, ".so") ||
       endswith(file, ".dll") || endswith(file, ".dylib") || endswith(file, ".a")
        rm(joinpath(output_dir, file))
        println("🗑️  Removed: $file")
    end
end

const _BATCH_SIG = (
    Int32, Int32,
    Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Ptr{Int32},
    Int32,
)

functions_to_compile = [
    (static_is_mouse_inside_element, (Int32, Int32, Int32, Int32, Int32, Int32), "static_is_mouse_inside_element"),
    (static_ui_hit_test_batch, _BATCH_SIG, "static_ui_hit_test_batch"),
    (static_force_frame_update, (Ptr{Cvoid}, Int32), "static_force_frame_update"),
    (static_play_animation_once, (Ptr{Cvoid}, Int32), "static_play_animation_once"),
    (static_update, (Ptr{Cvoid}, Int32), "static_update"),
]

compile_ok = true
for (func, types, name) in functions_to_compile
    println(" Compiling $name...")
    try
        if build_type == "web"
            StaticCompiler.generate_obj(func, types, output_dir, name, emit_llvm_only=true)
            println("✅ Generated: $output_dir/$name.ll")
        else
            StaticCompiler.generate_obj(func, types, output_dir, name, emit_llvm_only=false)
            println("✅ Generated: $output_dir/$name.o")
        end
    catch e
        global compile_ok = false
        println("❌ Error compiling $name: $e")
        if occursin("validate_code_in_debug_mode", string(e))
            println("💡 Use: julia --project=$(STATIC_ROOT) compile_library.jl desktop")
            println("   (global StaticCompiler 0.7.2 does not support Julia 1.11)")
        end
    end
end

if build_type == "web"
    println("\n⚠️  Web/WASM build not set up in JulGame Static yet.")
    println("   For emscripten + SDL, see sc-game/compile_library.jl web target.")
    compile_ok || exit(1)
    exit(0)
end

if !compile_ok
    println("\n❌ One or more functions failed to compile — not linking.")
    exit(1)
end

run_cmd(exe::String, args::Vector{String}) = run(Cmd(vcat([exe], args)))

println("\n🔨 Bundling native library (Julia .o + jg_static_runtime.c, no SDL)...")

runtime_c = joinpath(STATIC_ROOT, "jg_static_runtime.c")
runtime_o = joinpath(output_dir, "jg_static_runtime.o")
println(" Compiling jg_static_runtime.c...")
run_cmd("gcc", ["-c", "-O3", "-fPIC", "-o", runtime_o, runtime_c])

julia_o_files = String[]
for file in readdir(output_dir)
    endswith(file, ".o") || continue
    # Keep runtime .o separate; merge Julia objects only
    basename(file) == "jg_static_runtime.o" && continue
    push!(julia_o_files, joinpath(output_dir, file))
end

if isempty(julia_o_files)
    println("❌ No .o files in $output_dir — compile step produced nothing.")
    exit(1)
end

merged_o = joinpath(output_dir, "$(lib_base)_merged.o")
opt_c = ["-O3", "-flto", "-fPIC"]
if length(julia_o_files) == 1
    cp(julia_o_files[1], merged_o; force=true)
else
    run_cmd("gcc", vcat(opt_c, ["-r", "-o", merged_o], julia_o_files))
end

static_lib = joinpath(output_dir, "lib$(lib_base).a")
run_cmd("ar", ["rcs", static_lib, merged_o, runtime_o])
println("✅ Static archive: $static_lib")

if Sys.iswindows()
    lib_name = "$(lib_base).dll"
    system_libs = String[]
elseif Sys.isapple()
    lib_name = "lib$(lib_base).dylib"
    system_libs = ["-Wl,-undefined,dynamic_lookup"]
else
    lib_name = "lib$(lib_base).so"
    system_libs = ["-ldl", "-lpthread", "-lm"]
end

lib_path = joinpath(output_dir, lib_name)
soname = Sys.islinux() ? ["-Wl,-soname,$lib_name"] : String[]
# No -flto on final link: mix LTO Julia .o with non-LTO C runtime.
run_cmd("gcc", vcat(["-shared", "-O3", "-fPIC"], soname, ["-o", lib_path, merged_o, runtime_o], system_libs))
println("✅ Shared library: $lib_path")
println("\n💡 Verify: ./build_host.sh")
