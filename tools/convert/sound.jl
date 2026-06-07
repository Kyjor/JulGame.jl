# SoundSource.jl → SoundSource.ts fixups (included from tools/convert.jl).

function is_sound_source(path_jl::AbstractString)::Bool
    norm = replace(normpath(String(path_jl)), '\\' => '/')
    return endswith(norm, "/Component/SoundSource.jl") || endswith(norm, "SoundSource.jl")
end

function postprocess_sound_ts(data::AbstractString)::String
    s = wrap_sdl_mixer_volumes(data)
    s = ensure_mixer_volume_before_play(s)
    return s
end
