module ToolsModule

export Transpile

const JULGAME_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

"""
    Transpile(; project_root=pwd(), engine=true, scripts=true)

Transpile JulGame engine sources and/or game project scripts to TypeScript.

- `engine`: run JulGame `tools/convert.jl` (engine manifest)
- `scripts`: run `convert.jl --project-root <project> --all-scripts`
"""
function Transpile(;
    project_root::AbstractString = pwd(),
    engine::Bool = true,
    scripts::Bool = true,
    scene::Union{Nothing, AbstractString} = nothing,
)
    project_root = abspath(project_root)
    convert_script = joinpath(JULGAME_ROOT, "tools", "convert.jl")
    isfile(convert_script) || error("missing JulGame transpiler: $convert_script")
    julia = Base.julia_cmd()
    if engine
        println("=== JulGame engine ===")
        run(`$julia $convert_script`)
    end
    if scripts
        println("=== Game scripts ===")
        if scene === nothing
            run(`$julia $convert_script --project-root $project_root --all-scripts`)
        else
            run(`$julia $convert_script --project-root $project_root --all-scripts --scene $scene`)
        end
    end
    println("Transpile complete.")
    return nothing
end

end
