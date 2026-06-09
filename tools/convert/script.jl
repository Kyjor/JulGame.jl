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
        return "import { registerScript, registerSupportModule } from \"julgame/src/engine/runtime/scriptRegistry\";"
    end
    return "import { registerScript, registerSupportModule } from \"$rel\";"
end

"""Engine-wide includes skipped during inline expansion (ported to shared TS)."""
const DEFAULT_SKIP_GAME_SCRIPT_INLINE = Set(["Easings.jl"])

function game_project_root_from_script(path_jl::AbstractString)::Union{String, Nothing}
    norm = replace(normpath(String(path_jl)), '\\' => '/')
    m = match(r"^(.+)/scripts/", norm)
    m === nothing && return nothing
    return normpath(String(m.captures[1]))
end

"""Load optional `tools/transpile_project.jl` for per-game transpile hooks."""
function load_transpile_project_module(project_root::AbstractString)
    hook = joinpath(abspath(project_root), "tools", "transpile_project.jl")
    isfile(hook) || return nothing
    mod = Module()
    Base.include(mod, hook)
    return mod
end

const _PROJECT_TRANSPILE_SET_CACHE = Dict{String, Set{String}}()

function clear_project_transpile_cache!()
    empty!(_PROJECT_TRANSPILE_SET_CACHE)
end

"""Julia `module FooModule` name from source (before strip)."""
function parse_julia_module_name(text::AbstractString)::Union{Nothing, String}
    for line in split(String(text), '\n')
        m = match(r"^\s*module\s+(\w+Module)\s*$", strip(line))
        m !== nothing && return String(m.captures[1])
    end
    m = match(r"module\s+(\w+Module)", text)
    m === nothing && return nothing
    return String(m.captures[1])
end

"""Symbols listed on Julia `export` lines."""
function parse_julia_exports(text::AbstractString)::Vector{String}
    out = String[]
    for line in split(String(text), '\n')
        m = match(r"^\s*export\s+(.+)$", strip(line))
        m === nothing && continue
        body = strip(String(m.captures[1]))
        for part in split(body, ',')
            sym = strip(first(split(strip(part), r"\s*(#|$)")))
            isempty(sym) && continue
            push!(out, sym)
        end
    end
    return out
end

function has_script_lifecycle(text::AbstractString, path_jl::AbstractString)::Bool
    occursin(r"<\s*:\s*Script", text) || is_initialize_script_file(path_jl)
end

"""`:script`, `:support`, or `:dual` — drives registerScript vs registerSupportModule."""
function classify_script_file(path_jl::AbstractString)::Symbol
    text = read(path_jl, String)
    has_module = parse_julia_module_name(text) !== nothing
    has_script = has_script_lifecycle(text, path_jl)
    if has_script && has_module
        return :dual
    elseif has_script
        return :script
    elseif has_module
        return :support
    end
    return :script
end

function collect_included_script_paths(text::AbstractString, base_dir::AbstractString)::Vector{String}
    out = String[]
    for m in eachmatch(r"include\s*\(\s*\"([^\"]+)\"\s*\)", text)
        rel = String(m.captures[1])
        inc = isabspath(rel) ? rel : joinpath(base_dir, rel)
        isfile(inc) && push!(out, abspath(inc))
    end
    return out
end

function collect_nested_include_scripts(project_root::AbstractString, seeds::Vector{String})::Vector{String}
    out = Set{String}()
    queue = copy(seeds)
    seen = Set{String}()
    while !isempty(queue)
        path = popfirst!(queue)
        path in seen && continue
        push!(seen, path)
        text = read(path, String)
        for inc in collect_included_script_paths(text, dirname(path))
            push!(out, inc)
            inc in seen || push!(queue, inc)
        end
    end
    return sort!(collect(out))
end

function game_script_ts_path(path_jl::AbstractString, project_root::AbstractString)::String
    scripts_dir = joinpath(abspath(project_root), "scripts")
    rel = replace(relpath(abspath(path_jl), scripts_dir), '\\' => '/')
    stem = splitext(rel)[1]
    return joinpath(abspath(project_root), "ts", "_generated", "scripts", stem * ".ts")
end

function ts_import_path_from_jl(
    from_jl::AbstractString,
    to_jl::AbstractString,
    project_root::AbstractString,
)::String
    from_ts = game_script_ts_path(from_jl, project_root)
    to_ts = game_script_ts_path(to_jl, project_root)
    rel = replace(relpath(to_ts, dirname(from_ts)), '\\' => '/')
    rel = replace(rel, r"\.ts$" => "")
    startswith(rel, ".") || (rel = "./" * rel)
    return rel
end

function get_project_transpile_set(project_root::AbstractString)::Set{String}
    key = abspath(project_root)
    if haskey(_PROJECT_TRANSPILE_SET_CACHE, key)
        return _PROJECT_TRANSPILE_SET_CACHE[key]
    end
    files = Set(collect_project_script_files(project_root))
    _PROJECT_TRANSPILE_SET_CACHE[key] = files
    return files
end

"""Merge engine defaults with project `SKIP_GAME_SCRIPT_INLINE` / `skip_game_script_inline()`."""
function skip_game_script_inline_files(path_jl::AbstractString)::Set{String}
    skip = copy(DEFAULT_SKIP_GAME_SCRIPT_INLINE)
    root = game_project_root_from_script(path_jl)
    root === nothing && return skip
    mod = load_transpile_project_module(root)
    mod === nothing && return skip
    if isdefined(mod, :SKIP_GAME_SCRIPT_INLINE)
        union!(skip, getfield(mod, :SKIP_GAME_SCRIPT_INLINE))
    elseif isdefined(mod, :skip_game_script_inline)
        union!(skip, Base.invokelatest(getfield(mod, :skip_game_script_inline)))
    end
    return skip
end

"""Inline `include("foo.jl")` for game scripts before the generic include stripper runs."""
function expand_game_script_includes(data::AbstractString, path_jl::AbstractString)::String
    skip_inline = skip_game_script_inline_files(path_jl)
    base = dirname(abspath(String(path_jl)))
    project_root = game_project_root_from_script(path_jl)
    transpile_set = project_root === nothing ? Set{String}() : get_project_transpile_set(project_root)
    out = String(data)
    for _ in 1:32
        changed = false
        lines = split(out, '\n'; keepempty = true)
        new_lines = String[]
        for line in lines
            m = match(r"^(\s*)include\s*\(\s*\"([^\"]+)\"\s*\)\s*$", line)
            if m === nothing
                push!(new_lines, line)
                continue
            end
            rel = String(m.captures[2])
            inc = isabspath(rel) ? rel : joinpath(base, rel)
            inc_abs = abspath(inc)
            if isfile(inc) && basename(inc) in skip_inline
                changed = true
                push!(new_lines, "// skipped include: $rel")
            elseif isfile(inc_abs) && project_root !== nothing && inc_abs in transpile_set
                changed = true
                push!(new_lines, "# transpile-import: $rel")
            elseif isfile(inc)
                changed = true
                push!(new_lines, "// inlined: $rel")
                append!(new_lines, split(expand_game_script_includes(read(inc, String), inc), '\n'; keepempty = true))
            else
                push!(new_lines, line)
            end
        end
        out = join(new_lines, '\n')
        changed || break
    end
    return out
end

"""Script names attached in scene JSON `"scripts": [{ "name": "Foo" }]`."""
function collect_scene_script_names_from_text(text::AbstractString)::Set{String}
    names = Set{String}()
    for m in eachmatch(r"\"scripts\"\s*:\s*\[([\s\S]*?)\]", text)
        block = String(m.captures[1])
        for sm in eachmatch(r"\"name\"\s*:\s*\"([A-Za-z][A-Za-z0-9_]*)\"", block)
            push!(names, String(sm.captures[1]))
        end
    end
    return names
end

"""Script names referenced by one scene JSON (only names with a matching `scripts/*.jl`)."""
function collect_scene_script_names_from_file(
    project_root::AbstractString,
    scene_file::AbstractString,
)::Set{String}
    names = Set{String}()
    path = isabspath(scene_file) ? String(scene_file) :
           joinpath(abspath(project_root), "scenes", String(scene_file))
    isfile(path) || return names
    scripts_dir = joinpath(abspath(project_root), "scripts")
    text = read(path, String)
    for name in collect_scene_script_names_from_text(text)
        isfile(joinpath(scripts_dir, "$(name).jl")) && push!(names, name)
    end
    return names
end

function collect_scene_script_names(project_root::AbstractString)::Set{String}
    names = Set{String}()
    scenes_dir = joinpath(abspath(project_root), "scenes")
    isdir(scenes_dir) || return names
    for f in readdir(scenes_dir)
        endswith(f, ".json") || continue
        occursin("-backup", f) && continue
        try
            union!(names, collect_scene_script_names_from_text(read(joinpath(scenes_dir, f), String)))
        catch
        end
    end
    return names
