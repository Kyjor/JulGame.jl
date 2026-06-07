# Shared pattern-based TS postprocess helpers (included from tools/convert.jl).

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
