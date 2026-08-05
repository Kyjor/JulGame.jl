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
    s = replace(
        s,
        r"function Component_destroy\(self: InternalSprite\) \{\n        if \(self\.image == null\) \{\n            return\n        \}\n\n        // Only destroy texture if it's not in the shared cache\n        self\.image = null\n        self\.texture = null\n    \}" =>
        """
        function Component_destroy(self: InternalSprite) {
        if (self.image == null) {
            return
        }
        const cache = (globalThis as any).JulGame.TEXTURE_CACHE
        if (self.texture != null && cache[self.imagePath] == null) {
            (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(self.texture)
        }
        (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(self.image)
        self.image = null
        self.texture = null
    }""",
    )
    # Self-heal path still emits bare TEXTURE_CACHE / get/delete Julia helpers.
    s = replace(
        s,
        r"if \(get\(TEXTURE_CACHE, self\.imagePath, null\) == self\.texture\) \{\n\s*delete\(TEXTURE_CACHE, self\.imagePath\)\n\s*\}" =>
        """
        const cache = (globalThis as any).JulGame.TEXTURE_CACHE
                if (cache[self.imagePath] == self.texture) {
                    delete cache[self.imagePath]
                }""",
    )
    s = replace(s, r"\bget\(TEXTURE_CACHE,\s*([^,]+),\s*(?:null|C_NULL)\)" => s"((globalThis as any).JulGame.TEXTURE_CACHE[\1] ?? null)")
    s = replace(s, r"\bdelete\(TEXTURE_CACHE,\s*([^)]+)\)" => s"delete (globalThis as any).JulGame.TEXTURE_CACHE[\1]")
    s = replace(s, r"(?<!\.)\bTEXTURE_CACHE\b" => "(globalThis as any).JulGame.TEXTURE_CACHE")
    # Julia-only surface / effect-prewarm helpers do not transpile; keep a JS Map cache.
    s = replace(
        s,
        r"const SURFACE_CACHE = \{\}\n\s*const SURFACE_CACHE_PTRS = Set\{[^}]+\} \(\)\n\n\s*is_shared_surface\(surface\): boolean = surface in SURFACE_CACHE_PTRS\n\n\s*function get_or_load_surface\(fullPath: string, imagePath: string\) \{[\s\S]*?\n\s*function clear_surface_cache\(\) \{[\s\S]*?\n\s*\}" =>
        """
        const SURFACE_CACHE: Record<string, any> = {}
        function is_shared_surface(surface: any): boolean {
            return Object.values(SURFACE_CACHE).includes(surface)
        }
        function isSdlPtr(p: unknown): p is number {
            return typeof p === "number" && p !== 0
        }
        function get_or_load_surface(fullPath: string, imagePath: string) {
            let cached = SURFACE_CACHE[imagePath]
            if (isSdlPtr(cached)) {
                return cached
            }
            let surface = load_image_sdl(fullPath, imagePath)
            if (isSdlPtr(surface)) {
                SURFACE_CACHE[imagePath] = surface
                return surface
            }
            return null
        }
        function clear_surface_cache() {
            for (const imagePath of Object.keys(SURFACE_CACHE)) {
                const surface = SURFACE_CACHE[imagePath]
                if (surface != null) {
                    (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(surface)
                }
                delete SURFACE_CACHE[imagePath]
            }
        }""",
    )
    # Drop Julia Threads/Channel effect-prewarm block (wasm uses sync path).
    s = replace(
        s,
        r"\n\s*const EFFECT_PREWARM_RESULTS[\s\S]*?\n\s*function Component_load_image" =>
            """

    function pump_effect_prewarm() {}
    function prewarm_effect_textures(_imagePath: string, _effects: any[]) {}
    function compute_effect_prewarm_surface(_imagePath: string, _effects: any[]) { return null }
    function finalize_effect_prewarm(_key: string, _surface: any) {}
    function effect_prewarm_pending() { return false }

    function Component_load_image""",
    )
    s = replace(
        s,
        r"\n\s*// --- Async effect-texture prewarm[\s\S]*?\n\s*function Component_load_image" =>
            """

    function pump_effect_prewarm() {}
    function prewarm_effect_textures(_imagePath: string, _effects: any[]) {}
    function compute_effect_prewarm_surface(_imagePath: string, _effects: any[]) { return null }
    function finalize_effect_prewarm(_key: string, _surface: any) {}
    function effect_prewarm_pending() { return false }

    function Component_load_image""",
    )
    s = replace(s, r"const SURFACE_CACHE_PTRS = Set\{[^;\n]+\}" => "const SURFACE_CACHE_PTRS = new Set()")
    s = replace(s, r"const SURFACE_CACHE_PTRS = new Set\(\)\(\)" => "const SURFACE_CACHE_PTRS = new Set()")
    s = replace(s, r"is_shared_surface\(surface\): boolean = surface in SURFACE_CACHE_PTRS" =>
        "function is_shared_surface(surface: any): boolean { return SURFACE_CACHE_PTRS.has(surface) }")
    s = replace(s, r"Channel\{[^}]+\}(?:\{[^}]+\})?\(Infinity\)" => "[] as any[]")
    s = replace(s, r"Vector\{Tuple\{String, Vector\{Any\}\}\}\(\)" => "[] as Array<[string, any[]]>")
    s = replace(s, r"Set\{String\}\(\)" => "new Set<string>()")
    s = replace(s, r"Threads\.Atomic\{Int\}\(0\)" => "0")
    s = replace(
        s,
        r"function clear_surface_cache\(\) \{\n\s*for \(_, surface\) in SURFACE_CACHE\n\s*if \(surface != null\) \{\n\s*\(globalThis as any\)\.JulGameSdl\.glue_SDL_FreeSurface\(surface\)\n\s*\}\n\s*\}\n\s*empty\(SURFACE_CACHE\)\n\s*empty\(SURFACE_CACHE_PTRS\)\n\s*\}" =>
        """
        function clear_surface_cache() {
        for (const imagePath of Object.keys(SURFACE_CACHE)) {
            const surface = SURFACE_CACHE[imagePath]
            if (surface != null) {
                (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(surface)
            }
            delete SURFACE_CACHE[imagePath]
        }
        SURFACE_CACHE_PTRS.clear()
    }""",
    )
    s = replace(s, r"SURFACE_CACHE_PTRS\.push\(" => "SURFACE_CACHE_PTRS.add(")
    s = replace(s, r"let cached = get\(SURFACE_CACHE, imagePath, null\)" => "let cached = SURFACE_CACHE[imagePath] ?? null")
    s = replace(
        s,
        r"\bjoinpath\(BasePath," => "joinpath((globalThis as any).JulGame.BasePath,",
    )
    return s
end