end

function script_path_for_name(scripts_dir::AbstractString, name::AbstractString)::Union{Nothing, String}
    path = joinpath(scripts_dir, "$(name).jl")
    isfile(path) && return path
    return nothing
end

function is_initialize_script_file(path_jl::AbstractString)::Bool
    text = read(path_jl, String)
    occursin(r"function\s+JulGame\.initialize\s*\(", text) || return false
    base = splitext(basename(String(path_jl)))[1]
    return occursin("mutable struct $base", text) || occursin("struct $base", text)
end

"""Drop broken preamble from heavy `include` inlining before the script's `export class`."""
function strip_broken_transpile_preamble(s::AbstractString)::String
    s = String(s)
    m = match(r"export class \w+", s)
    m === nothing && return s
    preamble = s[1:prevind(s, m.offset)]
    broken = occursin("// inlined:", preamble) ||
             occursin("typeof(", preamble) ||
             occursin("cache_outline", preamble) ||
             occursin(r"\w+\([^)]*\)\s*=\s*\w", preamble)
    broken || return s
    lines = split(s, '\n'; keepempty = true)
    import_lines = String[]
    export_idx = 0
    for (i, line) in enumerate(lines)
        if occursin(r"^\s*export class \w+", line)
            export_idx = i
            break
        elseif occursin(r"^\s*import ", line)
            push!(import_lines, line)
        end
    end
    export_idx > 1 || return s
    return join(vcat(import_lines, "", lines[export_idx:end]), '\n')
end

"""`@enum Foo begin A B end` → TS const + destructuring (Julia 1-based values)."""
function fix_julia_enums(s::AbstractString)::String
    s = String(s)
    while true
        m = match(r"@enum\s+(\w+)\s+begin\s*([\s\S]*?)\n\s*(?:end|\})", s)
        m === nothing && break
        name = m.captures[1]
        members = String[]
        for line in split(strip(m.captures[2]), '\n')
            line = strip(line)
            isempty(line) && continue
            startswith(line, "#") && continue
            tok = strip(first(split(line, r"\s*(#|//)")))
            isempty(tok) && continue
            push!(members, tok)
        end
        enum_entries = join(["    $(mem): $i," for (i, mem) in enumerate(members)], '\n')
        destruct = join(members, ", ")
        replacement = "const $name = {\n$enum_entries\n};\nconst { $destruct } = $name;\n"
        s = replace(s, m.match => replacement, count=1)
    end
    return s
end

function inject_easings_import(s::AbstractString)::String
    s = String(s)
    needs = occursin(r"// skipped include: .*Easings\.jl", s) ||
            occursin(r"ease_(?:in|out|in_out)_", s) ||
            occursin(r"\bease_out_cubic\b", s)
    needs || return s
    import_line = "import { ease_in_out_cubic, ease_out_cubic, ease_in_cubic, linear } from \"julgame/src/engine/runtime/easings\";"
    occursin(r"from \"julgame/src/engine/runtime/easings\"", s) && return s
    # Remove any previously inlined Easings block
    s = replace(s, r"// inlined: utils/Easings\.jl[\s\S]*?(?=export class |const \w+ = \{|@enum )" => "")
    return import_line * "\n" * s
end

function julia_scalar_type_to_ts(name::AbstractString)::String
    n = strip(String(name))
    n == "Int" && return "number"
    n == "Float64" && return "number"
    n == "Float32" && return "number"
    n == "String" && return "string"
    n == "Bool" && return "boolean"
    occursin("[]", n) && return replace(replace(n, "Int" => "number"), "String" => "string")
    return "unknown"
end

function julia_tuple_type_to_ts(inner::AbstractString)::String
    parts = [strip(p) for p in split(String(inner), ',')]
    return "[" * join(julia_scalar_type_to_ts.(parts), ", ") * "]"
end

function regex_map_replace(
    s::AbstractString,
    pattern::Regex,
    f::Function,
)::String
    out = IOBuffer()
    last_end = 1
    for m in eachmatch(pattern, String(s))
        write(out, s[last_end:prevind(s, m.offset)])
        write(out, f(m))
        last_end = m.offset + length(m.match)
    end
    write(out, s[last_end:end])
    return String(take!(out))
end

function ts_replace_list_comp_with_if(m)::String
    expr, var, coll, cond = m.captures
    if strip(expr) == var
        return "$(coll).filter($(var) => $(cond))"
    end
    return "$(coll).filter($(var) => $(cond)).map($(var) => $(expr))"
end

function ts_replace_list_comp(m)::String
    expr, var, coll = m.captures
    if strip(expr) == var
        return coll
    end
    return "$(coll).map($(var) => $(expr))"
end

function ts_replace_sum_comp(m)::String
    expr, var, coll = m.captures
    return "$(coll).reduce((acc, $(var)) => acc + $(expr), 0)"
end

function ts_replace_any_comp(m)::String
    expr, var, coll = m.captures
    expr = replace(expr, r"startswith\((\w+),\s*(\w+)\)" => s"\1.startsWith(\2)")
    return "$(coll).some($(var) => $(expr))"
end

function ts_replace_enumerate_for(m)::String
    i, item, arr = m.captures
    return "for (let $(i) = 1; $(i) <= $(arr).length; $(i)++) { const $(item) = $(arr)[$(i) - 1]"
end

"""Julia `\"prefix_\$var\"` string interpolation → TS template literal."""
function fix_julia_dollar_string_interpolation(s::AbstractString)::String
    out = s
    pat = r"\"([^\"$]*)\$(\w+)([^\"$]*)\""
    while true
        new = regex_map_replace(out, pat, m -> begin
            pre, var, post = m.captures
            "`$(pre)\${$(var)}$(post)`"
        end)
        new == out && break
        out = new
    end
    return out
end

function ts_replace_object_entries_for(m)::String
    k, v, obj = m.captures
    return "for (const [$(k), $(v)] of Object.entries($(obj))) {"
end

function ts_replace_inbounds_for(m)::String
    v, hi = m.captures
    return "for (let $(v) = 0; $(v) < $(hi); $(v)++)"
end

function ts_replace_kwargs_constructor(m)::String
    body, args = m.captures
    body = replace(body, r"(\w+): number = " => s"\1 = ")
    body = replace(body, r"(\w+): boolean = " => s"\1 = ")
    assigns = join(["this.$f = $f;" for f in strip.(split(args, ','))], "\n            ")
    return "constructor($body) {\n            $assigns\n        }"
end

"""Replace `Int(Math.round(expr))` → `Math.round(expr)`; preserves nested parens."""
function replace_int_math_round(s::AbstractString)::String
    needle = "Int(Math.round("
    out = IOBuffer()
    i = firstindex(s)
    while i <= lastindex(s)
        if startswith(@view(s[i:end]), needle)
            j = nextind(s, i, ncodeunits(needle))
            depth = 1
            inner_start = j
            while j <= lastindex(s) && depth > 0
                c = s[j]
                depth += (c == '(') - (c == ')')
                j = nextind(s, j)
            end
            inner = s[inner_start:prevind(s, j)]
            k = j
            if k <= lastindex(s) && s[k] == ')'
                k = nextind(s, k)
            end
            print(out, "Math.round(", inner, ")")
            i = k
        else
            print(out, s[i])
            i = nextind(s, i)
        end
    end
    return String(take!(out))
end

"""Replace `round(Int, expr)` → `Math.round(expr)`; preserves nested parens."""
function replace_round_int_comma(s::AbstractString)::String
    needle = "round(Int, "
    out = IOBuffer()
    i = firstindex(s)
    while i <= lastindex(s)
        if startswith(@view(s[i:end]), needle)
            j = nextind(s, i, ncodeunits(needle))
            depth = 0
            inner_start = j
            while j <= lastindex(s)
                c = s[j]
                if c == '('
                    depth += 1
                elseif c == ')'
                    if depth == 0
                        break
                    end
                    depth -= 1
                end
                j = nextind(s, j)
            end
            inner = s[inner_start:prevind(s, j)]
            print(out, "Math.round(", inner, ")")
            i = nextind(s, j)
        else
            print(out, s[i])
            i = nextind(s, i)
        end
    end
    return String(take!(out))
end

"""Replace `Int32(round(expr))` → `Math.round(expr)`; preserves nested parens."""
function replace_int32_round(s::AbstractString)::String
    needle = "Int32(round("
    out = IOBuffer()
    i = firstindex(s)
    while i <= lastindex(s)
        if startswith(@view(s[i:end]), needle)
            j = nextind(s, i, ncodeunits(needle))
            depth = 1
            inner_start = j
            while j <= lastindex(s) && depth > 0
                c = s[j]
                depth += (c == '(') - (c == ')')
                j = nextind(s, j)
            end
            inner = s[inner_start:prevind(s, j)]
            k = j
            if k <= lastindex(s) && s[k] == ')'
                k = nextind(s, k)
            end
            print(out, "Math.round(", inner, ")")
            i = k
        else
            print(out, s[i])
            i = nextind(s, i)
        end
    end
    return String(take!(out))
