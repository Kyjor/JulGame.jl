# SoundSource.jl → SoundSource.ts fixups (included from tools/convert.jl).

function is_sound_source(path_jl::AbstractString)::Bool
    norm = replace(normpath(String(path_jl)), '\\' => '/')
    return endswith(norm, "/Component/SoundSource.jl") || endswith(norm, "SoundSource.jl")
end

function postprocess_sound_ts(data::AbstractString)::String
    s = String(data)
    # `clamp(-1, 0, 128)` → 0 silences all channels via `Mix_Volume(-1, 0)`.
    s = replace(s, "clamp(volume, 0, 128)" => "mixVolume(volume)")
    s = replace(s, "glue_Mix_VolumeMusic(self.volume)" => "glue_Mix_VolumeMusic(mixVolume(self.volume))")
    s = replace(s, "glue_Mix_Volume(self.channel, self.volume)" => "glue_Mix_Volume(self.channel, mixVolume(self.volume))")
    if !occursin("glue_Mix_VolumeMusic(mixVolume(self.volume));", s)
        s = replace(
            s,
            "                if ((globalThis as any).JulGameSdl.glue_Mix_PlayingMusic() == 0) {\n                    (globalThis as any).JulGameSdl.glue_Mix_PlayMusic( self.sound, -1 )" =>
                "                if ((globalThis as any).JulGameSdl.glue_Mix_PlayingMusic() == 0) {\n                    (globalThis as any).JulGameSdl.glue_Mix_VolumeMusic(mixVolume(self.volume));\n                    (globalThis as any).JulGameSdl.glue_Mix_PlayMusic(self.sound, -1);",
        )
        s = replace(
            s,
            "            } else {\n                if ((globalThis as any).JulGameSdl.glue_Mix_PlayChannel(self.channel, self.sound, loops) == -1) {" =>
                "            } else {\n                (globalThis as any).JulGameSdl.glue_Mix_Volume(self.channel, mixVolume(self.volume));\n                if ((globalThis as any).JulGameSdl.glue_Mix_PlayChannel(self.channel, self.sound, loops) == -1) {",
        )
        s = replace(
            s,
            "        if (self.isMusic) {\n            (globalThis as any).JulGameSdl.glue_Mix_PlayMusic(self.sound, -1)\n        } else {\n            (globalThis as any).JulGameSdl.glue_Mix_PlayChannel(self.channel, self.sound, loops)" =>
                "        if (self.isMusic) {\n            (globalThis as any).JulGameSdl.glue_Mix_VolumeMusic(mixVolume(self.volume));\n            (globalThis as any).JulGameSdl.glue_Mix_PlayMusic(self.sound, -1);\n        } else {\n            (globalThis as any).JulGameSdl.glue_Mix_Volume(self.channel, mixVolume(self.volume));\n            (globalThis as any).JulGameSdl.glue_Mix_PlayChannel(self.channel, self.sound, loops);",
        )
    end
    return s
end
