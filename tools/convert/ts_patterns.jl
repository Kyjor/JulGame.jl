# Shared pattern-based TS postprocess helpers (included from tools/convert.jl).

"""Julia 1-based `arr[i]` when `i` is an identifier (literals handled by `rewrite_one_based_indices`)."""
function fix_julia_one_based_variable_indices(data::AbstractString)::String
    text = String(data)
    for prop in ("animations", "uiElements", "frames")
        pat = Regex("\\.$prop\\[([A-Za-z_]\\w*)\\](?!\\s*-\\s*1)")
        io = IOBuffer()
        idx = firstindex(text)
        n = lastindex(text)
        while idx <= n
            rg = findnext(pat, text, idx)
            if rg === nothing
                write(io, SubString(text, idx))
                break
            end
            f = first(rg)
            f > idx && write(io, SubString(text, idx, prevind(text, f)))
            m = match(pat, text, f)
            m === nothing && break
            ident = String(m.captures[1])
            write(io, string(".", prop, "[", ident, " - 1]"))
            idx = nextind(text, last(rg))
        end
        text = String(take!(io))
    end
    return text
end

"""Repair duplicate JulGame rewrite: `(globalThis as any).JulGame.(globalThis as any).JulGame.` → `(globalThis as any).JulGame.`."""
function fix_double_julgame_rewrite(data::AbstractString)::String
    s = String(data)
    while occursin(r"\(globalThis as any\)\.\(globalThis as any\)\.JulGame\.", s)
        s = replace(s, r"\(globalThis as any\)\.\(globalThis as any\)\.JulGame\." => "(globalThis as any).JulGame.")
    end
    while occursin(r"\(globalThis as any\)\.JulGame\.\(globalThis as any\)\.JulGame\.", s)
        s = replace(s, r"\(globalThis as any\)\.JulGame\.\(globalThis as any\)\.JulGame\." => "(globalThis as any).JulGame.")
    end
    return s
end

"""`@argevent` callbacks: `( (col: any) => fn(self, col))` / trailing `))` → valid arrow fn."""
function fix_argevent_collision_callbacks(data::AbstractString)::String
    s = String(data)
    s = replace(
        s,
        r"=\s*\(\s*\((\w+):\s*any\)\s*=>\s*([\w.]+)\(self,\s*\1\)\)\s*\)\s*;" =>
            s"= (\1: any) => \2(self, \1);",
    )
    s = replace(
        s,
        r"=\s*\(\s*\((\w+):\s*any\)\s*=>\s*([\w.]+)\(self,\s*\1\)\)\s*;" =>
            s"= (\1: any) => \2(self, \1);",
    )
    s = replace(s, r"=>\s*handle_bullet_collisions\(self,\s*col\)\)\s*;" => "=> handle_bullet_collisions(self, col);")
    s = replace(s, r"=>\s*handle_collisions\(self,\s*col\)\)\s*;" => "=> handle_collisions(self, col);")
    return s
end

"""`destroy_entity(MAIN, …)` and other bare `MAIN` args (no trailing `.`)."""
function fix_bare_main_identifiers(data::AbstractString)::String
    s = String(data)
    s = replace(s, r"\bdestroy_entity\(\s*MAIN\s*," => "destroy_entity((globalThis as any).MAIN,")
    return s
end

"""Repair duplicate `MAIN` rewrite: `(globalThis as any).(globalThis as any).MAIN` → `(globalThis as any).MAIN`."""
function fix_double_main_rewrite(data::AbstractString)::String
    s = String(data)
    while occursin(r"\(globalThis as any\)\.\(globalThis as any\)\.MAIN", s)
        s = replace(s, r"\(globalThis as any\)\.\(globalThis as any\)\.MAIN" => "(globalThis as any).MAIN")
    end
    return s
end

"""JS ASI: `glue_foo()\\n(globalThis...` parses as calling the return value. Add `;` after glue lines."""
function fix_ts_asi_glue_semicolons(data::AbstractString)::String
    lines = split(String(data), '\n'; keepempty=true)
    out = String[]
    for i in eachindex(lines)
        line = lines[i]
        if i < lastindex(lines)
            cur = rstrip(line)
            nxt = lstrip(lines[i + 1])
            if occursin(r"glue_", cur) &&
               endswith(cur, ")") &&
               !endswith(cur, ";") &&
               !endswith(cur, "};") &&
               startswith(nxt, "(globalThis")
                line = cur * ";"
            end
        end
        push!(out, line)
    end
    return join(out, '\n')
end

"""SDL mixer: Julia volume `-1` means default; `clamp(-1,0,128)` → silent."""
function wrap_sdl_mixer_volumes(data::AbstractString)::String
    s = String(data)
    s = replace(s, r"\bclamp\s*\(\s*volume\s*,\s*0\s*,\s*128\s*\)" => "mixVolume(volume)")
    # Lookahead must skip optional whitespace: `\s*` before `(` can match zero chars and miss `mixVolume`.
    s = replace(s, r"glue_Mix_VolumeMusic\(\s*(?!\s*mixVolume\s*\()([^)]+)\)" => s"glue_Mix_VolumeMusic(mixVolume(\1))")
    s = replace(s, r"glue_Mix_Volume\(\s*([^,]+),\s*(?!\s*mixVolume\s*\()([^)]+)\)" => s"glue_Mix_Volume(\1, mixVolume(\2))")
    return s
end

const _GLUE_PLAY_MUSIC = r"glue_Mix_PlayMusic\s*\("
const _GLUE_PLAY_CHANNEL = r"glue_Mix_PlayChannel\s*\("
const _GLUE_VOL_MUSIC = r"glue_Mix_VolumeMusic\s*\("
const _GLUE_VOL_CHANNEL = r"glue_Mix_Volume\s*\("

"""Insert per-source volume immediately before play calls when the transpiler omitted it."""
function ensure_mixer_volume_before_play(data::AbstractString)::String
    lines = split(String(data), '\n'; keepempty=true)
    out = String[]
    for (i, line) in pairs(lines)
        prev = i > 1 ? lines[i - 1] : ""
        m = match(r"^(\s*)", line)
        indent = m === nothing ? "" : m.captures[1]
        if occursin(_GLUE_PLAY_MUSIC, line) && !occursin(_GLUE_VOL_MUSIC, prev)
            push!(out, indent * "(globalThis as any).JulGameSdl.glue_Mix_VolumeMusic(mixVolume(self.volume));")
        elseif occursin(_GLUE_PLAY_CHANNEL, line) && !occursin(_GLUE_VOL_CHANNEL, prev)
            push!(out, indent * "(globalThis as any).JulGameSdl.glue_Mix_Volume(self.channel, mixVolume(self.volume));")
        end
        push!(out, line)
    end
    return join(out, '\n')
end
