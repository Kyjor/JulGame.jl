# SoundSource.jl → SoundSource.ts fixups (included from tools/convert.jl).

function is_sound_source(path_jl::AbstractString)::Bool
    norm = replace(normpath(String(path_jl)), '\\' => '/')
    return endswith(norm, "/Component/SoundSource.jl") || endswith(norm, "SoundSource.jl")
end

function postprocess_sound_ts(data::AbstractString)::String
    s = wrap_sdl_mixer_volumes(data)
    s = ensure_mixer_volume_before_play(s)
    # WASM: defer Mix_Load* until Mix_OpenAudio (pointerdown) — reloadEntitySounds in memfsAudio.ts
    s = replace(s, "sound = load_sound_sdl(path, isMusic)" => "/* deferred */ null")
    s = replace(s, r"if \(path\.length > 0\) \{\s*\n\s*/\* deferred \*/ null\s*\n\s*\}" => "")
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGameSdl\.glue_SDL_ClearError\(\)\s*\n\s*let fullPath[^\n]+\n\s*let sound = null[\s\S]*?// Convert channel" =>
            "let sound = null\n\n            // Convert channel",
    )
    s = replace(
        s,
        r"self\.sound = load_sound_sdl\(soundPath, isMusic\)\s*\n\s*if \(error\.length" =>
            "self.sound = load_sound_sdl(soundPath, isMusic)\n        let error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())\n        if (error.length",
    )
    s = replace(
        s,
        "function load_sound_sdl(soundPath: string, isMusic: boolean) {" =>
            "function load_sound_sdl(soundPath: string, isMusic: boolean) {\n        if (!(globalThis as any).__julgameAudioOpen) {\n            return null\n        }",
    )
    return s
end