end

"""True when the previous line opens or continues a kwargs/object-literal block."""
function in_kwargs_context(prev::AbstractString)::Bool
    isempty(prev) && return false
    endswith(prev, ",") && return true
    return occursin(r",\s*\{?\s*$", prev)
end

"""Undo `let key = expr` mistakenly emitted inside object-literal kwargs."""
function relabel_let_as_kwargs_in_objects(s::AbstractString)::String
    lines = split(String(s), '\n'; keepempty=true)
    out = String[]
    for line in lines
        prev = length(out) > 0 ? strip(out[end]) : ""
        m = match(r"^(\s+)let (\w+) = (.+)$", line)
        if m !== nothing && in_kwargs_context(prev)
            push!(out, "$(m.captures[1])$(m.captures[2]): $(m.captures[3])")
        else
            push!(out, line)
        end
    end
    return join(out, '\n')
end

"""Restore `let x = expr` after kwargs pass wrongly lowered standalone locals to `x: expr`."""
function restore_wrongly_labeled_locals(s::AbstractString)::String
    lines = split(String(s), '\n'; keepempty=true)
    out = String[]
    for line in lines
        m = match(r"^(\s+)([a-zA-Z_]\w*): (.+)$", line)
        if m !== nothing
            prev = length(out) > 0 ? strip(out[end]) : ""
            in_kwargs = in_kwargs_context(prev)
            val = strip(m.captures[3])
            if in_kwargs && (
                endswith(val, ",") ||
                startswith(val, "{") || startswith(val, "[") ||
                occursin(r"^[\"']", val) ||
                occursin(r"^(true|false|null|-?\d)", val) ||
                occursin(r"^\(\)\s*=>", val)
            )
                push!(out, line)
                continue
            end
            if !in_kwargs && endswith(val, ",")
                push!(out, line)
                continue
            end
            rhs = val
            if startswith(rhs, "globals.") ||
               startswith(rhs, "self.") ||
               startswith(rhs, "(globalThis as any)") ||
               occursin(r"^\(\)\s*=>", rhs) ||
               occursin(r"^\w+\(", rhs)
                push!(out, "$(m.captures[1])let $(m.captures[2]) = $(m.captures[3])")
                continue
            end
        end
        push!(out, line)
    end
    return join(out, '\n')
end

"""Replace `Int(round(expr))` → `Math.round(expr)`; preserves nested parens."""
function replace_int_round(s::AbstractString)::String
    needle = "Int(round("
    out = IOBuffer()
    i = firstindex(s)
    while i <= lastindex(s)
        if startswith(@view(s[i:end]), needle)
            j = nextind(s, i, ncodeunits(needle))
            depth = 1
            inner_start = j
            while j <= lastindex(s) && depth > 0
                c = s[j]
                depth += (c == '(') - (c == ')')
                j = nextind(s, j)
            end
            inner = s[inner_start:prevind(s, j)]
            k = j
            if k <= lastindex(s) && s[k] == ')'
                k = nextind(s, k)
            end
            print(out, "Math.round(", inner, ")")
            i = k
        else
            print(out, s[i])
            i = nextind(s, i)
        end
    end
    return String(take!(out))
end

function replace_julia_round_calls(s::AbstractString)::String
    s = replace_int_math_round(s)
    s = replace_int_round(s)
    s = replace_round_int_comma(s)
    s = replace_int32_round(s)
    return s
end

"""`function f({ this: T, ...; kw... })` / Julia kwargs-on-functions → valid TS."""
function fix_mangled_julia_function_signatures(s::AbstractString)::String
    s = String(s)
    s = replace(s, r"Function\[(\w+)\]" => s"[\1]")
    s = replace(s, r": \(\) => void\[(\w+)\]" => s": [\1]")
    s = replace(s, r": \(x: number\) => number" => ": () => void")
    s = replace(s, r": null \| Function\b" => ": (() => void) | null")
    s = replace(s, r": Function\b" => ": () => void")
    s = replace(s, r": String," => ": string,")
    s = replace(s, r": String =" => ": string =")
    s = replace(s, r": String\)" => ": string)")
    s = replace(s, r"function (\w+)\(\{\s*\n\s*this: (\w+)," => s"function \1(self: \2,")
    s = replace(s, r"const on_confirm = \(\) => void," => "on_confirm: () => void,")
    s = replace(
        s,
        r",\s*\n\s*\{\s*\n+\s*confirm_text: string = ([^,\n]+),\s*\n\s*cancel_text: string = ([^,\n]+),\s*\n\s*layer: number = (\d+)\s*\n\s*\}\)\n(\s+)self\." =>
            SubstitutionString(
                ", kwargs: { confirm_text?: string; cancel_text?: string; layer?: number } = {})\n{\n\\4const confirm_text = kwargs.confirm_text ?? \\1;\n\\4const cancel_text = kwargs.cancel_text ?? \\2;\n\\4const layer = kwargs.layer ?? \\3;\n\\4self.",
            ),
    )
    s = replace(s, r"\): boolean \{ \{" => "): boolean {")
    s = replace(s, r"\): string \{ \{" => "): string {")
    return s
end

"""Julia file/JSON IO → web pref helpers."""
function fix_julia_file_io_residuals(s::AbstractString)::String
    s = String(s)
    s = replace(
        s,
        r"(\n\s+)data: JSON3\.read\(([^)]+)\)" =>
            s"\1const data = JSON.parse((globalThis as any).JulGame.PrefHandlerModule?.read_text?.(\2) ?? \"{}\")",
    )
    s = replace(
        s,
        r"(\n\s+)data: JSON\.parse\(\(globalThis as any\)\.JulGame\.PrefHandlerModule\?\.read_text\?\.\(([^)]+)\)\s*$"m =>
            s"\1const data = JSON.parse((globalThis as any).JulGame.PrefHandlerModule?.read_text?.(\2) ?? \"{}\")",
    )
    s = replace(
        s,
        r"open\(([^,]+), \"([^\"]+)\"\) do \w+\n\s+JSON3\.write\(\w+, ([^\)]+)\)\n\s+\}" =>
            s"(globalThis as any).JulGame.PrefHandlerModule?.write_text?.(\1, JSON.stringify(\3))",
    )
    return s
end

