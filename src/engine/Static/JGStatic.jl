# Shared access to the JulGame StaticCompiler native library (lib_desktop).
module JGStaticModule

const LIB_EXT = Sys.iswindows() ? "dll" : Sys.isapple() ? "dylib" : "so"
const LIB_DIR = normpath(joinpath(@__DIR__, "lib_desktop"))
# Built artifact name from compile_library.jl / build_host.sh
const LIB_PATH = joinpath(LIB_DIR, "libjg_static.$LIB_EXT")
const LIB_AVAILABLE = isfile(LIB_PATH)

function lib_path()::String
    LIB_PATH
end

function lib_available()::Bool
    LIB_AVAILABLE
end

@info "JGStatic" path=LIB_PATH available=LIB_AVAILABLE

export LIB_EXT,
       LIB_DIR,
       LIB_PATH,
       LIB_AVAILABLE,
       lib_path,
       lib_available

end
