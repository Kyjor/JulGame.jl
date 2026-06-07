# Sprite.jl → Sprite.ts fixups (included from tools/convert.jl).

function is_sprite_source(path_jl::AbstractString)::Bool
    norm = replace(normpath(String(path_jl)), '\\' => '/')
    return endswith(norm, "/Component/Sprite.jl") || endswith(norm, "Sprite.jl")
end

function postprocess_sprite_ts(data::AbstractString)::String
    s = String(data)
    # `crop` may be null or undefined (unset / failed animator index).
    s = replace(
        s,
        "self.crop === null || (self.crop.x === 0 && self.crop.y === 0 && self.crop.z === 0 && self.crop.t === 0)" =>
            "self.crop == null || (self.crop.x === 0 && self.crop.y === 0 && self.crop.z === 0 && self.crop.t === 0)",
    )
    s = replace(
        s,
        r"let cropWidth = srcRect == null \? self\.size\.x" =>
            "let cropWidth = srcRect == null ? (self.size?.x ?? 0)",
    )
    s = replace(
        s,
        r"let cropHeight = srcRect == null \? self\.size\.y" =>
            "let cropHeight = srcRect == null ? (self.size?.y ?? 0)",
    )
    return s
end