"""Lower remaining Julia syntax that blocks TS parsing."""
function fix_julia_typescript_residual_syntax(s::AbstractString)::String
    s = String(s)
    s = regex_map_replace(s, r"Tuple\{([^}]+)\}", m -> julia_tuple_type_to_ts(m.captures[1]))
    s = regex_map_replace(
        s,
        r"Set\{([^}]+)\}",
        m -> "<" * julia_scalar_type_to_ts(m.captures[1]) * ">",
    )
    s = replace(s, r" &&\)" => ")")
    s = replace(s, r" &&\s*\{" => " {")
    s = replace(s, r" &&\s*;" => ";")
    s = replace(s, r"Record<\[[^\]]+\], " => "Record<string, ")
    s = regex_map_replace(s, r"\[([^\[\]]+?) for (\w+) in ([^\[\]]+?) if ([^\[\]]+?)\]", ts_replace_list_comp_with_if)
    s = regex_map_replace(s, r"\[([^\[\]]+?) for (\w+) in ([^\[\]]+?)\]", ts_replace_list_comp)
    s = regex_map_replace(s, r"sum\(([^)]+?) for (\w+) in (\w+)\)", ts_replace_sum_comp)
    s = replace(
        s,
        r"any\(key\.startsWith\((\w+)\) for \1 in (\w+)\)" =>
            s"\2.some(\1 => key.startsWith(\1))",
    )
    s = regex_map_replace(s, r"any\(([^)]+?) for (\w+) in (\w+)\)", ts_replace_any_comp)
    s = regex_map_replace(s, r"for \((\w+), (\w+)\) in enumerate\(([^)]+)\)", ts_replace_enumerate_for)
    s = regex_map_replace(s, r"for \((\w+), (\w+)\) in (\w+)\b", ts_replace_object_entries_for)
    s = regex_map_replace(s, r"@inbounds for (\w+) in 0:\((\w+)-1\)", ts_replace_inbounds_for)
    s = replace(s, r"\bgetfield\((\w+),\s*(\w+)\)" => s"\1[\2]")
    s = replace(s, r"let (\w+) = ([\d.]+)f0," => s"const \1 = \2;")
    s = replace(s, r"(\w+): boolean = (true|false)," => s"const \1 = \2;")
    s = replace(s, r"(\w+): number = (\d+)," => s"const \1 = \2;")
    s = regex_map_replace(
        s,
        r"constructor\(\;\) \{([\s\S]*?)\)\s*new\(([^)]+)\)\s*\}",
        ts_replace_kwargs_constructor,
    )
    s = replace(s, r"constructor\(\;\) \{" => "constructor() {")
    s = replace(s, r": \(x: number\) => number" => ": () => void")
    s = replace(s, r": null \| Function\b" => ": (() => void) | null")
    s = replace(s, r": Function\b" => ": () => void")
    s = replace(s, r"\bstartswith\((\w+),\s*(\w+)\)" => s"\1.startsWith(\2)")
    s = replace(s, r"get\(ENV,\s*\"([^\"]+)\",\s*\"([^\"]*)\"\)" => s"\"\2\"")
    s = replace(s, r"([\d.]+)f0\b" => s"\1")
    s = replace(s, r": UIElement\[\]" => ": any[]")
    s = replace(s, r": null \| UIElement\b" => ": any")
    s = replace(s, r": UIElement\b" => ": any")
    s = replace(s, r"\bVector2\b" => "{ x: number; y: number }")
    s = replace(s, "Any[" => "[")
    s = replace(s, r", (\w+): boolean = (true|false)" => s", \1 = \2")
    s = replace(s, r", (\w+): number = ([\d.]+)" => s", \1 = \2")
    s = replace(s, r"(\w+)=([\d.]+)f0\b" => s"\1=\2")
    s = replace(s, r"(?m)^(\s+)end\)" => s"\1})")
    s = replace(s, r"(?m)^(\s+)end;" => s"\1};")
    s = replace(s, r"\(\) -> " => "() => ")
    s = replace(s, r"=> begin" => "=> {")
    s = replace(s, r"function (\w+)\(x: number\) :: number\n" => s"function \1(x: number): number {\n")
    s = replace(s, r"\"([^\"]+)\" => \"([^\"]+)\"" => s"\"\1\": \"\2\"")
    s = replace(s, r"Dict\(\"([^\"]+)\" => ([^)]+)\)" => s"{ \"\1\": \2 }")
    s = regex_map_replace(s, r"return Dict\(([\s\S]*?)\n\s*\)", ts_replace_return_dict)
    s = replace(s, r"const null = Ptr\{[^}]+\}\(0\)" => "const _null_ptr = null")
    s = replace(s, r"Ptr\{[^}]+\}" => "any")
    s = replace(s, r"Ref\{[^}]+\}\(0\)" => "{ value: 0 }")
    s = replace(s, r"convert\(Ptr\{[^}]+\}," => "/* convert ptr */ (")
    s = regex_map_replace(s, r"\$\(([^)]+)\)", m -> "`\${" * m.captures[1] * "}`")
    s = regex_map_replace(s, r"\"\$\(([^)]+)\)\"", m -> "`\${" * m.captures[1] * "}`")
    s = fix_julia_dollar_string_interpolation(s)
    s = replace(
        s,
        r"\? \((\d+), (\d+), (\d+), (\d+)\) : \((\d+), (\d+), (\d+), (\d+)\)" =>
            s"? [\1, \2, \3, \4] : [\5, \6, \7, \8]",
    )
    s = replace(s, r"^(\s+)(\w+), (\w+) = ([^\n]+)$"m => s"\1const [\2, \3] = \4")
    s = replace(s, r" ÷ " => " / ")
    s = replace(s, r"÷" => "/")
    s = replace(s, r"(\w+) \^ (\d+)" => s"\1 ** \2")
    s = replace(s, r"(\w+)\^(\d+)" => s"\1 ** \2")
    s = replace(s, r"(\w+);\s*\n(\s+)let " => s"\1, {\n\2")
    s = replace(s, r",\s*\n(\s+)let (\w+) = " => s",\n\1\2: ")
    s = replace(s, r"\n(\s+)let (\w+) = " => s"\n\1\2: ")
    s = replace(s, r",\s*\n(\s+)\)" => s" }\n\1)")
    while occursin(r"\n\s+\w+ = [^,\n]+,", s)
        s = replace(s, r"(\n\s+)(\w+) = ([^,\n]+,)" => s"\1\2: \3")
    end
    s = replace(s, r"\}\s*\n(\s+)\)" => s"})\n\1")
    s = replace(
        s,
        r"((?:const \w+ = [^;]+;\s*)+)(\w+): number = (\d+)\s*\n\s+\)\s*\n(\s+)this\." =>
            s"\1const \2 = \3;\n\4this.",
    )
    s = replace(s, r" (\w+) isa \(([^)]+)\)" => s" \1 instanceof (\2)")
    s = replace(s, r" (\w+) isa (\w+)\b" => s" \1 instanceof \2")
    s = replace(s, r"(\w+) isa NamedTuple \? \1\.(\w+) : getproperty\(\1, \"(\w+)\"\)" => s"\1.\2")
    s = replace(s, r" -> begin" => " => {")
    s = replace(s, r"\[([^,\]]+), ([^\]]+)\] -> begin" => s"(\1, \2) => {")
    s = replace(s, r"\) -> (\w+)\n" => s"): \1\n")
    s = replace(
        s,
        r"(function \w+\([^)]*\)(?:: [^\n]+)?)\n(?!\s*\{)(\s+)(\w+): " =>
            s"\1 {\n\2let \3 = ",
    )
    s = replace(s, r"unsafe_string\(" => "String(")
    s = replace(s, r"(\n\s+)(\w+): (globals\.)" => s"\1let \2 = \3")
    s = replace(
        s,
        r"(\n\s+)(\w+): \(globalThis as any\)\.JulGame" =>
            s"\1let \2 = (globalThis as any).JulGame",
    )
    s = replace(
        s,
        r"(\n\s+)(\w+) = \(globalThis as any\)\.JulGame" =>
            s"\1let \2 = (globalThis as any).JulGame",
    )
    s = replace(s, r"`\";\n(\s+)(\w+):" => s"\",\n\1\2:")
    s = replace(s, r"\): boolean \{ \{" => "): boolean {")
    s = replace(
        s,
        r"(function \w+\([^)]*\)(?:: [^\n]+)?)(?<!\{)\n(?!\s*\{)(\s+)(return\b)" =>
            s"\1 {\n\2\3",
    )
    s = replace(s, r"\): boolean \{ \{" => "): boolean {")
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGame\.\(globalThis as any\)\.JulGameSdl" =>
            "(globalThis as any).JulGameSdl",
    )
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGameSdl\.glue_SDL_OpenURL\(" =>
            "window.open(",
    )
    s = replace(s, r"window\.open\(String\((\"[^\"]+\")\)" => s"window.open(\1)")
    s = regex_map_replace(s, r"Vector\{([^}]+)\}", m -> julia_scalar_type_to_ts(m.captures[1]) * "[]")
    s = replace(s, r"constructor\(\;\) \{" => "constructor() {")
    s = replace(s, r"// Easing functions[\s\S]*?(?=\n\s*(?:export class |class \w+|function JulGame_))" => "")
    s = replace(s, r"contains\(([^,]+),\s*([^)]+)\)" => s"\1.includes(\2)")
    s = replace(s, "| null { {" => "| null {")
    s = replace(s, r"occursin\(\"([^\"]+)\",\s*([^)]+)\)" => s"\2.includes(\"\1\")")
    s = replace(s, r"split\(([^,]+),\s*\"([^\"]+)\"\)\[1\]" => s"\1.split(\"\2\")[0]")
    s = replace_julia_round_calls(s)
    s = replace(s, r"\bInt\(" => "Math.trunc(")
    # Julia kwargs / object fields — run after function-body `let` fixups above
    s = replace(s, r"from \"julgame/src/engine/runtime/easings\",\n" => "from \"julgame/src/engine/runtime/easings\";\n")
    s = replace(
        s,
        r"\"([^\"]+)\";\n(\s+)(fontSize|anchor|anchorOffset|color|layer|parent|position:|size:|let )" =>
            s"\"\1\",\n\2\3",
    )
    s = replace(
        s,
        r",\n(\s+)let (\w+) = \(globalThis as any\)\.JulGame" =>
            s",\n\1\2: (globalThis as any).JulGame",
    )
    s = replace(
        s,
        r"\n(\s+)let (\w+) = \(globalThis as any\)\.JulGame\.(\w+Module\.[A-Z_]+)\s*\}\)" =>
            s"\n\1\2: (globalThis as any).JulGame.\3 })",
    )
    s = replace(s, r"(\n\s+)let (\w+) = (\w+),\n" => s"\1\2: \3,\n")
    s = replace(s, r"(\n\s+)let (\w+) = (\{[^}]+\}),\n" => s"\1\2: \3,\n")
    s = restore_wrongly_labeled_locals(s)
    s = relabel_let_as_kwargs_in_objects(s)
    s = fix_julia_format_string_helper(s)
    return s
end

function ts_replace_return_dict(m)::String
    inner = String(m.captures[1])
    inner = replace(inner, r"\"([^\"]+)\" => \"([^\"]+)\"" => s"\"\1\": \"\2\"")
    inner = replace(inner, r"\"([^\"]+)\" => ([\w.:\"]+)" => s"\"\1\": \2")
    return "return {\n" * inner * "\n    }"
