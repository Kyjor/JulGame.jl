#!/usr/bin/env julia
# Scaffold Vite + SDL WASM TS layer for a JulGame Julia game project.
#
#   julia tools/scaffold_ts.jl --project-root /path/to/Platformer
#   julia tools/scaffold_ts.jl --project-root . --julgame-path ../../JulGame.jl --scene level_0.json

const TOOLS_DIR = @__DIR__
const TEMPLATE_DIR = joinpath(TOOLS_DIR, "templates", "ts_project")
const REPO_ROOT = normpath(joinpath(TOOLS_DIR, ".."))

struct ScaffoldOptions
    project_root::String
    julgame_path::String
    scene::String
    port::Int
    width::Int
    height::Int
    pixels_per_unit::Int
    force::Bool
    gitignore_path::Union{String, Nothing}
end

function usage(io::IO = stderr)
    println(
        io,
        """
        Usage: julia tools/scaffold_ts.jl --project-root <path> [options]

        Options:
          --julgame-path <path>   JulGame.jl repo root (default: JULGAME_ROOT env or auto-detect)
          --scene <file>          Default scene JSON under scenes/ (default: scene.json)
          --port <n>              Vite dev server port (default: 5174)
          --width <n>             Canvas width (default: 800)
          --height <n>            Canvas height (default: 600)
          --ppu <n>               Default PixelsPerUnit in config.julgame (default: 16)
          --gitignore <path>      Gitignore to update (default: parent of project-root if named Platformer, else project-root)
          --force                 Overwrite existing scaffold files
        """,
    )
end

function parse_scaffold_args()::ScaffoldOptions
    project_root = nothing
    julgame_path = nothing
    scene = "scene.json"
    port = 5174
    width = 800
    height = 600
    pixels_per_unit = 16
    force = false
    gitignore_path = nothing
    i = 1
    while i <= length(ARGS)
        a = ARGS[i]
        if a in ("-h", "--help")
            usage(stdout)
            exit(0)
        elseif a == "--project-root"
            i += 1
            i > length(ARGS) && error("--project-root requires a path")
            project_root = abspath(ARGS[i])
        elseif a == "--julgame-path"
            i += 1
            i > length(ARGS) && error("--julgame-path requires a path")
            julgame_path = abspath(ARGS[i])
        elseif a == "--scene"
            i += 1
            i > length(ARGS) && error("--scene requires a filename")
            scene = String(ARGS[i])
        elseif a == "--port"
            i += 1
            i > length(ARGS) && error("--port requires a number")
            port = parse(Int, ARGS[i])
        elseif a == "--width"
            i += 1
            i > length(ARGS) && error("--width requires a number")
            width = parse(Int, ARGS[i])
        elseif a == "--height"
            i += 1
            i > length(ARGS) && error("--height requires a number")
            height = parse(Int, ARGS[i])
        elseif a == "--ppu"
            i += 1
            i > length(ARGS) && error("--ppu requires a number")
            pixels_per_unit = parse(Int, ARGS[i])
        elseif a == "--gitignore"
            i += 1
            i > length(ARGS) && error("--gitignore requires a path")
            gitignore_path = abspath(ARGS[i])
        elseif a == "--force"
            force = true
        else
            error("unknown argument: $a")
        end
        i += 1
    end
    project_root === nothing && error("--project-root is required (see --help)")
    return ScaffoldOptions(
        project_root,
        julgame_path === nothing ? "" : julgame_path,
        scene,
        port,
        width,
        height,
        pixels_per_unit,
        force,
        gitignore_path,
    )
end

function resolve_julgame_path(project_root::AbstractString, hint::AbstractString)::String
    if !isempty(hint)
        p = abspath(String(hint))
        isdir(p) || error("JulGame path not found: $p")
        isfile(joinpath(p, "tools", "convert.jl")) ||
            error("JulGame path missing tools/convert.jl: $p")
        return p
    end
    if haskey(ENV, "JULGAME_ROOT")
        p = abspath(ENV["JULGAME_ROOT"])
        isdir(p) && isfile(joinpath(p, "tools", "convert.jl")) && return p
    end
    root = abspath(String(project_root))
    candidates = [
        normpath(joinpath(root, "..", "..", "JulGame.jl")),
        normpath(joinpath(root, "..", "JulGame.jl")),
        REPO_ROOT,
    ]
    for p in candidates
        if isdir(p) && isfile(joinpath(p, "tools", "convert.jl"))
            return p
        end
    end
    error(
        "Could not find JulGame.jl. Pass --julgame-path or set JULGAME_ROOT.",
    )
end

function validate_project_root(project_root::AbstractString)
    for dir in ("scripts", "scenes", "assets")
        p = joinpath(project_root, dir)
        isdir(p) || error("missing required directory: $p")
    end
end

function default_gitignore_path(project_root::AbstractString)::String
    parent = dirname(abspath(String(project_root)))
    if basename(project_root) == "Platformer" && isfile(joinpath(parent, ".gitignore"))
        return joinpath(parent, ".gitignore")
    end
    gi = joinpath(project_root, ".gitignore")
    return isfile(gi) ? gi : joinpath(parent, ".gitignore")
