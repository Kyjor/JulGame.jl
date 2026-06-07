# Game project scripts/*.jl → ts/_generated/scripts/*.ts (included from tools/convert.jl).

"""True when `path_jl` lives under a game project's `scripts/` folder."""
function is_game_script_source(path_jl::AbstractString)::Bool
    norm = replace(normpath(String(path_jl)), '\\' => '/')
    return occursin("/scripts/", norm) && endswith(norm, ".jl")
end

"""Script name from `scripts/PlayerMovement.jl` → `PlayerMovement`."""
function game_script_name(path_jl::AbstractString)::String
    return splitext(basename(String(path_jl)))[1]
end

function strip_script_module_wrapper(data::AbstractString)::String
    s = String(data)
    s = replace(s, r"^export \{\}\n+" => "")
    s = replace(s, r"(?m)^\s*module\s+\w+Module\s*\n" => "")
    s = replace(s, r"(?m)^\s*end\s*#\s*module.*$" => "")
    s = replace(s, r"(?m)^\s*end\s*#\s*module\s*$" => "")
    lines = split(rstrip(s, '\n'), '\n'; keepempty = true)
    while !isempty(lines) && strip(lines[end]) == "end"
        pop!(lines)
    end
    return join(lines, '\n')
end

function script_registry_import_line(path_ts::AbstractString)::String
    ts_dir = dirname(abspath(path_ts))
    reg = abspath(joinpath(@__DIR__, "..", "..", "ts", "src", "engine", "runtime", "scriptRegistry.ts"))
    rel = replace(String(relpath(reg, ts_dir)), '\\' => '/')
    rel = replace(rel, r"\.ts$" => "")
    if occursin("_generated/scripts", replace(normpath(path_ts), '\\' => '/'))
        return "import { registerScript } from \"julgame/src/engine/runtime/scriptRegistry\";"
    end
    return "import { registerScript } from \"$rel\";"
end