end

"""Module-level script functions use `self`; Julia `this` in those bodies should become `self`."""
function fix_this_to_self_in_script_functions(s::AbstractString)::String
    s = replace(String(s), "this." => "self.")
    s = replace(s, r"\(this," => "(self,")
    s = replace(s, r"\(this\)" => "(self)")
    s = replace(s, r", this\)" => ", self)")
    s = replace(s, r", this," => ", self,")
    return regex_map_replace(
        s,
        r"constructor\(\) \{([\s\S]*?)\n        \}\n    \}",
        m -> "constructor() {" * replace(m.captures[1], "self." => "this.") * "\n        }\n    }",
    )
end

function fix_multiline_dict_literals(s::AbstractString)::String
    s = String(s)
    while true
        m = match(r"Dict\(\s*\n", s)
        m === nothing && break
        start = m.offset
        depth = 1
        i = start + length(m.match)
        while i <= lastindex(s) && depth > 0
            c = s[i]
            if c == '('
                depth += 1
            elseif c == ')'
                depth -= 1
            end
            i = nextind(s, i)
        end
        depth != 0 && break
        inner = s[start + length("Dict("):prevind(s, i)]
        inner = regex_map_replace(inner, r":(\w+) => ", m -> string("\"", m.captures[1], "\": "))
        inner = regex_map_replace(inner, r"\"([^\"]+)\" => ", m -> string("\"", m.captures[1], "\": "))
        inner = regex_map_replace(inner, r"(\w+) => ", m -> string(m.captures[1], ": "))
        s = s[1:prevind(s, start)] * "{" * inner * "}" * s[i:end]
    end
    return s
end

"""`Foo(speed: 1.5, ...)` Julia keyword ctor → `Foo({ speed: 1.5, ... })`."""
function fix_julia_keyword_ctor_calls(s::AbstractString)::String
    s = String(s)
    s = replace(s, r"(\w+)\(\s*\n(\s+\w+:)" => s"\1({\n\2")
    s = replace(s, r"(\n\s+\w+: [^\n]+,?\s*)\n(\s+)\)(?!\))" => s"\1\n\2})")
    s = replace(s, r"\breturn (\w+)\(\{" => s"return new \1({")
    s = replace(
        s,
        r"return (\w+)\(\s*\n(\s+\w+:)" =>
            s"return new \1({\n\2",
    )
    return s
end

function fix_malformed_kwargs_constructor(s::AbstractString)::String
    return regex_map_replace(
        s,
        r"constructor\(\) \{\n((?:\s+\w+:[^\n]+\n)+)\s*\}\)\s*\n+(\s+this\.)"m,
        m -> begin
            params = replace(String(m.captures[1]), r"(\w+): (?:number|boolean) = " => s"\1 = ")
            "constructor({\n$params    }) {\n$(m.captures[2])"
        end,
    )
end

"""`*_STRINGS` dict paired with `format_string` in localization modules."""
function localization_strings_dict_name(s::AbstractString)::Union{Nothing, String}
    for m in eachmatch(r"export\s+(?:\w+,\s*)*(\w+_STRINGS)", s)
        return String(m.captures[1])
    end
    m = match(r"\b(\w+_STRINGS)\s*[=:]", s)
    m === nothing && return nothing
    return String(m.captures[1])
end

function fix_julia_format_string_helper(s::AbstractString)::String
    occursin("function format_string", s) || return String(s)
    s = String(s)
    dict = localization_strings_dict_name(s)
    dict === nothing && return s
    occursin("str = str.replace(`{\${k}}`", s) && return s
    body = """function format_string(key: string, kwargs: Record<string, unknown> = {}) {
    let str = $dict[key as keyof typeof $dict];
    for (const [k, v] of Object.entries(kwargs)) {
        str = str.replace(`{\${k}}`, String(v));
    }
    return str;
}"""
    pat = r"function format_string\([^)]*\) \{[\s\S]*?return str;?\n\}"
    if occursin("str: $dict", s) || occursin("replace(str,", s)
        return replace(s, pat => body)
    end
    next = replace(s, pat => body)
    return next != s ? next : s
end

function script_includes_file(path_jl::AbstractString, include_name::AbstractString)::Bool
    occursin("include(\"$include_name\")", read(path_jl, String)) ||
        occursin("include(\"utils/$include_name\")", read(path_jl, String)) ||
        occursin("include(\"localization/$include_name\")", read(path_jl, String))
end

"""Module names from `include()` targets transpiled as separate `JulGame.Scripts.*` support modules."""
function collect_external_support_module_names(path_jl::AbstractString)::Vector{String}
    path_jl = String(path_jl)
    (isempty(path_jl) || !isfile(path_jl)) && return String[]
    base = dirname(abspath(path_jl))
    skip_inline = skip_game_script_inline_files(path_jl)
    project_root = game_project_root_from_script(path_jl)
    transpile_set = project_root === nothing ? Set{String}() : get_project_transpile_set(project_root)
    names = String[]
    for m in eachmatch(r"include\s*\(\s*\"([^\"]+)\"\s*\)", read(path_jl, String))
        rel = String(m.captures[1])
        inc_abs = abspath(isabspath(rel) ? rel : joinpath(base, rel))
        isfile(inc_abs) || continue
        basename(inc_abs) in skip_inline || inc_abs in transpile_set || continue
        mod = parse_julia_module_name(read(inc_abs, String))
        mod === nothing && continue
        push!(names, mod)
    end
    return unique(names)
end

"""TS stems for separately transpiled `include()` targets (e.g. Acknowledgments.jl → `"Acknowledgments"`)."""
function collect_external_support_stems(path_jl::AbstractString, scripts_out::AbstractString)::Vector{String}
    path_jl = String(path_jl)
    (isempty(path_jl) || !isfile(path_jl)) && return String[]
    base = dirname(abspath(path_jl))
    skip_inline = skip_game_script_inline_files(path_jl)
    project_root = game_project_root_from_script(path_jl)
    transpile_set = project_root === nothing ? Set{String}() : get_project_transpile_set(project_root)
    stems = String[]
    for m in eachmatch(r"include\s*\(\s*\"([^\"]+)\"\s*\)", read(path_jl, String))
        rel = String(m.captures[1])
        inc_abs = abspath(isabspath(rel) ? rel : joinpath(base, rel))
        isfile(inc_abs) || continue
        basename(inc_abs) in skip_inline || inc_abs in transpile_set || continue
        stem = splitext(basename(inc_abs))[1]
        isfile(joinpath(scripts_out, stem * ".ts")) && push!(stems, stem)
    end
    return unique(stems)
end

"""Module names that get `import * as FooModule from "./..."` (not `JulGame.Scripts` registry)."""
function esm_import_module_names(path_jl::AbstractString)::Set{String}
    names = Set{String}()
    for line in collect_transpile_imports(path_jl)
        m = match(r"import \* as (\w+) from", line)
        m === nothing && continue
        push!(names, String(m.captures[1]))
    end
    return names
end

"""Use ESM `FooModule.*` when the file imports it — module-level inits run before registry is reliable."""
function prefer_esm_import_over_scripts_registry(s::AbstractString, path_jl::AbstractString)::String
    for mod in esm_import_module_names(path_jl)
        pat = Regex("\\(globalThis as any\\)\\.JulGame\\.Scripts\\." * mod * "\\.")
        s = replace(s, pat => "$mod.")
    end
    return s
end

"""Bare `FooModule.bar` from skipped/transpile includes → `(globalThis as any).JulGame.Scripts.FooModule.bar`."""
function rewrite_external_support_module_refs(s::AbstractString, path_jl::AbstractString)::String
    imported = Set{String}()
    for m in eachmatch(r"import \* as (\w+) from", s)
        push!(imported, String(m.captures[1]))
    end
    esm = esm_import_module_names(path_jl)
    for mod in collect_external_support_module_names(path_jl)
        (mod in imported || mod in esm) && continue
        pat = Regex("(?<!Scripts\\.)\\b" * mod * "\\.")
        s = replace(s, pat => "(globalThis as any).JulGame.Scripts.$mod.")
    end
    return s
end

function fix_transpiled_include_call_syntax(
    s::AbstractString,
    path_jl::AbstractString,
)::String
    if script_includes_file(path_jl, "UIFloatingAnimation.jl")
        s = regex_map_replace(
            s,
            r"UIFloatingAnimation\(\s*\n(\s+speed:)",
            m -> "new UIFloatingAnimationModule.UIFloatingAnimation({\n$(m.captures[1])",
        )
        s = regex_map_replace(
            s,
            r"(\n\s+rotationAmplitude: [^\n]+)\n(\s+)\)(?!\))",
            m -> "$(m.captures[1])\n$(m.captures[2])})",
        )
    end
    return s
end