end

function render_template(text::AbstractString, vars::Dict{String, String})::String
    out = String(text)
    for (k, v) in vars
        out = replace(out, "{{$k}}" => v)
    end
    return out
end

function write_scaffold_file(
    src::AbstractString,
    dest::AbstractString,
    vars::Dict{String, String},
    force::Bool,
)
    if isfile(dest) && !force
        println("skip (exists): $dest")
        return false
    end
    mkpath(dirname(dest))
    text = read(src, String)
    open(dest, "w") do io
        print(io, render_template(text, vars))
    end
    println("wrote: $dest")
    return true
end

function scaffold_tree(template_base::AbstractString, dest_base::AbstractString, vars::Dict{String, String}, force::Bool)
    for (root, dirs, files) in walkdir(template_base)
        rel = relpath(root, template_base)
        rel == "." && (rel = "")
        out_root = isempty(rel) ? dest_base : joinpath(dest_base, rel)
        for d in dirs
            mkpath(joinpath(out_root, d))
        end
        for f in files
            src = joinpath(root, f)
            write_scaffold_file(src, joinpath(out_root, f), vars, force)
        end
    end
end

function append_gitignore_entries(path::AbstractString, entries::Vector{String})
    isfile(path) || touch(path)
    existing = read(path, String)
    to_add = String[]
    for e in entries
        occursin(Regex("(?m)^\\s*$(escape_string(strip(e)))\\s*\$"), existing) && continue
        push!(to_add, e)
    end
    isempty(to_add) && return
    open(path, "a") do io
        endswith(existing, "\n") || println(io)
        for e in to_add
            println(io, e)
        end
    end
    println("updated gitignore: $path (+$(length(to_add)) entries)")
end

function project_display_name(project_root::AbstractString)::String
    return basename(abspath(String(project_root)))
end

function ensure_config_pixels_per_unit(project_root::AbstractString, ppu::Int)
    path = joinpath(project_root, "config.julgame")
    isfile(path) || return
    text = read(path, String)
    occursin(r"(?m)^\s*PixelsPerUnit\s*=" , text) && return
    open(path, "a") do io
        endswith(text, "\n") || println(io)
        println(io, "PixelsPerUnit=$ppu")
    end
    println("updated config.julgame: PixelsPerUnit=$ppu")
end

"""Canonical `tools/transpile.jl` written into every scaffolded TS project."""
function canonical_transpile_jl()::String
    return """
    #!/usr/bin/env julia
    # Generated by JulGame scaffold — edit below only for project-specific transpile hooks.

    const PROJECT_ROOT = normpath(@__DIR__, "..")

    import Pkg
    Pkg.activate(PROJECT_ROOT)

    using JulGame
    include(joinpath(pkgdir(JulGame), "tools", "src", "ToolsModule.jl"))
    ToolsModule.Transpile(;
        project_root=PROJECT_ROOT,
        engine=!any(==("--scripts-only"), ARGS),
        scripts=!any(==("--engine-only"), ARGS))
    """
end

function write_transpile_jl(project_root::AbstractString, force::Bool)
    dest = joinpath(abspath(project_root), "tools", "transpile.jl")
    if isfile(dest) && !force
        println("skip (exists): $dest")
        return false
    end
    mkpath(dirname(dest))
    open(dest, "w") do io
        print(io, canonical_transpile_jl())
    end
    println("wrote: $dest")
    return true
end

function main()
    opts = parse_scaffold_args()
    validate_project_root(opts.project_root)
    julgame = resolve_julgame_path(opts.project_root, opts.julgame_path)
    julgame_ts_rel = replace(relpath(joinpath(julgame, "ts"), opts.project_root), '\\' => '/')
    name = project_display_name(opts.project_root)
    vars = Dict{String, String}(
        "PROJECT_NAME" => lowercase(name),
        "PAGE_TITLE" => name,
        "JULGAME_TS_REL" => julgame_ts_rel,
        "JULGAME_TS_DIR" => julgame_ts_rel,
        "DEV_PORT" => string(opts.port),
        "DEFAULT_SCENE" => opts.scene,
        "CANVAS_WIDTH" => string(opts.width),
        "CANVAS_HEIGHT" => string(opts.height),
    )
    isdir(TEMPLATE_DIR) || error("missing template dir: $TEMPLATE_DIR")
    scaffold_tree(TEMPLATE_DIR, opts.project_root, vars, opts.force)
    write_transpile_jl(opts.project_root, opts.force)
    ensure_config_pixels_per_unit(opts.project_root, opts.pixels_per_unit)
    gi = opts.gitignore_path !== nothing ? opts.gitignore_path : default_gitignore_path(opts.project_root)
    append_gitignore_entries(gi, ["node_modules/", "dist/"])
    println()
    println("Scaffold complete for: $(opts.project_root)")
    println("JulGame: $julgame")
    println()
    println("Next steps:")
    println("  cd $(opts.project_root)")
    println("  npm install")
    println("  npm run build:wasm")
    println("  npm run transpile")
    println("  npm run dev    # http://localhost:$(opts.port)/")
end

main()
