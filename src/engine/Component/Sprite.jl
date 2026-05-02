module SpriteModule
    using ..Component.JulGame
    using ..Component.JulGame.ResourceModule
    import ..Component
    # Effects imports - will be available after Effects module is loaded
    import ..Component.JulGame as JG

    export Sprite
    struct Sprite
        color::NTuple{4, Int}
        crop::Union{Ptr{Nothing}, Math.Vector4}
        isFlipped::Bool
        imagePath::String
        layer::Int
        offset::Math.Vector2f
        position::Math.Vector2f
        rotation::Float64
        pixelsPerUnit::Int
        center::Math.Vector2f
        anchor::Symbol
        isStatic::Bool
    end

    export InternalSprite
    mutable struct InternalSprite <: JulGame.ISprite 
        imagePath::String
        layer::Int
        offset::Math.Vector2f
        center::Math.Vector2f
        rotation::Float64
        color::NTuple{4, Int}
        crop::Union{Ptr{Nothing}, Math.Vector4}
        isFlipped::Bool
        isFloatPrecision::Bool
        image::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Surface}}
        parent::JulGame.IEntity # Entity
        lastRenderedScreenPosition::Union{Math.Vector2f, Nothing}
        lastRenderedScreenSize::Union{Math.Vector2f, Nothing}
        pixelsPerUnit::Int
        size::Math.Vector2
        texture::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Texture}}
        position::Math.Vector2f
        anchor::Symbol
        isStatic::Bool
        #  effects support
        effects::Vector{Any}  # Will hold Effect objects
        effectTexture::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Texture}}
        effectSize::Math.Vector2  # Size of effect texture (may be larger due to glow padding)
        effectCacheKey::String  # Cache key for sharing effect textures
        needsEffectUpdate::Bool
        useEffectTexture::Bool  # Toggle to enable/disable effect texture rendering
        interactionScale::Float64  # Scale factor for hover/click hitbox (1.0 = full size, <1.0 = smaller)
        
        function InternalSprite(
            parent::JulGame.IEntity, 
            imagePath::String, 
            crop::Union{Ptr{Nothing}, Math.Vector4}=C_NULL, 
            isFlipped::Bool=false, 
            color::NTuple{4, Int} = (255,255,255,255), 
            isCreatedInEditor::Bool=false; 
            pixelsPerUnit::Int=0, 
            position::Math.Vector2f = Math.Vector2f(0,0), 
            rotation::Float64 = 0.0, 
            layer::Int = 0, 
            center::Math.Vector2f = Math.Vector2f(0.5,0.5), 
            anchor::Symbol = :center, 
            offset::Math.Vector2f = Math.Vector2f(0,0), 
            isStatic::Bool = false
        )
            this = new()

            this.offset = offset
            this.isFlipped = isFlipped
            @debug "attemping to load sprite with path: $(imagePath)"
            this.imagePath = imagePath
            this.center = center
            this.color = color
            this.crop = crop
            this.image = C_NULL
            this.layer = layer
            this.parent = parent
            this.pixelsPerUnit = pixelsPerUnit
            this.position = position
            this.rotation = rotation
            this.texture = C_NULL
            this.isFloatPrecision = false
            this.lastRenderedScreenPosition = nothing
            this.lastRenderedScreenSize = nothing
            this.anchor = anchor

            this.isStatic = isStatic
            
            # Initialize effects
            this.effects = Any[]
            this.effectTexture = C_NULL
            this.effectSize = Math._Vector2{Int32}(0, 0)
            this.effectCacheKey = ""
            this.needsEffectUpdate = false
            this.useEffectTexture = true  # Default to showing effects when applied
            this.interactionScale = 1.0  # Default to full-size hitbox

            # Early returns
            if isCreatedInEditor
                return this
            end

            Component.load_image(this::InternalSprite, imagePath::String)
            if this.image == C_NULL
                error = unsafe_string(SDL2.SDL_GetError())
                @error string("Couldn't open image! SDL Error: ", error)
                return this
            end
            surface = unsafe_wrap(Array, this.image, 10; own = false)
            this.size = Math._Vector2{Int32}(surface[1].w, surface[1].h)
        
            return this
        end
    end
    
    function Component.draw(this::InternalSprite, camera = nothing)
        if this.image == C_NULL || JulGame.Renderer::Ptr{SDL2.SDL_Renderer} == C_NULL
            return
        end
        
        # Update effects if needed
        if !isempty(this.effects) && this.needsEffectUpdate
            update_effects(this)
        end
    
        # Use effect texture if available and enabled, otherwise use regular texture
        texture_to_render = if this.useEffectTexture && !isempty(this.effects) && this.effectTexture != C_NULL
            this.effectTexture
        else
            # Create or get cached texture if it doesn't exist
            if this.texture == C_NULL && this.image != C_NULL
                this.texture = get_or_create_texture(this.imagePath, this.image)
                Component.set_color(this)
            end
            this.texture
        end
    
        # Check and set color if necessary (for both regular and effect textures)
        colorRefs = (Ref(UInt8(0)), Ref(UInt8(0)), Ref(UInt8(0)))
        alphaRef = Ref(UInt8(0))
        SDL2.SDL_GetTextureColorMod(texture_to_render, colorRefs...)
        SDL2.SDL_GetTextureAlphaMod(texture_to_render, alphaRef)
        if colorRefs[1][] != this.color[1] || colorRefs[2][] != this.color[2] || colorRefs[3][] != this.color[3] || this.color[4] != alphaRef[]
            SDL2.SDL_SetTextureColorMod(texture_to_render, UInt8(clamp(this.color[1], 0, 255)), UInt8(clamp(this.color[2], 0, 255)), UInt8(clamp(this.color[3], 0, 255)))
            SDL2.SDL_SetTextureAlphaMod(texture_to_render, UInt8(clamp(this.color[4], 0, 255)))
        end
    
        S = JulGame.pixels_per_world_unit(camera)
        # Calculate camera difference
        cameraDiff = camera !== nothing ? 
            Math.Vector2((camera.position.x + camera.offset.x) * S, (camera.position.y + camera.offset.y) * S) : 
            Math.Vector2(0, 0)
    
        # Calculate position
        position = this.parent.transform.position
    
        # Calculate source rectangle
        srcRect = (this.crop == Math.Vector4(0, 0, 0, 0) || this.crop == C_NULL) ? C_NULL : Ref(SDL2.SDL_Rect(this.crop.x, this.crop.y, this.crop.z, this.crop.t))
    
        # Calculate pixels per unit
        ppu = this.pixelsPerUnit > 0 ? this.pixelsPerUnit : JulGame.PIXELS_PER_UNIT
    
        # Check if using effect texture
        usingEffectTex = texture_to_render == this.effectTexture && this.effectSize != Math.Vector2(0, 0)
        
        # Always use original sprite size for positioning calculations
        cropWidth = srcRect == C_NULL ? this.size.x : this.crop.z
        cropHeight = srcRect == C_NULL ? this.size.y : this.crop.t
        scaleX = this.parent.transform.scale.x
        scaleY = this.parent.transform.scale.y
    
        # Compute position adjustment
        adjustedX = (position.x + this.offset.x) * S - cameraDiff.x
        adjustedY = (position.y + this.offset.y) * S - cameraDiff.y
    
        # Handle pixelsPerUnit == 0 (use true size without scaling)
        if this.pixelsPerUnit == 0
            scaledWidth = cropWidth * scaleX * S / 64.0
            scaledHeight = cropHeight * scaleY * S / 64.0
        else
            # Use pixelsPerUnit or default PIXELS_PER_UNIT for scaling
            ppu = this.pixelsPerUnit > 0 ? this.pixelsPerUnit : JulGame.PIXELS_PER_UNIT
            scaleFactor = S / ppu
            scaledWidth = cropWidth * scaleFactor * scaleX
            scaledHeight = cropHeight * scaleFactor * scaleY
        end
    
        # Compute position based on anchor (using original sprite dimensions)
        centeredX = adjustedX
        centeredY = adjustedY
        
        # Apply anchor positioning
        if this.anchor == :center
            # Center anchor (default behavior)
            centeredX -= (scaledWidth - S * scaleX) / 2
            centeredY -= (scaledHeight - S * scaleY) / 2
        elseif this.anchor == :top
            # Top anchor
            centeredX -= (scaledWidth - S * scaleX) / 2
            # No adjustment for Y
        elseif this.anchor == :bottom
            # Bottom anchor
            centeredX -= (scaledWidth - S * scaleX) / 2
            centeredY -= (scaledHeight - S * scaleY)
        elseif this.anchor == :left
            # Left anchor
            centeredY -= (scaledHeight - S * scaleY) / 2
            # No adjustment for X
        elseif this.anchor == :right
            # Right anchor
            centeredX -= (scaledWidth - S * scaleX)
            centeredY -= (scaledHeight - S * scaleY) / 2
        elseif this.anchor == :topleft
            # Top-left anchor
            # No adjustment needed
        elseif this.anchor == :topright
            # Top-right anchor
            centeredX -= (scaledWidth - S * scaleX)
        elseif this.anchor == :bottomleft
            # Bottom-left anchor
            centeredY -= (scaledHeight - S * scaleY)
        elseif this.anchor == :bottomright
            # Bottom-right anchor
            centeredX -= (scaledWidth - S * scaleX)
            centeredY -= (scaledHeight - S * scaleY)
        end
        
        # AFTER anchor positioning: expand render size for effect texture and offset to center it
        if usingEffectTex
            scaleFactor = this.pixelsPerUnit == 0 ? (S / 64.0) : (S / ppu)
            effectScaledWidth = this.effectSize.x * scaleFactor * scaleX
            effectScaledHeight = this.effectSize.y * scaleFactor * scaleY
            # Offset to center the larger effect texture over the original sprite position
            centeredX -= (effectScaledWidth - scaledWidth) / 2
            centeredY -= (effectScaledHeight - scaledHeight) / 2
            # Use effect dimensions for rendering
            scaledWidth = effectScaledWidth
            scaledHeight = effectScaledHeight
        end
    
        # Select float or integer precision
        if this.isFloatPrecision
            dstRect = Ref(SDL2.SDL_FRect(centeredX, centeredY, scaledWidth, scaledHeight))
        else
            dstRect = Ref(SDL2.SDL_Rect(
                Math.TypeConversions.safe_int32_convert(round(centeredX)),
                Math.TypeConversions.safe_int32_convert(round(centeredY)),
                Math.TypeConversions.safe_int32_convert(round(scaledWidth)),
                Math.TypeConversions.safe_int32_convert(round(scaledHeight))
            ))
        end
    
        # Calculate center for rotation
        calculatedCenter = Math.Vector2(dstRect[].w * (this.center.x % 1), dstRect[].h * (this.center.y % 1))
        rotationCenter = !this.isFloatPrecision ? 
            Ref(SDL2.SDL_Point(Math.TypeConversions.safe_int32_convert(round(calculatedCenter.x)), Math.TypeConversions.safe_int32_convert(round(calculatedCenter.y)))) :
            Ref(SDL2.SDL_FPoint(calculatedCenter.x, calculatedCenter.y))
    
        this.lastRenderedScreenPosition = Math.Vector2f(convert(Float64, dstRect[].x), convert(Float64, dstRect[].y))
        this.lastRenderedScreenSize = Math.Vector2f(convert(Float64, dstRect[].w), convert(Float64, dstRect[].h))
        # Render with appropriate precision
        renderFn = this.isFloatPrecision ? SDL2.SDL_RenderCopyExF : SDL2.SDL_RenderCopyEx
        if renderFn(
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
            texture_to_render, 
            srcRect, 
            dstRect,
            this.rotation, 
            rotationCenter, 
            this.isFlipped ? SDL2.SDL_FLIP_HORIZONTAL : SDL2.SDL_FLIP_NONE
        ) != 0
            error = unsafe_string(SDL2.SDL_GetError())
        end
    end

    function Component.initialize(this::InternalSprite)
        if this.image == C_NULL
            return
        end

        this.texture = get_or_create_texture(this.imagePath, this.image)
    end

    function Component.flip(this::InternalSprite)
        this.isFlipped = !this.isFlipped
    end
    
    # Shared effect texture cache for sprites (keyed by image+size+effects, not instance)
    const SPRITE_EFFECT_CACHE = Dict{String, Tuple{Ptr{SDL2.SDL_Texture}, Math.Vector2}}()

    # Shared texture cache for base images (keyed by image path)
    const TEXTURE_CACHE = Dict{String, Ptr{SDL2.SDL_Texture}}()

    function get_or_create_texture(imagePath::String, surface::Ptr{SDL2.LibSDL2.SDL_Surface})
        if haskey(TEXTURE_CACHE, imagePath)
            @debug("Using cached texture for: $(imagePath)")
            return TEXTURE_CACHE[imagePath]
        end
        tex = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, surface)
        if tex != C_NULL
            TEXTURE_CACHE[imagePath] = tex
            @debug("Created and cached texture for: $(imagePath)")
        else
            @error("Failed to create texture for: $(imagePath)")
        end
        return tex
    end
    
    function serialize_effects(effects::Vector{Any})::String
        if isempty(effects)
            return "[]"
        end
        parts = String[]
        for eff in effects
            T = typeof(eff)
            fnames = fieldnames(T)
            vals = String[]
            for f in fnames
                v = getfield(eff, f)
                if v isa Ptr
                    push!(vals, string(f, "=Ptr"))
                else
                    push!(vals, string(f, "=", v))
                end
            end
            push!(parts, string(nameof(T), "(", join(vals, ","), ")"))
        end
        return "[" * join(parts, ";") * "]"
    end
    
    function generate_effect_cache_key(this::InternalSprite)::String
        # Cache key based on image path, size, and effects - NOT instance ID
        # This allows sharing effect textures across sprites with same visuals
        content = string(
            this.imagePath, "|",
            this.size.x, "x", this.size.y, "|",
            serialize_effects(this.effects)
        )
        return string(hash(content))
    end
    
    #  effects API
    function Component.apply_effects!(this::InternalSprite, effects::Vector)
        this.effects = Any[effect for effect in effects]  # Convert to Vector{Any}
        
        # Generate cache key and check if we need to recompute
        newKey = generate_effect_cache_key(this)
        if this.effectCacheKey == newKey && this.effectTexture != C_NULL
            # Already have this effect cached on this sprite
            @debug "Sprite.apply_effects!: cache key unchanged; skipping recompute" path=this.imagePath
            return this
        end
        
        this.effectCacheKey = newKey
        this.needsEffectUpdate = true
        update_effects(this)
        return this
    end
    
    function apply_style!(this::InternalSprite, style)
        return apply_effects!(this, style.effects)
    end
    
    function update_effects(this::InternalSprite)
        if isempty(this.effects) || !this.needsEffectUpdate
            return
        end
        
        # Check shared cache first
        if haskey(SPRITE_EFFECT_CACHE, this.effectCacheKey)
            cached = SPRITE_EFFECT_CACHE[this.effectCacheKey]
            this.effectTexture = cached[1]
            this.effectSize = cached[2]
            this.needsEffectUpdate = false
            @debug "Sprite using cached effect texture" path=this.imagePath key=this.effectCacheKey
            return
        end
        
        # Create target for effects
        target = JG.EffectsModule.SpriteTarget(this)
        
        # Apply effects
        try
            result = JG.EffectRendererModule.apply_effects!(target, this.effects)
            if result isa JG.EffectsModule.SpriteTarget
                # Effect texture should be updated by the renderer
                # Query the effect texture size and store it
                if this.effectTexture != C_NULL
                    w = Ref{Cint}(0); h = Ref{Cint}(0)
                    fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
                    SDL2.SDL_QueryTexture(this.effectTexture, fmt, access, w, h)
                    this.effectSize = Math.Vector2(w[], h[])
                    
                    # Cache the result for other sprites with same visuals
                    SPRITE_EFFECT_CACHE[this.effectCacheKey] = (this.effectTexture, this.effectSize)
                    @debug "Cached sprite effect texture" path=this.imagePath key=this.effectCacheKey
                end
                this.needsEffectUpdate = false
            end
        catch e
            @error("Failed to apply effects to sprite: $e")
        end
    end
    
    function clear_sprite_effects_cache()
        for (key, cached) in SPRITE_EFFECT_CACHE
            if cached[1] != C_NULL
                SDL2.SDL_DestroyTexture(cached[1])
            end
        end
        empty!(SPRITE_EFFECT_CACHE)
    end

    function get_effect_cache_snapshot()
        snapshot = NamedTuple[]
        for (key, cached) in SPRITE_EFFECT_CACHE
            texture = cached[1]
            size = cached[2]
            width = Int(round(size.x))
            height = Int(round(size.y))
            if (width <= 0 || height <= 0) && texture != C_NULL
                w = Ref{Cint}(0)
                h = Ref{Cint}(0)
                fmt = Ref{UInt32}(0)
                access = Ref{Cint}(0)
                if SDL2.SDL_QueryTexture(texture, fmt, access, w, h) == 0
                    width = Int(w[])
                    height = Int(h[])
                end
            end
            push!(snapshot, (
                key = key,
                texture = texture,
                width = width,
                height = height,
                approxBytes = width * height * 4,
            ))
        end
        return snapshot
    end

    function clear_texture_cache()
        for (key, tex) in TEXTURE_CACHE
            if tex != C_NULL
                SDL2.SDL_DestroyTexture(tex)
            end
        end
        empty!(TEXTURE_CACHE)
    end

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
    ]  # This is a 1x1 transparent PNG image.

    function load_fallback_image()
        rwops = SDL2.SDL_RWFromMem(pointer(FALLBACK_IMAGE_BYTES), length(FALLBACK_IMAGE_BYTES))
        if rwops == C_NULL
            @error("Failed to create SDL_RWops for fallback image.")
            return C_NULL
        end
        image = SDL2.IMG_Load_RW(rwops, 1)  # Load directly from memory and free rwops after use
        return image
    end

    function Component.load_image(this::InternalSprite, imagePath::String)
        SDL2.SDL_ClearError()

        fullPath = joinpath(BasePath, "assets", "images", imagePath)
        this.image = load_image_sdl(fullPath, imagePath)
        error = unsafe_string(SDL2.SDL_GetError())
    
        if !isempty(error) || this.image == C_NULL
            try
                throw(error)
            catch e
                @error("Error loading image '$imagePath'! SDL Error: ", e)
            end
            SDL2.SDL_ClearError()
    
            # Load from byte array
            this.image = load_fallback_image()
            setfield!(this, :imagePath, "fallback.png")
            this.pixelsPerUnit = 0
            if this.image == C_NULL
                @error("Fallback image also failed to load! $(unsafe_string(SDL2.SDL_GetError()))")
                return
            end
        elseif this.imagePath != imagePath
            this.imagePath = imagePath
        end
    
        # Get image size
        surface = unsafe_wrap(Array, this.image, 10; own = false)
        this.size = Math._Vector2{Int32}(surface[1].w, surface[1].h)

        # Create or get cached texture
        this.texture = get_or_create_texture(this.imagePath, this.image)

        if this.texture == C_NULL
            @error("Failed to create texture from image.")
            return
        end

        Component.set_color(this)
    end

    function load_image_sdl(fullPath::String, imagePath::String)
        commaSeparatedPath = JulGame.get_comma_separated_path(imagePath)
        if haskey(JulGame.IMAGE_CACHE, commaSeparatedPath)
            raw_data = JulGame.IMAGE_CACHE[commaSeparatedPath]
            rw = SDL2.SDL_RWFromConstMem(pointer(raw_data), length(raw_data))
            if rw != C_NULL
                @debug("loading image from cache")
                @debug("comma separated path: ", commaSeparatedPath)
                return SDL2.IMG_Load_RW(rw, 1)
            end
        end
        @debug "Loading image from disk $(fullPath) for sprite, there are $(length(JulGame.IMAGE_CACHE)) images in cache"

        return SDL2.IMG_Load(fullPath)
    end

    function Component.destroy(this::InternalSprite)
        if this.image == C_NULL
            return
        end

        # Only destroy texture if it's not in the shared cache
        if this.texture != C_NULL && !haskey(TEXTURE_CACHE, this.imagePath)
            SDL2.SDL_DestroyTexture(this.texture)
        end
        this.image = C_NULL
        this.texture = C_NULL
    end

    function Component.set_color(this::InternalSprite)
        SDL2.SDL_SetTextureColorMod(this.texture, UInt8(clamp(this.color[1], 0, 255)), UInt8(clamp(this.color[2], 0, 255)), UInt8(clamp(this.color[3], 0, 255)));
        SDL2.SDL_SetTextureAlphaMod(this.texture, UInt8(clamp(this.color[4], 0, 255)));
    end

    function Component.duplicate(this::InternalSprite, parent::Any)
        newSprite = InternalSprite(parent, this.imagePath, this.crop, this.isFlipped, this.color, false; pixelsPerUnit=this.pixelsPerUnit, position=this.position, rotation=this.rotation, layer=this.layer, center=this.center, anchor=this.anchor, offset=this.offset, isStatic=this.isStatic)
        newSprite.interactionScale = this.interactionScale
        Component.initialize(newSprite)
        return newSprite
    end

    function Component.is_mouse_hovering(this::InternalSprite)
       # TODO: check if the mouse is hovering over any of the sprites pixels
       return false
    end

    """Mark static-sprite layer dirty when MAIN is set; uses typeassert so `--trim` sees `MainLoop.scene`, not `Any`."""
    function _mark_static_layer_rebatch_if_main!(layer::Int)
        m = JulGame.MAIN
        m === nothing && return
        JulGame.StaticSpriteBatcherModule.mark_layer_for_rebatch((m::JulGame.MainLoop).scene, layer)
    end

    function Base.setproperty!(this::InternalSprite, s::Symbol, x)
        @debug("setting sprite property $(s) to: $(x)")
        try
            # Track if this is a static sprite property change that requires rebatching
            needs_rebatch = false
            
            if s == :imagePath
                @debug("setting imagePath to: $(x)")
                if !isdefined(this, :imagePath) || (this.imagePath != x && !isempty(x))
                    # Reload the image, cleaning up the old one first
                    setfield!(this, s, String(x))
                    Component.load_image(this, String(x))
                    needs_rebatch = isdefined(this, :isStatic) && this.isStatic
                end
                if needs_rebatch
                    _mark_static_layer_rebatch_if_main!(this.layer)
                end
                return
            end
            
            # Check if property affects rendering and sprite is static
            if isdefined(this, :isStatic) && this.isStatic && s in [:position, :rotation, :color, :crop, :isFlipped, :offset, :layer, :pixelsPerUnit]
                needs_rebatch = true
            end
            
            setfield!(this, s, x)
            
            # Mark layer for rebatch if needed
            if needs_rebatch
                _mark_static_layer_rebatch_if_main!(this.layer)
            end
        catch e
            @error "Error setting sprite property $(s) to: $(x)"
            @error sprint(showerror, e)
        end
    end
end