function apply_game_script_fixups(data::AbstractString, name::AbstractString)::String
    s = String(data)
    init_fn = "JulGame_initialize_$name"
    update_fn = "JulGame_update_$name"
    shutdown_fn = "JulGame_on_shutdown_$name"
    s = replace(s, "function JulGame_initialize(self: $name" => "function $init_fn(self: $name")
    s = replace(s, "function JulGame_update(self: $name" => "function $update_fn(self: $name")
    s = replace(s, "function JulGame_on_shutdown(self: $name" => "function $shutdown_fn(self: $name")
    if !occursin("export class $name", s) && occursin("class $name", s)
        s = replace(s, "class $name" => "export class $name")
    end
    s = replace(s, r"\(globalThis as any\)\.JulGame\.Component_add_collision_event" =>
        "(globalThis as any).JulGame.Component.add_collision_event")
    s = replace(s, r"\(globalThis as any\)\.JulGame\.Component_toggle_sound" =>
        "(globalThis as any).JulGame.Component.toggle_sound")
    s = replace(s, r"\(globalThis as any\)\.JulGame\.Component_flip" =>
        "(globalThis as any).JulGame.Component.flip")
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGame\.Macros\.@argevent\s*\((\w+)\)\s+(\w+)\(self,\s*\1\)" =>
            s"( (\1: any) => \2(self, \1))",
    )
    s = replace(s, r"scheduleTask\(\(\) => knockback_coroutine\(self\)\s*$" => "scheduleTask(() => knockback_coroutine(self))")
    s = replace(s, "scheduleTask(() => knockback_coroutine(self)" => "scheduleTask(() => knockback_coroutine(self))")
    s = replace(
        s,
        r"self\.knockbackTask = scheduleTask\(\(\) => knockback_coroutine\(self\)\s*\n" =>
            "self.knockbackTask = scheduleTask(() => knockback_coroutine(self));\n",
    )
    s = replace(
        s,
        r"console\.log\(`freed \$\{notifyCondition\(self\.condition\)\} waiting for \$\{self\.condition\}`\)" =>
            "notifyCondition(self.condition); console.log('knockback waiting', self.condition)",
    )
    s = fix_argevent_collision_callbacks(s)
    s = fix_bare_main_identifiers(s)
    s = fix_double_julgame_rewrite(s)
    s = replace(s, r" extends Script" => "")
    s = replace(s, r": EditorExport\{Float64\}" => ": number")
    s = replace(s, r": EditorExport\{Int\}" => ": number")
    s = replace(s, r": EditorExport\{Bool\}" => ": boolean")
    s = replace(s, "function $name()" => "constructor()")
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGame\.Component_get_velocity" =>
            "(globalThis as any).JulGame.RigidbodyModule.Component_get_velocity",
    )
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGame\.Component_unload_sound" =>
            "(globalThis as any).JulGame.Component.unload_sound",
    )
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGame\.destroy\(" =>
            "(globalThis as any).JulGame.destroy_entity((globalThis as any).MAIN, ",
    )
    s = replace(s, r"\babs\(" => "Math.abs(")
    s = replace(s, r"\bsign\(" => "Math.sign(")
    s = replace(s, r"split\(([^,]+),\s*\"/\"\)" => s"\1.split('/')")
    s = replace(s, ".split('/')[1]" => ".split('/')[0]")
    s = replace(s, ".split('/')[2]" => ".split('/')[1]")
    s = replace(s, ".split('/')[3]" => ".split('/')[2]")
    s = replace(
        s,
        r"(\.isCenteredX),\s*(\.isCenteredY)\s*=\s*true,\s*true" => s"\1 = true; \2 = true",
    )
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGame\.SceneModule\.get_entity_by_name\(\"([^\"]+)\"\)" =>
            s"(globalThis as any).JulGame.SceneModule.get_entity_by_name((globalThis as any).MAIN.scene, \"\1\")",
    )
    s = replace(
        s,
        r"self\.cameraTarget = \(globalThis as any\)\.JulGame\.TransformModule\.Transform\(\{x: ([^,]+), y: ([^,]+), z: ([^}]+)\}\)" =>
            s"self.cameraTarget = { position: { x: \1, y: \2, z: \3 }, scale: { x: 1, y: 1, z: 1 } }",
    )
    # Transform already lowered to `{ position: ... }` before fixups run.
    s = replace(
        s,
        r"(self\.cameraTarget = \{ position: \{[^}]+\}) \};" =>
            s"\1, scale: { x: 1, y: 1, z: 1 } };",
    )
    s = replace(
        s,
        "console.log(`freed \${notifyCondition(self.condition)} waiting for \${self.condition}`)" =>
            "notifyCondition(self.condition); console.log('knockback waiting', self.condition)",
    )
    s = replace(s, r"\bAnimatorModule\." => "(globalThis as any).JulGame.AnimatorModule.")
    s = replace(s, r"\bRigidbodyModule\." => "(globalThis as any).JulGame.RigidbodyModule.")
    s = fix_double_main_rewrite(s)
    # Julia `if (a && b) || (c && d)` can transpile as `if (a && b) || (c && d) {` — invalid TS.
    s = replace(s, r"if \(([^)]+)\) \|\| \(([^)]+)\) \{" => s"if ((\1) || (\2)) {")
    s = replace(s, r"\(globalThis as any\)\.JulGame\.\{x:" => "{x:")
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGame\.Math\.Vector2f\(([^,]+),\s*([^)]+)\)" =>
            s"{x: \1, y: \2}",
    )
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGame\.Math\.Vector3f\(([^,]+),\s*([^,]+),\s*([^)]+)\)" =>
            s"{x: \1, y: \2, z: \3}",
    )
    s = replace(s, r"\bVector2f\(([^,]+),\s*([^)]+)\)" => s"{x: \1, y: \2}")
    s = replace(s, r"\bVector3f\(([^,]+),\s*([^,]+),\s*([^)]+)\)" => s"{x: \1, y: \2, z: \3}")
    s = replace(s, "parse(Int," => "parseInt(")
    s = replace(s, "\"\$(score)\"" => "`\${score}`")
    s = replace(s, r"\bcos\(" => "Math.cos(")
    s = replace(s, r"for \(const i of 1:10\)" => "for (let i = 0; i < 10; i++)")
    s = replace(s, r"scheduleTask\(knockback_coroutine\(self\)\s*\n\s*schedule\(self\.knockbackTask\)" =>
        "scheduleTask(() => knockback_coroutine(self))")
    s = replace(s, r"schedule\(self\.knockbackTask\)" => "")
    s = replace(s, r"notifyCondition\(self\.condition\)\) waiting for" => "notifyCondition(self.condition); waiting for")
    s = replace(s, r"\bTask \| null\b" => "unknown")
    s = replace(s, r": Condition\b" => ": unknown")
    s = replace(s, r"@task\s+" => "scheduleTask(() => ")
    s = replace(s, r"\bCondition\s*\(\s*\)" => "new (globalThis as any).JulGame.Condition()")
    s = replace(s, r"\bwait\s*\(\s*self\.condition\s*\)" => "await waitCondition(self.condition)")
    s = replace(s, r"\byield\s*\(\s*\)" => "await yieldTask()")
    s = replace(s, r"\bnotify\s*\(\s*self\.condition\s*\)" => "notifyCondition(self.condition)")
    s = replace(s, r"\bistaskdone\s*\(\s*self\.knockbackTask\s*\)" => "isTaskDone(self.knockbackTask)")
  s = replace(s, r"(?m)^\s*@testset\b.*$" => "")
    s = replace(s, r"(?m)^\s*@test\b.*$" => "")
    lines = split(s, '\n'; keepempty = true)
    lines = map(lines) do line
        if occursin("scheduleTask(() => knockback_coroutine(self)", line) &&
           !occursin("scheduleTask(() => knockback_coroutine(self))", line)
            return replace(line, "scheduleTask(() => knockback_coroutine(self)" => "scheduleTask(() => knockback_coroutine(self))")
        end
        if occursin("console.log(`freed", line) && occursin("notifyCondition", line)
            return "            notifyCondition(self.condition); console.log('knockback waiting', self.condition)"
        end
        return line
    end
    return join(lines, '\n')