"""Julia `f(pos; kw=1)` / `f(pos, kw=1)` → TS `f(pos, { kw: 1 })`."""
function fix_julia_semicolon_kwargs_calls(s::AbstractString)::String
    patterns = (
        r"(\])\;\n(\s+)(\w+:)" => s"\1,\n\2{\n\2\3",
        r"(\w+);(\n\s+)(\w+:)" => s"\1,\n\2{\n\2\3",
        r"(\"[^\"]*\");(\n\s+)(\w+:)" => s"\1,\n\2{\n\2\3",
        r"(?<!: )(\"[^\"]*\"),\n(\s+)(\w+:)" => s"\1,\n\2{\n\2\3",
        r"\);(\n\s+)(\w+:)" => s"),\n\1{\n\1\2",
    )
    for _ in 1:32
        changed = false
        for (pat, rep) in patterns
            next = replace(String(s), pat => rep)
            if next != s
                s = next
                changed = true
            end
        end
        changed || break
    end
    s = replace(s, r"(\n\s+)lifetime = ([^,\n]+)\s*\}\)" => s"\1lifetime: \2 })")
    s = replace(s, r"\[;" => "[")
    return s
end

function apply_generic_game_script_fixups(s::AbstractString)::String
    s = replace(String(s), "C_NULL" => "null")
    s = replace(s, r"JulGame\.UserGlobals\[\"Module\"\]" => "(globalThis as any).JulGame.UserGlobals.Module")
    s = replace(s, r"(?<!\(globalThis as any\)\.)JulGame\.UserGlobals\[" => "(globalThis as any).JulGame.UserGlobals[")
    s = replace(s, r"\bFloat64\b" => "number")
    s = replace(s, r"\bInt64\b" => "number")
    s = replace(s, r"\bBool\b" => "boolean")
    s = replace(s, r"\bUnion\{Nothing,\s*([^}]+)\}" => s"\1 | null")
    s = replace(s, r"Scripts\.(\w+)Module\." => s"(globalThis as any).JulGame.Scripts.\1Module.")
    s = replace(s, r"\bMath\.Vector2\(([^,]+),\s*([^)]+)\)" => s"{x: \1, y: \2}")
    s = replace(s, r"JulGame\.UI\.add_click_event" => "(globalThis as any).JulGame.UI.add_click_event")
    s = replace(s, r"JulGame\.UI\.add_hover_enter_event" => "(globalThis as any).JulGame.UI.add_hover_enter_event")
    s = replace(s, r"JulGame\.UI\.add_hover_exit_event" => "(globalThis as any).JulGame.UI.add_hover_exit_event")
    s = replace(s, r"JulGame\.UI\.align_to_anchor" => "(globalThis as any).JulGame.UI.align_to_anchor")
    s = replace(s, r"JulGame\.UI\.set_color" => "(globalThis as any).JulGame.UI.set_color")
    s = replace(s, r"JulGame\.UI\.duplicate" => "(globalThis as any).JulGame.UI.duplicate")
    s = replace(s, r"JulGame\.UI\.initialize" => "(globalThis as any).JulGame.UI.initialize")
    s = replace(
        s,
        r"JulGame\.UI\.set_color\(([^,]+);\s*a\s*=\s*([^)]+)\)" =>
            s"(globalThis as any).JulGame.UI.set_color(\1, \1.color[0], \1.color[1], \1.color[2], \2)",
    )
    s = replace(s, r"JulGame\.ImmediateUIModule\." => "(globalThis as any).JulGame.ImmediateUIModule.")
    s = replace(s, r"JulGame\.SceneModule\." => "(globalThis as any).JulGame.SceneModule.")
    # `using JulGame.ImmediateUIModule` → bare `ImmediateUIModule.foo` in transpiled bodies
    s = replace(s, r"(?<!JulGame\.)\bImmediateUIModule\." => "(globalThis as any).JulGame.ImmediateUIModule.")
    s = replace(s, r"(?<!JulGame\.)\bSceneModule\." => "(globalThis as any).JulGame.SceneModule.")
    s = replace(s, r"(?<!JulGame\.)\bPrefHandlerModule\." => "(globalThis as any).JulGame.PrefHandlerModule.")
    s = replace(s, r"JulGame\.SDL2\.SDL_OpenURL\(" => "window.open(String(")
    s = replace(s, r"SDL2\.SDL_OpenURL\(" => "window.open(String(")
    s = replace(s, r"@debug\b" => "// @debug")
    s = replace(s, r"@warn\b" => "console.warn")
    s = replace(s, r"@error\b" => "console.error")
    s = replace(s, r"\(\)\s*->\s*begin" => "() => {")
    s = replace(s, r"\bDict\(\)" => "new Map()")
    s = fix_multiline_dict_literals(s)
    s = fix_julia_keyword_ctor_calls(s)
    s = fix_malformed_kwargs_constructor(s)
    s = fix_julia_semicolon_kwargs_calls(s)
    s = replace(s, r"\)\}(\n)" => s"}\1")
    s = replace(s, r"\)\}," => "},")
    s = replace(s, r"(\d)π\b" => s"\1 * Math.PI")
    s = replace(s, r"\bπ\b" => "Math.PI")
    s = replace(s, r"(?<![.\w])\bsin\(" => "Math.sin(")
    s = replace(s, r"(?<![.\w])\bcos\(" => "Math.cos(")
    s = replace(s, r"(?<![.\w])\bsqrt\(" => "Math.sqrt(")
    s = replace(s, r"(\w+)\^(\d+)" => s"\1 ** \2")
    s = replace(s, r"(\bself\.\w+) \|\| return\b" => s"if (!\1) return")
    s = replace(s, r"(\n\s+)(.+?) && return\b" => s"\1if (\2) return")
    # Julia early-return chains mangled into `{ return if (...) ... }` (match inner block only — outer `if` may contain nested parens).
    s = replace(
        s,
        r"\{ return if \(([^)]+)\) \{ \}\s*\n\s+return\s*\n\s+\}" =>
            SubstitutionString("return\n        if (\\1) return\n    "),
    )
    s = replace(
        s,
        r"\{ return if \(([^)]+)\) return \}" =>
            SubstitutionString("return\n        if (\\1) return"),
    )
    s = replace(
        s,
        r"\{ return let (\w+) = ([^}]+) \}" =>
            SubstitutionString("return\n        let \\1 = \\2"),
    )
    s = replace(
        s,
        r"\{ return // ([^}]+) \}" =>
            SubstitutionString("return\n        // \\1"),
    )
    s = replace(
        s,
        r"\{ return for \((.+)\) \{ \}" =>
            SubstitutionString("return\n        for (\\1) {"),
    )
    # Julia `Module.TypeName()` struct construction → `new Module.TypeName()`.
    s = replace(
        s,
        r"(?<!\bnew )((?:\(globalThis as any\)\.JulGame\.Scripts\.)?\w+Module\.[A-Z]\w*)\(\)" =>
            SubstitutionString("new \\1()"),
    )
    # Julia `nothing` checks often emit `=== null`; unset TS fields are `undefined`.
    s = replace(s, " === null" => " == null")
    s = replace(s, " !== null" => " != null")
    s = replace(s, "Object.Object.values" => "Object.values")
    s = replace(s, r"(?<!Object\.)\bvalues\(" => "Object.values(")
    # Julia 1-based indices on JS arrays (enumerate / character select fields).
    for field in ("selectedCharacterIndex", "iconIndex")
        pat_self = Regex("(\\w+)\\[self\\." * field * "\\](?!\\s*-)")
        pat_local = Regex("(\\w+)\\[" * field * "\\](?!\\s*-)")
        s = replace(s, pat_self => SubstitutionString("\\1[self.$field - 1]"))
        s = replace(s, pat_local => SubstitutionString("\\1[$field - 1]"))
    end
    s = replace(s, r"(\n\s+)(\w+): (self\.[^\n]+)" => s"\n\1let \2 = \3")
    s = replace(s, r"(\n\s+)(\w+): (globals\.[^\n]+)" => s"\n\1let \2 = \3")
    s = replace(s, r"(\n\s+)(\w+): (td\[[^\]]+\])" => s"\n\1let \2 = \3")
    s = replace(s, r"color=" => "color: ")
    s = replace(s, r"^(\s+)parent = "m => s"\1parent: ")
    s = replace(
        s,
        r"^(\s+)parent = ([^\n]+)\n(\s+)\)(?!\))"m =>
            SubstitutionString("\\1parent: \\2\n\\3})"),
    )
    s = replace(s, r"\): boolean \{ \{" => "): boolean {")
    s = replace(s, r"\): string \{ \{" => "): string {")
    s = replace(s, r"Object\.entries\(self\)\) \{\.(\w+)" => s"Object.entries(self.\1)) {")
    s = replace(s, r"^(\s+)(.+?) && continue$"m => s"\1if (!(\2)) continue")
    s = replace(s, r"^(\s+)(.+?) \|\| continue$"m => s"\1if (!(\2)) continue")
    s = replace(s, r"\): string\n(\s+)if " => s"): string {\n\1if ")
    s = replace(s, r"\|\|\)\s*\{" => "|| false) {")
    s = replace(s, r": Vector\b" => ": unknown[]")
    s = replace(s, r": Vector2f\b" => ": { x: number; y: number }")
    s = replace(s, r"^(\s+)(\w+): (`[^`]+`)$"m => s"\1let \2 = \3")
    s = fix_julia_file_io_residuals(s)
    s = fix_julia_typescript_residual_syntax(s)
    return fix_mangled_julia_function_signatures(s)
