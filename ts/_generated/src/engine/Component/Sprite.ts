export {}
import { clamp } from "../../../../src/engine/core/juliaHelpers";
import { vecAdd, vecSub, vecMul, vecDiv, vecNeg } from "../../../../src/engine/core/vectorOps";


    // using ..Component.JulGame
    // using ..Component.(globalThis as any).JulGame.ResourceModule
    // import ..Component
    // Effects imports - will be available after Effects 
    // import ..Component.JulGame as JG

    
    class Sprite {
        color: [number, number, number, number]
        crop: null | Vector4
        isFlipped: boolean
        imagePath: string
        layer: number
        offset: Vector2f
        position: Vector2f
        rotation: number
        pixelsPerUnit: number
        center: Vector2f
        anchor: symbol
        isStatic: boolean
    }

    
    class InternalSprite extends (globalThis as any).JulGame.ISprite { 
        imagePath: string
        layer: number
        offset: Vector2f
        center: Vector2f
        rotation: number
        color: [number, number, number, number]
        crop: null | Vector4
        isFlipped: boolean
        isFloatPrecision: boolean
        image: null | SDL_Surface}
        parent: IEntity // Entity
        lastRenderedScreenPosition: Vector2f | null
        lastRenderedScreenSize: Vector2f | null
        pixelsPerUnit: number
        size: Vector2
        texture: null | SDL_Texture}
        position: Vector2f
        anchor: symbol
        isStatic: boolean
        //  effects support
        effects: any[]  // Will hold Effect objects
        effectTexture: null | SDL_Texture}
        effectSize: Vector2  // Size of effect texture (may be larger due to glow padding)
        effectCacheKey: String  // Cache key for sharing effect textures
        needsEffectUpdate: boolean
        useEffectTexture: Bool  // Toggle to enable/disable effect texture rendering
        interactionScale: number  // Scale factor for hover/click hitbox (1.0 = full size, <1.0 = smaller)
        
        function InternalSprite(
            parent: IEntity,
            imagePath: String,
            crop: null | Vector4=null, 
            isFlipped: boolean=false, 
            color = [255,255,255,255], 
            isCreatedInEditor: boolean=false; 
            pixelsPerUnit: number=0, 
            position = {x: 0, y: 0}, 
            rotation: number = 0.0, 
            layer: number = 0, 
            center = {x: 0.5, y: 0.5}, 
            anchor: symbol = :center, 
            offset = {x: 0, y: 0}, 
            isStatic: boolean = false
        )
            

            this.offset = offset
            this.isFlipped = isFlipped
            console.debug("attemping to load sprite with path: $(imagePath)")
            this.imagePath = imagePath
            this.center = center
            this.color = color
            this.crop = crop
            this.image = null
            this.layer = layer
            this.parent = parent
            this.pixelsPerUnit = pixelsPerUnit
            this.position = position
            this.rotation = rotation
            this.texture = null
            this.isFloatPrecision = false
            this.lastRenderedScreenPosition = null
            this.lastRenderedScreenSize = null
            this.anchor = anchor

            this.isStatic = isStatic
            
            // Initialize effects
            this.effects = []
            this.effectTexture = null
            this.effectSize = {x: 0, y: 0}
            this.effectCacheKey = ""
            this.needsEffectUpdate = false
            this.useEffectTexture = true  // Default to showing effects when applied
            this.interactionScale = 1.0  // Default to full-size hitbox

            // Early returns
            if (isCreatedInEditor) {

            }

            Component_load_image(this: InternalSprite, imagePath: string)
            if (this.image == null) {
                let error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())
                @error(string("Couldn't open image! path: $(fullPath) SDL Error: ", error))
                Base.show_backtrace(stdout, catch_backtrace())
                return
            }
            let surface = unsafe_wrap(Array, this.image, 10; own = false)
            this.size = {x: surface[0].w, y: surface[0].h}

        }
    }
    
    function Component_draw(this: InternalSprite,  camera = null) {
        if (this.image == null || (globalThis as any).JulGame.Renderer == null) {
            return
        }
        
        // Update effects if needed
        if (!isempty(this.effects) && this.needsEffectUpdate) {
            update_effects(this)
        }
    
        // Use effect texture if available and enabled, otherwise use regular texture
        let texture_to_render = if this.useEffectTexture && !isempty(this.effects) && this.effectTexture != null
            this.effectTexture
        } else {
            // Create or get cached texture if it doesn't exist
            if (this.texture == null && this.image != null) {
                this.texture = get_or_create_texture(this.imagePath, this.image)
                Component_set_color(this)
            }
            this.texture
        }
    
        // Check and set color if necessary (for both regular and effect textures)
        let colorRefs = (UInt8(0), UInt8(0), UInt8(0))
        let alphaRef = UInt8(0)
        (globalThis as any).JulGameSdl.glue_SDL_GetTextureColorMod(texture_to_render, colorRefs...)
        (globalThis as any).JulGameSdl.glue_SDL_GetTextureAlphaMod(texture_to_render, alphaRef)
        if (colorRefs[0][] != this.color[0] || colorRefs[1][] != this.color[1] || colorRefs[2][] != this.color[2] || this.color[3] != alphaRef) {
            (globalThis as any).JulGameSdl.glue_SDL_SetTextureColorMod(texture_to_render, UInt8(clamp(this.color[0], 0, 255)), UInt8(clamp(this.color[1], 0, 255)), UInt8(clamp(this.color[2], 0, 255)))
            (globalThis as any).JulGameSdl.glue_SDL_SetTextureAlphaMod(texture_to_render, UInt8(clamp(this.color[3], 0, 255)))
        }
    
        let S = (globalThis as any).JulGame.pixels_per_world_unit(camera)
        // Calculate camera difference
        let cameraDiff = camera !== null ? 
            {x: (camera.position.x + camera.offset.x) * S, y: (camera.position.y + camera.offset.y) * S} : 
            {x: 0, y: 0}
    
        // Calculate position
        let position = this.parent.transform.position
    
        // Calculate source rectangle
        let srcRect = (this.crop == Vector4(0, 0, 0, 0) || this.crop == null) ? null : (globalThis as any).JulGameSdl.glue_SDL_Rect(this.crop.x, this.crop.y, this.crop.z, this.crop.t)
    
        // Calculate pixels per unit
        let ppu = this.pixelsPerUnit > 0 ? this.pixelsPerUnit : (globalThis as any).JulGame.PIXELS_PER_UNIT
    
        // Check if // using effect texture
        let usingEffectTex = texture_to_render == this.effectTexture && this.effectSize != {x: 0, y: 0}
        
        // Always use original sprite size for positioning calculations
        let cropWidth = srcRect == null ? this.size.x : this.crop.z
        let cropHeight = srcRect == null ? this.size.y : this.crop.t
        let scaleX = this.parent.transform.scale.x
        let scaleY = this.parent.transform.scale.y
    
        // Compute position adjustment
        let adjustedX = vecSub(vecMul(vecAdd(position.x, this.offset.x), S), cameraDiff.x)
        let adjustedY = vecSub(vecMul(vecAdd(position.y, this.offset.y), S), cameraDiff.y)
    
        // Handle pixelsPerUnit == 0 (use true size without scaling)
        if (this.pixelsPerUnit == 0) {
            let scaledWidth = cropWidth * scaleX * S / 64.0
            let scaledHeight = cropHeight * scaleY * S / 64.0
        } else {
            // Use pixelsPerUnit or default PIXELS_PER_UNIT for scaling
            ppu = this.pixelsPerUnit > 0 ? this.pixelsPerUnit : (globalThis as any).JulGame.PIXELS_PER_UNIT
            let scaleFactor = S / ppu
            scaledWidth = cropWidth * scaleFactor * scaleX
            scaledHeight = cropHeight * scaleFactor * scaleY
        }
    
        // Compute position based on anchor (// using original sprite dimensions)
        let centeredX = adjustedX
        let centeredY = adjustedY
        
        // Apply anchor positioning
        if (this.anchor == :center) {
            // Center anchor (default behavior)
            centeredX -= (scaledWidth - S * scaleX) / 2
            centeredY -= (scaledHeight - S * scaleY) / 2
        } else if (this.anchor == :top) {
            // Top anchor
            centeredX -= (scaledWidth - S * scaleX) / 2
            // No adjustment for Y
        } else if (this.anchor == :bottom) {
            // Bottom anchor
            centeredX -= (scaledWidth - S * scaleX) / 2
            centeredY -= (scaledHeight - S * scaleY)
        } else if (this.anchor == :left) {
            // Left anchor
            centeredY -= (scaledHeight - S * scaleY) / 2
            // No adjustment for X
        } else if (this.anchor == :right) {
            // Right anchor
            centeredX -= (scaledWidth - S * scaleX)
            centeredY -= (scaledHeight - S * scaleY) / 2
        } else if (this.anchor == :topleft) {
            // Top-left anchor
            // No adjustment needed
        } else if (this.anchor == :topright) {
            // Top-right anchor
            centeredX -= (scaledWidth - S * scaleX)
        } else if (this.anchor == :bottomleft) {
            // Bottom-left anchor
            centeredY -= (scaledHeight - S * scaleY)
        } else if (this.anchor == :bottomright) {
            // Bottom-right anchor
            centeredX -= (scaledWidth - S * scaleX)
            centeredY -= (scaledHeight - S * scaleY)
        }
        
        // AFTER anchor positioning: expand render size for effect texture and offset to center it
        if (usingEffectTex) {
            scaleFactor = this.pixelsPerUnit == 0 ? (S / 64.0) : (S / ppu)
            let effectScaledWidth = this.effectSize.x * scaleFactor * scaleX
            let effectScaledHeight = this.effectSize.y * scaleFactor * scaleY
            // Offset to center the larger effect texture over the original sprite position
            centeredX -= (effectScaledWidth - scaledWidth) / 2
            centeredY -= (effectScaledHeight - scaledHeight) / 2
            // Use effect dimensions for rendering
            scaledWidth = effectScaledWidth
            scaledHeight = effectScaledHeight
        }
    
        // Select float or integer precision
        if (this.isFloatPrecision) {
            let dstRect = (globalThis as any).JulGameSdl.glue_SDL_FRect(centeredX, centeredY, scaledWidth, scaledHeight)
        } else {
            dstRect = (globalThis as any).JulGameSdl.glue_SDL_Rect(
                Math.round(centeredX),
                Math.round(centeredY),
                Math.round(scaledWidth),
                Math.round(scaledHeight)
            )
        }
    
        // Calculate center for rotation
        let calculatedCenter = {x: dstRect.w * (this.center.x % 1), y: dstRect.h * (this.center.y % 1)}
        let rotationCenter = !this.isFloatPrecision ? 
            (globalThis as any).JulGameSdl.glue_SDL_Point(Math.round(calculatedCenter.x), Math.round(calculatedCenter.y)) :
            (globalThis as any).JulGameSdl.glue_SDL_FPoint(calculatedCenter.x, calculatedCenter.y)
    
        this.lastRenderedScreenPosition = {x: convert(Float64, dstRect.x), y: convert(Float64, dstRect.y)}
        this.lastRenderedScreenSize = {x: convert(Float64, dstRect.w), y: convert(Float64, dstRect.h)}
        // Render with appropriate precision
        let renderFn = this.isFloatPrecision ? SDL2.SDL_RenderCopyExF : SDL2.SDL_RenderCopyEx
        if (renderFn() {
            (globalThis as any).JulGame.Renderer, 
            texture_to_render, 
            srcRect, 
            dstRect,
            this.rotation, 
            rotationCenter, 
            this.isFlipped ? SDL2.SDL_FLIP_HORIZONTAL : SDL2.SDL_FLIP_NONE
        ) != 0
            error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())
        }
    }

    function Component_initialize(this: InternalSprite) {
        if (this.image == null) {
            return
        }

        this.texture = get_or_create_texture(this.imagePath, this.image)
    }

    function Component_flip(this: InternalSprite) {
        this.isFlipped = !this.isFlipped
    }
    
    // Shared effect texture cache for sprites (keyed by image+size+effects, not instance)
    const SPRITE_EFFECT_CACHE = Dict{String, Tuple{Ptr{SDL2.SDL_Texture}, Vector2}}()

    // Shared texture cache for base images (keyed by image path)
    const TEXTURE_CACHE = Dict{String, Ptr{SDL2.SDL_Texture}}()

    function get_or_create_texture(imagePath: string,  surface: SDL_Surface}) {
        if (haskey(TEXTURE_CACHE, imagePath)) {
            console.debug("Using cached texture for: $(imagePath)")
            return TEXTURE_CACHE[imagePath]
        }
        let tex = (globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface((globalThis as any).JulGame.Renderer, surface)
        if (tex != null) {
            TEXTURE_CACHE[imagePath] = tex
            console.debug("Created and cached texture for: $(imagePath)")
        } else {
            @error("Failed to create texture for: $(imagePath)")
        }
        return tex
    }
    
    function serialize_effects(effects: any[]): string
        if (isempty(effects)) {
            return "[]"
        }
        let parts = []
        for (const eff of effects) {
            let T = typeof(eff)
            let fnames = fieldnames(T)
            let vals = []
            for (const f of fnames) {
                let v = getfield(eff, f)
                if (v isa Ptr) {
                    vals.push(string(f, "=Ptr"))
                } else {
                    vals.push(string(f, "=", v))
                }
            }
            parts.push(string(nameof(T), "(", join(vals, ","), ")"))
        }
        return "[" * join(parts, ";") * "]"
    }
    
    function generate_effect_cache_key(this: InternalSprite): string
        // Cache key based on image path, size, and effects - NOT instance ID
        // This allows sharing effect textures across sprites with same visuals
        let content = string(
            this.imagePath, "|",
            this.size.x, "x", this.size.y, "|",
            serialize_effects(this.effects)
        )
        return string(hash(content))
    }
    
    //  effects API
    function Component_apply_effects(this: InternalSprite,  effects: Vector) {
        this.effects = Any[effect for effect in effects]  // Convert to Vector{Any}
        
        // Generate cache key and check if we need to recompute
        let newKey = generate_effect_cache_key(this)
        if (this.effectCacheKey == newKey && this.effectTexture != null) {
            // Already have this effect cached on this sprite
            console.debug("Sprite.apply_effects!: cache key unchanged; skipping recompute") path=this.imagePath

        }
        
        this.effectCacheKey = newKey
        this.needsEffectUpdate = true
        update_effects(this)

    }
    
    function apply_style(this: InternalSprite,  style) {
        return apply_effects(this, style.effects)
    }
    
    function update_effects(this: InternalSprite) {
        if (isempty(this.effects) || !this.needsEffectUpdate) {
            return
        }
        
        // Check shared cache first
        if (haskey(SPRITE_EFFECT_CACHE, this.effectCacheKey)) {
            let cached = SPRITE_EFFECT_CACHE[this.effectCacheKey]
            this.effectTexture = cached[0]
            this.effectSize = cached[1]
            this.needsEffectUpdate = false
            console.debug("Sprite // using cached effect texture") path=this.imagePath key=this.effectCacheKey
            return
        }
        
        // Create target for effects
        let target = (globalThis as any).(globalThis as any).JulGame.EffectsModule.SpriteTarget(this)
        
        // Apply effects
        try {
            let result = (globalThis as any).(globalThis as any).JulGame.EffectRendererModule.apply_effects(target, this.effects)
            if (result isa (globalThis as any).(globalThis as any).JulGame.EffectsModule.SpriteTarget) {
                // Effect texture should be updated by the renderer
                // Query the effect texture size and store it
                if (this.effectTexture != null) {
                    let w = Ref{Cint}(0); h = Ref{Cint}(0)
                    let fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
                    (globalThis as any).JulGameSdl.glue_SDL_QueryTexture(this.effectTexture, fmt, access, w, h)
                    this.effectSize = {x: w, y: h}
                    
                    // Cache the result for other sprites with same visuals
                    SPRITE_EFFECT_CACHE[this.effectCacheKey] = [this.effectTexture, this.effectSize]
                    console.debug("Cached sprite effect texture") path=this.imagePath key=this.effectCacheKey
                }
                this.needsEffectUpdate = false
            }
        } catch (e) {
            @error("Failed to apply effects to sprite: $e")
        }
    }
    
    function clear_sprite_effects_cache() {
        for (key, cached) in SPRITE_EFFECT_CACHE
            if (cached[0] != null) {
                (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(cached[0])
            }
        }
        empty(SPRITE_EFFECT_CACHE)
    }

    function get_effect_cache_snapshot() {
        let snapshot = []
        for (key, cached) in SPRITE_EFFECT_CACHE
            let texture = cached[0]
            let size = cached[1]
            let width = Int(Math.round(size.x))
            let height = Int(Math.round(size.y))
            if ((width <= 0 || height <= 0) && texture != null) {
                w = Ref{Cint}(0)
                let h = Ref{Cint}(0)
                fmt = Ref{UInt32}(0)
                let access = Ref{Cint}(0)
                if ((globalThis as any).JulGameSdl.glue_SDL_QueryTexture(texture, fmt, access, w, h) == 0) {
                    width = Int(w)
                    height = Int(h)
                }
            }
            snapshot.push((
                let key = key,
                texture = texture,
                width = width,
                height = height,
                let approxBytes = width * height * 4,
            ))
        }
        return snapshot
    }

    function clear_texture_cache() {
        for (key, tex) in TEXTURE_CACHE
            if (tex != null) {
                (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(tex)
            }
        }
        empty(TEXTURE_CACHE)
    }

    const FALLBACK_IMAGE_BYTES = UInt8[
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x20, 
        0x00, 0x00, 0x00, 0x20, 0x08, 0x06, 0x00, 0x00, 0x00, 0x73, 0x7a, 0x7a, 0xf4, 0x00, 0x00, 0x00, 0x01, 0x73, 0x52, 0x47, 
        0x42, 0x00, 0xae, 0xce, 0x1c, 0xe9, 0x00, 0x00, 0x01, 0x02, 0x49, 0x44, 0x41, 0x54, 0x58, 0x85, 0xdd, 0x96, 0x4b, 0x0e, 
        0x83, 0x30, 0x0c, 0x44, 0xed, 0xaa, 0x57, 0x61, 0xc9, 0x02, 0x72, 0x14, 0xae, 0x59, 0x8e, 0x12, 0x75, 0xd1, 0x25, 0x87, 
        0x71, 0x37, 0x0d, 0xa2, 0x40, 0xc3, 0xd8, 0x71, 0x68, 0xd5, 0x59, 0x81, 0x64, 0x65, 0x5e, 0x7e, 0x9e, 0x30, 0x01, 0x12, 
        0x11, 0x41, 0xea, 0x98, 0x99, 0x91, 0xba, 0xa5, 0xae, 0x88, 0xf9, 0x18, 0x02, 0x34, 0x58, 0x02, 0xd5, 0x80, 0x1c, 0x16, 
        0xde, 0xfa, 0x7e, 0x33, 0xfb, 0xb6, 0xe9, 0x36, 0x75, 0x8f, 0xe9, 0x3e, 0x7f, 0x0f, 0x31, 0xc2, 0x10, 0xd9, 0x22, 0x64, 
        0xf6, 0x6b, 0x98, 0x04, 0x82, 0x42, 0x7c, 0x2c, 0xd0, 0x2c, 0xfd, 0x1a, 0x44, 0x03, 0x71, 0x78, 0x06, 0x50, 0x2d, 0xb7, 
        0xa0, 0x6d, 0xba, 0xb7, 0xff, 0x9c, 0x2e, 0x5e, 0x00, 0x56, 0xfd, 0x27, 0x00, 0xba, 0xfc, 0x59, 0x00, 0x66, 0xe6, 0x21, 
        0x46, 0x17, 0x20, 0x13, 0x40, 0xa9, 0xd0, 0x6b, 0xf8, 0xdb, 0x67, 0xe0, 0x8c, 0x6d, 0xa8, 0xb2, 0x02, 0x9a, 0x56, 0xec, 
        0x0e, 0xa0, 0x31, 0x27, 0x02, 0xc2, 0x88, 0x08, 0x6f, 0xcb, 0x5a, 0x73, 0x18, 0x00, 0x81, 0xb0, 0x98, 0xab, 0x00, 0x72, 
        0x10, 0x56, 0x73, 0x35, 0x40, 0x82, 0x20, 0x22, 0x4a, 0x20, 0x25, 0xe6, 0x45, 0x92, 0x97, 0x4e, 0x37, 0xf6, 0x96, 0x79, 
        0x0b, 0x76, 0x07, 0xab, 0xf1, 0x28, 0x5d, 0x9b, 0xe7, 0x6e, 0x82, 0x88, 0x88, 0x16, 0x02, 0x06, 0xc8, 0x99, 0xa7, 0xe7, 
        0xd8, 0x18, 0x82, 0x1a, 0xc2, 0xa5, 0x13, 0xa6, 0xfc, 0x6f, 0x9b, 0x6e, 0x86, 0x38, 0x15, 0x60, 0x09, 0xa1, 0x95, 0x6b, 
        0x16, 0x58, 0x20, 0x60, 0x80, 0x5a, 0xd1, 0x6c, 0xba, 0x86, 0x9e, 0x99, 0x60, 0x6a, 0xa1, 0x9e, 0x99, 0x60, 0xee, 0xe1, 
        0x7b, 0x27, 0xfd, 0x2b, 0x99, 0x50, 0xaa, 0x27, 0x9d, 0x07, 0x96, 0x9b, 0xca, 0xab, 0x4b, 0x6c, 0x00, 0x00, 0x00, 0x00, 
        0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82
    ]  // This is a 1x1 transparent PNG image.

    function load_fallback_image() {
        let rwops = (globalThis as any).JulGameSdl.glue_SDL_RWFromMem(pointer(FALLBACK_IMAGE_BYTES), FALLBACK_IMAGE_BYTES.length)
        if (rwops == null) {
            @error("Failed to create SDL_RWops for fallback image.")
            return null
        }
        let image = SDL2.IMG_Load_RW(rwops, 1)  // Load directly from memory and free rwops after use
        return image
    }

    function Component_load_image(this: InternalSprite,  imagePath: string) {
        (globalThis as any).JulGameSdl.glue_SDL_ClearError()

        let fullPath = joinpath(BasePath, "assets", "images", imagePath)
        this.image = load_image_sdl(fullPath, imagePath)
        error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())
    
        if (!isempty(error) || this.image == null) {
            try {
                throw(error)
            } catch (e) {
                @error("Error loading image '$imagePath'! SDL Error: ", e)
                Base.show_backtrace(stdout, catch_backtrace()) // Backtrace won't be shown if we don't throw the error
            }
            (globalThis as any).JulGameSdl.glue_SDL_ClearError()
    
            // Load from byte array
            this.image = load_fallback_image()
            setfield(this, :imagePath, "fallback.png")
            this.pixelsPerUnit = 0
            if (this.image == null) {
                @error("Fallback image also failed to load! $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
                return
            }
        } else if (this.imagePath != imagePath) {
            this.imagePath = imagePath
        }
    
        // Get image size
        surface = unsafe_wrap(Array, this.image, 10; own = false)
        this.size = {x: surface[0].w, y: surface[0].h}

        // Create or get cached texture
        this.texture = get_or_create_texture(this.imagePath, this.image)

        if (this.texture == null) {
            @error("Failed to create texture from image.")
            Base.show_backtrace(stdout, catch_backtrace())
            return
        }

        Component_set_color(this)
    }

    function load_image_sdl(fullPath: string,  imagePath: string) {
        let commaSeparatedPath = (globalThis as any).JulGame.get_comma_separated_path(imagePath)
        if (haskey((globalThis as any).JulGame.IMAGE_CACHE, commaSeparatedPath)) {
            let raw_data = (globalThis as any).JulGame.IMAGE_CACHE[commaSeparatedPath]
            let rw = (globalThis as any).JulGameSdl.glue_SDL_RWFromConstMem(pointer(raw_data), raw_data.length)
            if (rw != null) {
                console.debug("loading image from cache")
                console.debug("comma separated path: ", commaSeparatedPath)
                return SDL2.IMG_Load_RW(rw, 1)
            }
        }
        console.debug("Loading image from disk $(fullPath) for sprite, there are $((globalThis as any).JulGame.IMAGE_CACHE.length) images in cache")

        return SDL2.IMG_Load(fullPath)
    }

    function Component_destroy(this: InternalSprite) {
        if (this.image == null) {
            return
        }

        // Only destroy texture if it's not in the shared cache
        if (this.texture != null && !haskey(TEXTURE_CACHE, this.imagePath)) {
            (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(this.texture)
        }
        this.image = null
        this.texture = null
    }

    function Component_set_color(this: InternalSprite) {
        (globalThis as any).JulGameSdl.glue_SDL_SetTextureColorMod(this.texture, UInt8(clamp(this.color[0], 0, 255)), UInt8(clamp(this.color[1], 0, 255)), UInt8(clamp(this.color[2], 0, 255)));
        (globalThis as any).JulGameSdl.glue_SDL_SetTextureAlphaMod(this.texture, UInt8(clamp(this.color[3], 0, 255)));
    }

    function Component_duplicate(this: InternalSprite,  parent: any) {
        let newSprite = new InternalSprite(parent, this.imagePath, this.crop, this.isFlipped, this.color, false; pixelsPerUnit=this.pixelsPerUnit, position=this.position, rotation=this.rotation, layer=this.layer, center=this.center, anchor=this.anchor, offset=this.offset, isStatic=this.isStatic)
        newSprite.interactionScale = this.interactionScale
        Component_initialize(newSprite)
        return newSprite
    }

    function Component_is_mouse_hovering(this: InternalSprite) {
       // TODO: check if the mouse is hovering over any of the sprites pixels
       return false
    }