end

"""When a script `include("Easings.jl")`, prepend the easing helpers it calls."""
function prepend_easings_helpers(data::AbstractString, path_jl::AbstractString)::String
    src = read(path_jl, String)
    occursin(r"include\s*\(\s*\"Easings\.jl\"\s*\)", src) || return data
    helpers = """
function ease_out_cubic(x: number): number {
    return 1 - Math.pow(1 - x, 3);
}

"""
    return helpers * String(data)
end

"""Sound filenames referenced in `scripts/*.jl` (e.g. `InternalSoundSource(..., "Jump.wav")`)."""
function collect_script_sound_paths(path_jl::AbstractString, transpiled::AbstractString)::Vector{String}
    paths = Set{String}()
    for m in eachmatch(r"\"([^\"]+\.(?:wav|mp3))\"", read(path_jl, String))
        push!(paths, String(m.captures[1]))
    end
    for m in eachmatch(r"InternalSoundSource\([^)]*\"([^\"]+\.(?:wav|mp3))\"", transpiled)
        push!(paths, String(m.captures[1]))
    end
    return sort!(collect(paths))
end

"""Append `registerScript(...)` and exports for transpiled game scripts."""
function finalize_game_script_ts(data::AbstractString, path_jl::AbstractString, path_ts::AbstractString)::String
    name = game_script_name(path_jl)
    s = strip_script_module_wrapper(data)
    s = apply_game_script_fixups(s, name)
    s = prepend_easings_helpers(s, path_jl)
    init_fn = "JulGame_initialize_$name"
    update_fn = "JulGame_update_$name"
    shutdown_fn = "JulGame_on_shutdown_$name"
    has_init = occursin("function $init_fn", s)
    has_update = occursin("function $update_fn", s)
    has_shutdown = occursin("function $shutdown_fn", s)
    needs_async = occursin("await ", s)
    if needs_async && has_update
        s = replace(s, "function $update_fn(self: $name" => "async function $update_fn(self: $name")
    end
    if needs_async && occursin("function knockback_coroutine", s)
        s = replace(s, "function knockback_coroutine" => "async function knockback_coroutine")
    end
    sound_paths = collect_script_sound_paths(path_jl, s)
    reg = IOBuffer()
    println(reg, script_registry_import_line(path_ts))
    if !isempty(sound_paths)
        println(reg, "import { registerScriptSounds } from \"julgame/src/engine/runtime/scriptRegistry\";")
    end
    if needs_async
        println(reg, "import { isTaskDone, notifyCondition, scheduleTask, waitCondition, yieldTask } from \"julgame/src/engine/runtime/coroutineRuntime\";")
    end
    println(reg, "")
    print(reg, s)
    println(reg, "")
    println(reg, "registerScript(\"$name\", {")
    println(reg, "    create: () => new $name(),")
    has_init && println(reg, "    initialize: $init_fn,")
    has_update && println(reg, "    update: $update_fn,")
    has_shutdown && println(reg, "    onShutdown: $shutdown_fn,")
    println(reg, "});")
    if !isempty(sound_paths)
        println(reg, "registerScriptSounds([$(join(map(p -> "\"$p\"", sound_paths), ", "))]);")
    end
    return String(take!(reg))
end

function postprocess_game_script_ts(data::AbstractString, path_jl::AbstractString, path_ts::AbstractString)::String
    s = finalize_game_script_ts(data, path_jl, path_ts)
    s = insert_semicolon_before_line_starting_with_open_paren(s)
    s = fix_argevent_collision_callbacks(s)
    s = fix_bare_main_identifiers(s)
    s = fix_double_julgame_rewrite(s)
    s = fix_double_main_rewrite(s)
    return s
end

function collect_project_script_files(project_root::AbstractString)::Vector{String}
    scripts_dir = joinpath(abspath(project_root), "scripts")
    isdir(scripts_dir) || return String[]
    out = String[]
    for f in readdir(scripts_dir)
        endswith(f, ".jl") || continue
        path = joinpath(scripts_dir, f)
        text = read(path, String)
        occursin(r"<\s*:\s*Script", text) || continue
        push!(out, path)
    end
    sort!(out)
    return out
end

"""Side-effect barrel: `import "./Foo"` for every transpiled `ts/_generated/scripts/*.ts`."""
function write_scripts_index(project_root::AbstractString)::Union{String, Nothing}
    scripts_out = joinpath(abspath(project_root), "ts", "_generated", "scripts")
    isdir(scripts_out) || return nothing
    stems = String[]
    for f in readdir(scripts_out)
        endswith(f, ".ts") || continue
        stem = splitext(f)[1]
        stem == "index" && continue
        push!(stems, stem)
    end
    isempty(stems) && return nothing
    sort!(stems)
    index_path = joinpath(scripts_out, "index.ts")
    open(index_path, "w") do io
        println(io, "// Auto-generated by tools/convert.jl — registers all transpiled game scripts.")
        for stem in stems
            println(io, "import \"./$stem\";")
        end
    end
    return index_path
end