end

"""Optional per-game hook from `tools/transpile_project.jl` (`filter_scene_index_stems`)."""
function call_filter_scene_index_stems(
    project_root::AbstractString,
    scene::AbstractString,
    stems::Vector{String},
)::Vector{String}
    mod = load_transpile_project_module(project_root)
    mod === nothing && return stems
    isdefined(mod, :filter_scene_index_stems) ||
        return stems
    return Base.invokelatest(getfield(mod, :filter_scene_index_stems), project_root, scene, stems)
end

"""Optional per-game hook from `tools/transpile_project.jl` (`apply_project_script_fixups`)."""
function call_project_script_fixups(
    data::AbstractString,
    name::AbstractString,
    path_jl::AbstractString,
)::String
    root = game_project_root_from_script(path_jl)
    root === nothing && return data
    mod = load_transpile_project_module(root)
    mod === nothing && return data
    isdefined(mod, :apply_project_script_fixups) ||
        return data
    return Base.invokelatest(getfield(mod, :apply_project_script_fixups), data, name, path_jl)
end

function apply_game_script_fixups(
    data::AbstractString,
    name::AbstractString,
    path_jl::AbstractString,
)::String
    s = fix_julia_enums(String(data))
    s = inject_easings_import(s)
    s = apply_generic_game_script_fixups(s)
    s = rewrite_external_support_module_refs(s, path_jl)
    s = fix_transpiled_include_call_syntax(s, path_jl)
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
    s = replace(
        s,
        r"((?:self\.)[\w.]+\.transform\.position) = (\{x:[^}]+\}) \+ (self\.offset)" =>
            s"\1 = vecAdd(\2, \3)",
    )
    s = replace(s, "parse(Int," => "parseInt(")
    s = replace(s, r"\"\$\((\w+)\)\"" => s"`\${\1}`")
    s = replace(s, r"\bcos\(" => "Math.cos(")
    s = replace(s, r"for \(const i of 1:10\)" => "for (let i = 0; i < 10; i++)")
    s = replace(
        s,
        r"for \(const i of 1:([\w.]+)\)" =>
            s"for (let i = 1; i <= \1; i++)",
    )
    s = replace(s, r"(\d)π\b" => s"\1 * Math.PI")
    s = replace(s, r"\bTask \| null\b" => "unknown")
    s = replace(s, r": Condition\b" => ": unknown")
    s = replace(s, r"@task\s+" => "scheduleTask(() => ")
    s = replace(s, r"\bCondition\s*\(\s*\)" => "new (globalThis as any).JulGame.Condition()")
    s = replace(s, r"\bwait\s*\(\s*self\.condition\s*\)" => "await waitCondition(self.condition)")
    s = replace(s, r"\byield\s*\(\s*\)" => "await yieldTask()")
    s = replace(s, r"\bnotify\s*\(\s*self\.condition\s*\)" => "notifyCondition(self.condition)")
    s = replace(s, r"\bistaskdone\s*\(\s*([^)]+)\)" => s"isTaskDone(\1)")
    s = replace(s, r"(?m)^\s*@testset\b.*$" => "")
    s = replace(s, r"(?m)^\s*@test\b.*$" => "")
    s = call_project_script_fixups(s, name, path_jl)
    s = strip_broken_transpile_preamble(s)
    s = fix_julia_typescript_residual_syntax(s)
    s = fix_malformed_kwargs_constructor(s)
    s = fix_julia_format_string_helper(s)
    s = fix_julia_keyword_ctor_calls(s)
    s = fix_julia_semicolon_kwargs_calls(s)
    s = fix_julia_file_io_residuals(s)
    s = fix_mangled_julia_function_signatures(s)
    return fix_this_to_self_in_script_functions(s)
end

"""When a script `include("Easings.jl")`, ensure the shared TS easings module is imported."""
function prepend_easings_helpers(data::AbstractString, path_jl::AbstractString)::String
    src = read(path_jl, String)
    occursin(r"include\s*\(\s*\".*Easings\.jl\"\s*\)", src) || return data
    return inject_easings_import(data)
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

"""Symbols already exported inline (`export class`, `export function`, etc.) must not repeat in `export { ... }`."""
function symbol_already_exported_in_ts(s::AbstractString, sym::AbstractString)::Bool
    sym = String(sym)
    return occursin(Regex("export (?:class|function|async function|const) $(sym)\\b"), s)
end

function symbol_defined_in_ts(s::AbstractString, sym::AbstractString)::Bool
    sym = String(sym)
    occursin(Regex("export class $(sym)\\b"), s) && return true
    occursin(Regex("(?m)^function $(sym)\\("), s) && return true
    occursin(Regex("(?m)^async function $(sym)\\("), s) && return true
    occursin(Regex("(?m)^const $(sym)\\b"), s) && return true
    occursin(Regex("(?m)^class $(sym)\\b"), s) && return true
    return false
end

"""Resolve TS symbols to register on JulGame.Scripts.FooModule."""
function detect_support_module_exports(
    s::AbstractString,
    julia_exports::Vector{String},
    name::AbstractString,
)::Vector{String}
    symbols = String[]
    for sym in julia_exports
        symbol_defined_in_ts(s, sym) && push!(symbols, sym)
    end
    for m in eachmatch(r"export class (\w+)", s)
        sym = String(m.captures[1])
        sym in symbols || push!(symbols, sym)
    end
    for m in eachmatch(r"(?m)^\s*class (\w+)", s)
        sym = String(m.captures[1])
        sym in symbols || push!(symbols, sym)
    end
    for m in eachmatch(r"(?m)^\s*function (\w+)\(", s)
        fn = String(m.captures[1])
        startswith(fn, "JulGame_") && continue
        startswith(fn, "_") && continue
        fn == name && continue
        fn in symbols || push!(symbols, fn)
    end
    for m in eachmatch(r"(?m)^\s*async function (\w+)\(", s)
        fn = String(m.captures[1])
        startswith(fn, "JulGame_") && continue
        fn in symbols || push!(symbols, fn)
    end
    for m in eachmatch(r"(?m)^\s*const (\w+) = \{", s)
        sym = String(m.captures[1])
        sym in symbols || push!(symbols, sym)
    end
    for m in eachmatch(r"const \{ ([^}]+) \} = (\w+)", s)
        for part in split(String(m.captures[1]), ',')
            sym = strip(part)
            isempty(sym) && continue
            sym in symbols || push!(symbols, sym)
        end
    end
    return unique(symbols)
end

"""TS `import * as FooModule from "./Bar"` for separately transpiled `include()` targets."""
function collect_transpile_imports(path_jl::AbstractString)::Vector{String}
    project_root = game_project_root_from_script(path_jl)
    project_root === nothing && return String[]
    transpile_set = get_project_transpile_set(project_root)
    skip = skip_game_script_inline_files(path_jl)
    base = dirname(abspath(path_jl))
    imports = String[]
    seen = Set{String}()
    for m in eachmatch(r"include\s*\(\s*\"([^\"]+)\"\s*\)", read(path_jl, String))
        rel = String(m.captures[1])
        inc = isabspath(rel) ? rel : joinpath(base, rel)
        inc_abs = abspath(inc)
        inc_abs in transpile_set || continue
        basename(inc) in skip && continue
        mod_name = parse_julia_module_name(read(inc_abs, String))
        mod_name === nothing && (mod_name = splitext(basename(inc_abs))[1] * "Module")
        import_path = ts_import_path_from_jl(path_jl, inc_abs, project_root)
        line = "import * as $mod_name from \"$import_path\";"
        line in seen && continue
        push!(seen, line)
        push!(imports, line)
    end
    return imports
end

