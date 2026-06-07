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
    s = replace(
        s,
        r"\(globalThis as any\)\.JulGame\.IMAGE_CACHE\.length" =>
            "Object.keys((globalThis as any).JulGame.IMAGE_CACHE).length",
    )
    # Transpiler strips module-level TEXTURE_CACHE; restore shared texture lookup.
    s = replace(
        s,
        "        let _textureColor = (globalThis as any).JulGameSdl.glue_SDL_GetTextureColorMod(texture_to_render)" =>
            "        if (texture_to_render == null) { return }\n        let _textureColor = (globalThis as any).JulGameSdl.glue_SDL_GetTextureColorMod(texture_to_render)",
    )
    s = replace(
        s,
        r"function get_or_create_texture\(imagePath: string, surface: any\) \{\n        let tex = \(globalThis as any\)\.JulGameSdl\.glue_SDL_CreateTextureFromSurface\(\(globalThis as any\)\.JulGame\.Renderer, surface\)\n        if \(tex != null\) \{\n\n            console\.debug\(`Created and cached texture for: \$\{imagePath\}`\)\n        \} else \{\n            console\.error\(`Failed to create texture for: \$\{imagePath\}`\)\n        \}\n        return tex\n    \}" =>
        """
        function get_or_create_texture(imagePath: string, surface: any) {
        const cache = (globalThis as any).JulGame.TEXTURE_CACHE
        if (cache[imagePath] != null) {
            return cache[imagePath]
        }
        let tex = (globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface((globalThis as any).JulGame.Renderer, surface)
        if (tex != null) {
            cache[imagePath] = tex
        } else {
            console.error(`Failed to create texture for: \${imagePath}`)
        }
        return tex
    }""",
    )
    return s
end
