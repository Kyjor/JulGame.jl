module SpriteModule
    using ..Component.JulGame
    using ..Component.JulGame.ResourceModule
    import ..Component
    # Effects imports - will be available after Effects module is loaded
    import ..Component.JulGame as JG
    include(joinpath(@__DIR__, "Sprite", "constants.jl"))
    include(joinpath(@__DIR__, "Sprite", "effects_functions.jl"))

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
        
        function InternalSprite(parent::JulGame.IEntity, imagePath::String, crop::Union{Ptr{Nothing}, Math.Vector4}=C_NULL, isFlipped::Bool=false, color::NTuple{4, Int} = (255,255,255,255), isCreatedInEditor::Bool=false; pixelsPerUnit::Int=0, position::Math.Vector2f = Math.Vector2f(0,0), rotation::Float64 = 0.0, layer::Int = 0, center::Math.Vector2f = Math.Vector2f(0.5,0.5), anchor::Symbol = :center, offset::Math.Vector2f = Math.Vector2f(0,0), isStatic::Bool = false)
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
            this.effectSize = Math.Vector2(0, 0)
            this.effectCacheKey = ""
            this.needsEffectUpdate = false
            this.useEffectTexture = true  # Default to showing effects when applied
            this.interactionScale = 1.0  # Default to full-size hitbox

            # Early returns
            if isCreatedInEditor
                return this
            end

            Component.load_image(this, imagePath)
            if this.image == C_NULL
                error = unsafe_string(SDL2.SDL_GetError())
                @error(string("Couldn't open image! path: $(fullPath) SDL Error: ", error))
                Base.show_backtrace(stdout, catch_backtrace())
                return
            end
            surface = unsafe_wrap(Array, this.image, 10; own = false)
            this.size = Math.Vector2(surface[1].w, surface[1].h)
        
            return this
        end
    end
    
    function Component.draw(this::InternalSprite, camera = nothing)
        if this.image == C_NULL || JulGame.Renderer::Ptr{SDL2.SDL_Renderer} == C_NULL
            return
        end
        
        # Update effects if needed
        if length(this.effects) > 0 && this.needsEffectUpdate
            update_effects(this)
        end
    
        # Use effect texture if available and enabled, otherwise use regular texture
        texture_to_render = nothing
        if this.useEffectTexture && length(this.effects) > 0 && this.effectTexture != C_NULL
            texture_to_render = this.effectTexture
        else
            # Create or get cached texture if it doesn't exist
            if this.texture == C_NULL && this.image != C_NULL
                this.texture = get_or_create_texture(this.imagePath, this.image)
                Component.set_color(this)
            end
            texture_to_render = this.texture
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
        crop = this.crop == C_NULL ? Math.Vector4(0, 0, 0, 0) : this.crop
        cropWidth = srcRect == C_NULL ? this.size.x : crop.z
        cropHeight = srcRect == C_NULL ? this.size.y : crop.t
        scaleX = this.parent.transform.scale.x
        scaleY = this.parent.transform.scale.y
    
        # Compute position adjustment
        # VERBOSE because of transpiler 
        adjustedX = position.x
        adjustedX += this.offset.x
        adjustedX *= S
        adjustedX -= cameraDiff.x
        adjustedY = position.y
        adjustedY += this.offset.y
        adjustedY *= S
        adjustedY -= cameraDiff.y
    
        # Handle pixelsPerUnit == 0 (use true size without scaling)
        scaledWidth = 0.0
        scaledHeight = 0.0
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
        dstRect = Ref(SDL2.SDL_FRect(centeredX, centeredY, scaledWidth, scaledHeight))
        if !this.isFloatPrecision
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
        if renderFn(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, texture_to_render, srcRect, dstRect, this.rotation, rotationCenter, this.isFlipped ? SDL2.SDL_FLIP_HORIZONTAL : SDL2.SDL_FLIP_NONE) != 0
            error = unsafe_string(SDL2.SDL_GetError())
            @error("Failed to render sprite: $error")
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

        fullPath = joinpath(JulGame.BasePath, "assets", "images", imagePath)
        this.image = load_image_sdl(fullPath, imagePath)
        error = unsafe_string(SDL2.SDL_GetError())
    
        if length(error) > 0 || this.image == C_NULL
            try
                throw(error)
            catch e
                @error("Error loading image '$imagePath'! SDL Error: ", e)
                Base.show_backtrace(stdout, catch_backtrace()) # Backtrace won't be shown if we don't throw the error
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
        this.size = Math.Vector2(surface[1].w, surface[1].h)

        # Create or get cached texture
        this.texture = get_or_create_texture(this.imagePath, this.image)

        if this.texture == C_NULL
            @error("Failed to create texture from image.")
            Base.show_backtrace(stdout, catch_backtrace())
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

    function Base.setproperty!(this::InternalSprite, s::Symbol, x)
        @debug("setting sprite property $(s) to: $(x)")
        try
            # Track if this is a static sprite property change that requires rebatching
            needs_rebatch = false
            
            if s == :imagePath
                @debug("setting imagePath to: $(x)")
                if !isdefined(this, :imagePath) || (this.imagePath != x && length(x) > 0)
                    # Reload the image, cleaning up the old one first
                    setfield!(this, s, String(x))
                    Component.load_image(this, String(x))
                    needs_rebatch = isdefined(this, :isStatic) && this.isStatic
                end
                if needs_rebatch && JulGame.MAIN !== nothing && JulGame.MAIN.scene !== nothing
                    JulGame.StaticSpriteBatcherModule.mark_layer_for_rebatch(JulGame.MAIN.scene, this.layer)
                end
                return
            end
            
            # Check if property affects rendering and sprite is static
            if isdefined(this, :isStatic) && this.isStatic && s in [:position, :rotation, :color, :crop, :isFlipped, :offset, :layer, :pixelsPerUnit]
                needs_rebatch = true
            end
            
            setfield!(this, s, x)
            
            # Mark layer for rebatch if needed
            if needs_rebatch && JulGame.MAIN !== nothing && JulGame.MAIN.scene !== nothing
                JulGame.StaticSpriteBatcherModule.mark_layer_for_rebatch(JulGame.MAIN.scene, this.layer)
            end
        catch e
            @error "Error setting sprite property $(s) to: $(x)"
            @error "Error: $e"
            Base.show_backtrace(stderr, catch_backtrace())
        end
    end
end