"""Append `registerScript(...)` and exports for transpiled game scripts."""
function finalize_game_script_ts(data::AbstractString, path_jl::AbstractString, path_ts::AbstractString)::String
    name = game_script_name(path_jl)
    src = read(path_jl, String)
    kind = classify_script_file(path_jl)
    module_name = parse_julia_module_name(src)
    julia_exports = parse_julia_exports(src)
    s = strip_script_module_wrapper(data)
    s = apply_game_script_fixups(s, name, path_jl)
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
    sound_paths = collect_script_sound_paths(path_jl, s)
    reg = IOBuffer()
    println(reg, script_registry_import_line(path_ts))
    if !isempty(sound_paths)
        println(reg, "import { registerScriptSounds } from \"julgame/src/engine/runtime/scriptRegistry\";")
    end
    if needs_async
        println(reg, "import { isTaskDone, notifyCondition, scheduleTask, waitCondition, yieldTask } from \"julgame/src/engine/runtime/coroutineRuntime\";")
    end
    if occursin(r"\bvec(?:Add|Sub|Mul|Div|Neg)\(", s)
        println(reg, "import { vecAdd, vecSub, vecMul, vecDiv, vecNeg } from \"julgame/src/engine/core/vectorOps\";")
    end
    for line in collect_transpile_imports(path_jl)
        println(reg, line)
    end
    println(reg, "")
    print(reg, s)
    println(reg, "")
    if kind in (:script, :dual)
        println(reg, "registerScript(\"$name\", {")
        println(reg, "    create: () => new $name(),")
        has_init && println(reg, "    initialize: $init_fn,")
        has_update && println(reg, "    update: $update_fn,")
        has_shutdown && println(reg, "    onShutdown: $shutdown_fn,")
        println(reg, "});")
    end
    if kind in (:support, :dual) && module_name !== nothing
        exports = detect_support_module_exports(s, julia_exports, name)
        if !isempty(exports)
            esm_exports = filter(sym -> !symbol_already_exported_in_ts(s, sym), exports)
            if !isempty(esm_exports)
                println(reg, "export { $(join(esm_exports, ", ")) };")
            end
            println(reg, "registerSupportModule(\"$module_name\", {")
            for sym in exports
                println(reg, "    $sym,")
            end
            println(reg, "});")
        end
    end
    if !isempty(sound_paths)
        println(reg, "registerScriptSounds([$(join(map(p -> "\"$p\"", sound_paths), ", "))]);")
    end
    return prefer_esm_import_over_scripts_registry(String(take!(reg)), path_jl)
end

function postprocess_game_script_ts(data::AbstractString, path_jl::AbstractString, path_ts::AbstractString)::String
    s = finalize_game_script_ts(data, path_jl, path_ts)
    s = insert_semicolon_before_line_starting_with_open_paren(s)
    s = replace(s, r"\[;" => "[")
    s = fix_argevent_collision_callbacks(s)
    s = fix_bare_main_identifiers(s)
    s = fix_double_julgame_rewrite(s)
    s = fix_double_main_rewrite(s)
    return s
end

function collect_project_script_files(project_root::AbstractString)::Vector{String}
    scripts_dir = joinpath(abspath(project_root), "scripts")
    isdir(scripts_dir) || return String[]
    out = Set{String}()
    top_level = String[]
    for f in readdir(scripts_dir)
        endswith(f, ".jl") || continue
        path = abspath(joinpath(scripts_dir, f))
        push!(out, path)
        push!(top_level, path)
    end
    for path in collect_nested_include_scripts(project_root, top_level)
        push!(out, path)
    end
    for name in collect_scene_script_names(project_root)
        p = script_path_for_name(scripts_dir, name)
        p === nothing && continue
        push!(out, abspath(p))
    end
    return sort!(collect(out))
end

"""Last generic syntax pass — also run after project postprocess (project hooks may re-mangle)."""
function finalize_transpiled_script_syntax(s::AbstractString)::String
    s = fix_julia_file_io_residuals(s)
    return fix_mangled_julia_function_signatures(s)
end

"""Run project `tools/transpile_project.jl` postprocess hooks after convert.jl."""
function run_transpile_project_postprocess(project_root::AbstractString)
    mod = load_transpile_project_module(project_root)
    mod === nothing && return nothing
    if isdefined(mod, :postprocess_after_transpile)
        Base.invokelatest(getfield(mod, :postprocess_after_transpile), project_root)
    end
    scripts_out = joinpath(abspath(project_root), "ts", "_generated", "scripts")
    if isdir(scripts_out)
        for f in readdir(scripts_out)
            endswith(f, ".ts") || continue
            f == "index.ts" && continue
            path = joinpath(scripts_out, f)
            original = read(path, String)
            updated = finalize_transpiled_script_syntax(original)
            if updated != original
                open(path, "w") do io
                    print(io, updated)
                end
                println("finalize: $(relpath(path, project_root))")
            end
        end
    end
    return joinpath(abspath(project_root), "tools", "transpile_project.jl")
end

function collect_ts_script_stems(scripts_out::AbstractString)::Vector{String}
    stems = String[]
    for (root, _, files) in walkdir(scripts_out)
        for f in files
            endswith(f, ".ts") || continue
            f == "index.ts" && continue
            full = joinpath(root, f)
            rel = relpath(full, scripts_out)
            push!(stems, replace(rel, r"\.ts$" => ""))
        end
    end
    return stems
end

function index_import_kind(ts_path::AbstractString)::Symbol
    isfile(ts_path) || return :script
    content = read(ts_path, String)
    has_support = occursin("registerSupportModule", content)
    has_script = occursin("registerScript(", content)
    has_support && !has_script && return :support
    return :script
end

function project_skip_inline_basenames(project_root::AbstractString)::Set{String}
    skip = copy(DEFAULT_SKIP_GAME_SCRIPT_INLINE)
    mod = load_transpile_project_module(project_root)
    mod === nothing && return skip
    if isdefined(mod, :SKIP_GAME_SCRIPT_INLINE)
        union!(skip, getfield(mod, :SKIP_GAME_SCRIPT_INLINE))
    end
    return skip
end

function stem_is_skipped_inline(project_root::AbstractString, stem::AbstractString)::Bool
    skip = project_skip_inline_basenames(project_root)
    basename(stem * ".jl") in skip && return true
    for name in skip
        endswith(stem, replace(name, ".jl" => "")) && return true
    end
    return false
end

function collect_scene_index_stems(
    project_root::AbstractString,
    scene::AbstractString,
    scripts_out::AbstractString,
)::Vector{String}
    allowed_entities = collect_scene_script_names_from_file(project_root, scene)
    stems = Set{String}()
    for name in allowed_entities
        stem_is_skipped_inline(project_root, name) || push!(stems, name)
    end
    scripts_jl = joinpath(abspath(project_root), "scripts")
    queue = collect(stems)
    seen = copy(stems)
    while !isempty(queue)
        stem = popfirst!(queue)
        ts_path = joinpath(scripts_out, stem * ".ts")
        jl_path = joinpath(scripts_jl, stem * ".jl")
        if isfile(jl_path)
            for ext in collect_external_support_stems(jl_path, scripts_out)
                ext in seen && continue
                push!(seen, ext)
                push!(stems, ext)
                push!(queue, ext)
            end
        end
        isfile(ts_path) || continue
        for m in eachmatch(r"import \* as \w+ from \"\./([^\"]+)\"", read(ts_path, String))
            dep = String(m.captures[1])
            dep in seen && continue
            stem_is_skipped_inline(project_root, dep) && continue
            startswith(dep, "console/") && continue
            push!(seen, dep)
            push!(stems, dep)
            push!(queue, dep)
        end
    end
    out = sort!(filter(st -> isfile(joinpath(scripts_out, st * ".ts")), collect(stems)))
    return call_filter_scene_index_stems(project_root, scene, out)
end

"""Side-effect barrel: `import "./Foo"` for every transpiled `ts/_generated/scripts/*.ts`."""
function write_scripts_index(
    project_root::AbstractString;
    scene::Union{Nothing, AbstractString} = nothing,
)::Union{String, Nothing}
    scripts_out = joinpath(abspath(project_root), "ts", "_generated", "scripts")
    isdir(scripts_out) || return nothing
    stems = scene !== nothing ?
            collect_scene_index_stems(project_root, scene, scripts_out) :
            collect_ts_script_stems(scripts_out)
    if scene !== nothing
        println("index scene filter ($scene): $(length(stems)) scripts")
    end
    isempty(stems) && return nothing
    support_stems = String[]
    script_stems = String[]
    for stem in stems
        ts_path = joinpath(scripts_out, stem * ".ts")
        index_import_kind(ts_path) == :support ? push!(support_stems, stem) : push!(script_stems, stem)
    end
    sort!(support_stems)
    sort!(script_stems)
    index_path = joinpath(scripts_out, "index.ts")
    open(index_path, "w") do io
        scene === nothing ||
            println(io, "// Scene filter: $scene")
        println(io, "// Auto-generated by tools/convert.jl — registers transpiled game scripts.")
        if !isempty(support_stems)
            println(io, "// Support modules (JulGame.Scripts.*) — load before entity scripts.")
            for stem in support_stems
                println(io, "import \"./$stem\";")
            end
        end
        if !isempty(script_stems)
            !isempty(support_stems) && println(io, "")
            println(io, "// Entity scripts")
            for stem in script_stems
                println(io, "import \"./$stem\";")
            end
        end
    end
    return index_path
end
