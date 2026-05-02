module UIImageModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    using JulGame.EffectsModule
    using JulGame.EffectRendererModule
    using JulGame.EffectCacheModule
    include(joinpath(@__DIR__, "..", "Resource", "InternalImages.jl"))
    
    export UIImage
    mutable struct UIImage <: UI.UIElement
        path::String
        rotation::Float64
        color::NTuple{4, Int}
        crop::Union{Ptr{Nothing}, Math.Vector4}
        isFlipped::Bool
        surface::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Surface}}
        texture::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Texture}}
        #  effects support
        effects::Vector{Any}  # Will hold Effect objects
        effectTexture::Union{Ptr{SDL2.LibSDL2.SDL_Texture}, Ptr{Nothing}}
        effectSize::Math.Vector2  # Size of the effect texture (tracks glow padding separately)
        useEffectTexture::Bool  
        needsEffectUpdate::Bool
        effectCacheKey::String
         
        function UIImage(path::String="Default";
            id::String=JulGame.generate_uuid(), 
            name::String="Image",
            anchor::Symbol = :none,
            anchorOffset::Math.Vector2 = Math.Vector2(0,0), 
            crop::Union{Ptr{Nothing}, Math.Vector4} = C_NULL,
            layer::Int=0,
            position::Math.Vector2 = Math.Vector2(0,0), 
            isActive::Bool=true,
            persistentBetweenScenes::Bool=false,
            color::NTuple{4, Int}=(255, 255, 255, 255), 
            size::Math.Vector2=Math.Vector2(0,0), 
            parent::Union{UI.UIElement, Nothing, JulGame.IEntity, JulGame.ISprite}=nothing,
            rotation::Float64=0.0,
            clickEvents::Vector{Function} = Function[],
            hoverEnterEvents::Vector{Function} = Function[],
            hoverExitEvents::Vector{Function} = Function[],
            useEffectTexture::Bool = true,
            forceClickCheck::Bool = false,
        )
            this = new()

            this.anchor = JulGame.copy_enum(UI.anchor_types)
            this.isActive = isActive
            this.id = id
            this.persistentBetweenScenes = persistentBetweenScenes
            this.name = name

            this.anchor.current_state = anchor
            this.anchorOffset = anchorOffset
            this.isFlipped = false
            @debug "attemping to load image with path: $(path)"
            this.color = color
            this.crop = crop
            this.surface = C_NULL
            this.layer = layer
            this.parent = parent
            this.position = position
            this.rotation = rotation
            this.size = size
            this.useEffectTexture = useEffectTexture
            this.texture = C_NULL
            this.forceClickCheck = forceClickCheck

            # Before `this.path = …`: setproperty!(:path) touches effects / effectCacheKey / effectTexture.
            this.effects = Any[]
            this.effectTexture = C_NULL
            this.effectSize = Math.Vector2(0, 0)
            this.needsEffectUpdate = false
            this.effectCacheKey = ""

            this.path = path

            this.clickEvents = clickEvents
            this.hoverEnterEvents = hoverEnterEvents
            this.hoverExitEvents = hoverExitEvents

            return this
        end
    end
    
    function UI.render(this::UIImage)
        if (this.surface == C_NULL || 
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer} == C_NULL || 
            !this.isActive
        )
            return
        end
        if this.size == Math.Vector2(0,0)
            surface = unsafe_wrap(Array, this.surface, 10; own = false)
            this.size = Math.Vector2(surface[1].w, surface[1].h)
            this.originalSize = Math.Vector2(this.size.x, this.size.y)
        end
        UI.align_to_anchor(this)

        
        # Update effects if needed
        if this.needsEffectUpdate && !isempty(this.effects)
            @debug "Updating effects for image: $(this.name)"
            update_effects(this)
        end
    
        # Determine which texture to use
        texture_to_render = (this.useEffectTexture && !isempty(this.effects) && this.effectTexture != C_NULL) ? this.effectTexture : this.texture
        
        # Validate texture if we're using effect texture
        if texture_to_render == this.effectTexture && texture_to_render != C_NULL
            # Query texture to check if it's still valid
            w = Ref{Cint}(0); h = Ref{Cint}(0)
            fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
            if SDL2.SDL_QueryTexture(texture_to_render, fmt, access, w, h) != 0
                # Texture is invalid, fall back to base texture and clear effect texture
                @debug "Effect texture is invalid for $(this.name), falling back to base texture"
                this.effectTexture = C_NULL
                texture_to_render = this.texture
                this.needsEffectUpdate = true
            end
        end
        
        # Create texture if it doesn't exist
        if texture_to_render == C_NULL && this.texture == C_NULL
            @debug "Creating texture from surface because it doesn't exist for image: $(this.name)"
            this.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.surface)
            texture_to_render = this.texture
            UI.set_color(this)
        end
    
        # Keep SDL color modulation in sync with element.color (including when using effect textures).
        colorRefs = (Ref(UInt8(0)), Ref(UInt8(0)), Ref(UInt8(0)))
        alphaRef = Ref(UInt8(0))
        SDL2.SDL_GetTextureColorMod(texture_to_render, colorRefs...)
        SDL2.SDL_GetTextureAlphaMod(texture_to_render, alphaRef)
        if colorRefs[1][] != this.color[1] || colorRefs[2][] != this.color[2] || colorRefs[3][] != this.color[3] || this.color[4] != alphaRef[]
            UI.set_color(this)
        end
        srcRect = (this.crop == Math.Vector4(0, 0, 0, 0) || this.crop == C_NULL) ? C_NULL : Ref(SDL2.SDL_Rect(this.crop.x, this.crop.y, this.crop.z, this.crop.t))
    
        # Determine render size and position based on whether effects are being used
        adjusted_position = this.position
        render_size = this.originalSize
        
        if this.useEffectTexture && !isempty(this.effects) && this.effectTexture != C_NULL
            # When using effect texture, use the cached effectSize
            if this.effectSize != Math.Vector2(0, 0) && this.effectSize != this.originalSize
                size_diff_x = (this.effectSize.x - this.originalSize.x) / 2
                size_diff_y = (this.effectSize.y - this.originalSize.y) / 2
                adjusted_position = Math.Vector2(this.position.x - size_diff_x, this.position.y - size_diff_y)
                render_size = this.effectSize
            end
        end
        if JulGame.IS_DEBUG
            rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(255)))
            SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)
            SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 255, 255, 0, 255);
            SDL2.SDL_RenderDrawLines(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, [
                SDL2.SDL_Point(adjusted_position.x, adjusted_position.y), 
                SDL2.SDL_Point(adjusted_position.x + render_size.x, adjusted_position.y),
                SDL2.SDL_Point(adjusted_position.x + render_size.x, adjusted_position.y + render_size.y), 
                SDL2.SDL_Point(adjusted_position.x, adjusted_position.y + render_size.y), 
                SDL2.SDL_Point(adjusted_position.x, adjusted_position.y)], 5)
            SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);
        end
        @assert SDL2.SDL_RenderCopyExF(
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
            texture_to_render, 
            srcRect, 
            Ref(SDL2.SDL_FRect(adjusted_position.x, adjusted_position.y, render_size.x,render_size.y)), 
            this.rotation, 
            C_NULL, 
            SDL2.SDL_FLIP_NONE
        ) == 0 "error rendering image: $(unsafe_string(SDL2.SDL_GetError()))"
    end

    function UI.initialize(this::UIImage)
        if this.surface == C_NULL
            return
        end

        this.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.surface)
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

    function UI.load_image(this::UIImage, path::String)
        SDL2.SDL_ClearError()

        if isempty(strip(path))
            # Placeholder / deferred art: same as load failure — in-memory 1×1 PNG, no disk path spam.
            this.surface = load_fallback_image()
            setfield!(this, :path, "fallback.png")
            if this.surface == C_NULL
                @error("Fallback image failed for empty path $(unsafe_string(SDL2.SDL_GetError()))")
                return
            end
        else
            fullPath = joinpath(BasePath, "assets", "images", path)
            this.surface = load_image_sdl(fullPath, path)
            error = unsafe_string(SDL2.SDL_GetError())

            if !isempty(error) || this.surface == C_NULL
                @error("Couldn't open image '$path'! SDL Error: ", error)
                SDL2.SDL_ClearError()

                this.surface = load_fallback_image()
                setfield!(this, :path, "fallback.png")
                if this.surface == C_NULL
                    @error("Fallback image also failed to load! $(unsafe_string(SDL2.SDL_GetError()))")
                    return
                end
            else
                if getfield(this, :path) != path
                    setfield!(this, :path, path)
                end
            end
        end
    
        # Get image size
        surface = unsafe_wrap(Array, this.surface, 10; own = false)
        if this.size == Math.Vector2(0,0)
            this.size = Math.Vector2(surface[1].w, surface[1].h)
        end
        this.originalSize = Math.Vector2(this.size.x, this.size.y)
        # Create texture
        this.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.surface)
    
        if this.texture == C_NULL
            @error("Failed to create texture from image.")
            return
        end
    
        UI.set_color(this)
    end

    function load_image_sdl(fullPath::String, path::String)
        if haskey(JulGame.IMAGE_CACHE, get_comma_separated_path(path))
            raw_data = JulGame.IMAGE_CACHE[get_comma_separated_path(path)]
            rw = SDL2.SDL_RWFromConstMem(pointer(raw_data), length(raw_data))
            if rw != C_NULL
                @debug("loading image from cache")
                @debug("comma separated path: ", get_comma_separated_path(path))
                return SDL2.IMG_Load_RW(rw, 1)
            end
        end
        @debug "Loading image from disk $(fullPath) for image, there are $(length(JulGame.IMAGE_CACHE)) images in cache"

        return SDL2.IMG_Load(fullPath)
    end

    function get_comma_separated_path(path::String)
        # Normalize the path to use forward slashes
        normalized_path = replace(path, '\\' => '/')
        
        # Split the path into components
        parts = split(normalized_path, '/')
        
        result = join(parts[1:end], ",")
    
        return result  
    end

    function UI.destroy(this::UIImage)
        if this.surface == C_NULL
            return
        end

        # Effect textures may be cached and reused elsewhere. Just clear the reference.
        if this.effectTexture != C_NULL
            this.effectTexture = C_NULL
        end
        SDL2.SDL_DestroyTexture(this.texture)
        this.surface = C_NULL
        this.texture = C_NULL

        MAIN.scene.uiElements = filter(x -> x !== this, MAIN.scene.uiElements)
    end

    function UI.set_color(this::UIImage)
        if is_texture_valid(this.texture)
            SDL2.SDL_SetTextureColorMod(this.texture, UInt8(clamp(this.color[1], 0, 255)), UInt8(clamp(this.color[2], 0, 255)), UInt8(clamp(this.color[3], 0, 255)))
            SDL2.SDL_SetTextureAlphaMod(this.texture, UInt8(clamp(this.color[4], 0, 255)))
        else
            this.texture = C_NULL
        end
        if is_texture_valid(this.effectTexture)
            SDL2.SDL_SetTextureColorMod(this.effectTexture, UInt8(clamp(this.color[1], 0, 255)), UInt8(clamp(this.color[2], 0, 255)), UInt8(clamp(this.color[3], 0, 255)))
            SDL2.SDL_SetTextureAlphaMod(this.effectTexture, UInt8(clamp(this.color[4], 0, 255)))
        else
            this.effectTexture = C_NULL
        end
    end

    function is_texture_valid(texture::Union{Ptr{SDL2.SDL_Texture}, Ptr{Nothing}})
        if texture == C_NULL || texture isa Ptr{Nothing}
            return false
        end

        #@debug "Texture: $(texture)"
        w = Ref{Cint}(0); h = Ref{Cint}(0)
        fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
        result = SDL2.SDL_QueryTexture(texture, fmt, access, w, h)
        if result != 0
            @debug "Texture is invalid: $(unsafe_string(SDL2.SDL_GetError()))"
        end

        return result == 0  # SDL_SUCCESS
    end

    function UI.duplicate(this::UIImage)
        newImage = UIImage(
            this.path; 
            id=JulGame.generate_uuid(), 
            name=this.name, 
            anchor=this.anchor.current_state, 
            anchorOffset=this.anchorOffset, 
            layer=this.layer, 
            position=this.position, 
            isActive=this.isActive, 
            persistentBetweenScenes=this.persistentBetweenScenes, 
            color=this.color, size=this.size, 
            parent=this.parent, 
            rotation=this.rotation, 
            clickEvents=this.clickEvents, 
            hoverEnterEvents=this.hoverEnterEvents, 
            hoverExitEvents=this.hoverExitEvents
        )

        UI.initialize(newImage)
        push!(MAIN.scene.uiElements, newImage)
        return newImage
    end

    function UI.add_click_event(this::UIImage, event)
        push!(this.clickEvents, event)
    end

    function Base.setproperty!(this::UIImage, s::Symbol, x)
        @debug("setting image property $(s) to: $(x)")
        try
            if hasfield(UI.UIElementInstance, s)
                #@debug "setting UIElement property $(s) to: $(x)"
                invoke(Base.setproperty!, Tuple{UI.UIElement, Symbol, Any}, this, s, x)
                return
            else
                #@debug "setting UIImage property $(s) to: $(x)"
            end
            if s == :path
                @debug("setting path to: $(x)")
                xstr = String(x)
                eff_nonempty = isdefined(this, :effects) && !isempty(getfield(this, :effects))
                if !isdefined(this, :path) || (getfield(this, :path) != xstr && !isempty(strip(xstr)))
                    if eff_nonempty && isdefined(this, :effectTexture) && getfield(this, :effectTexture) != C_NULL
                        k = isdefined(this, :effectCacheKey) ? getfield(this, :effectCacheKey) : ""
                        et = getfield(this, :effectTexture)
                        if !isempty(k) && haskey(EFFECT_CACHE, k) && EFFECT_CACHE[k] == et
                            delete!(EFFECT_CACHE, k)
                        end
                        SDL2.SDL_DestroyTexture(et)
                        this.effectTexture = C_NULL
                    end
                    setfield!(this, s, xstr)
                    UI.load_image(this, xstr)
                    # Never leave effectCacheKey as "" — update_effects would cache under "" and reuse the wrong texture on the next path change.
                    if eff_nonempty
                        this.effectCacheKey = generate_effect_cache_key(this)
                        this.needsEffectUpdate = true
                    end
                elseif isdefined(this, :path) && getfield(this, :path) != xstr && isempty(strip(xstr))
                    setfield!(this, s, xstr)
                    UI.load_image(this, xstr)
                    if eff_nonempty
                        this.effectCacheKey = generate_effect_cache_key(this)
                        this.needsEffectUpdate = true
                    end
                end
                return
            end
            setfield!(this, s, x)
        catch e
            @error "Error setting image property $(s) to: $(x)"
            @error "Error: $e"
        end
    end
    
    # Helpers to serialize effects and generate cache keys (mirrors TextBox)
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

    function generate_effect_cache_key(this::UIImage)::String
        # Cache key must be unique per instance to prevent texture sharing issues
        # When textures are shared and one instance destroys it, other instances
        # end up with invalid texture pointers
        # Include instance ID to ensure each sprite has its own effect texture
        # Omit color: tint via SDL_SetTextureColorMod in render (re-baking on every alpha fade was very expensive).
        content = string(
            this.id, "|",  # Instance ID - prevents sharing across different sprites
            this.path, "|",
            this.size.x, "x", this.size.y, "|",
            serialize_effects(this.effects)
        )
        return string(hash(content))
    end

    # Local effects cache for UIImage
    const EFFECT_CACHE = Dict{String, Ptr{SDL2.SDL_Texture}}()
    const MAX_CACHE_SIZE = 100

    function cache_effect_texture(key::String, texture::Ptr{SDL2.SDL_Texture})
        isempty(key) && return
        EFFECT_CACHE[key] = texture
        @debug("Cached UIImage effect texture for key: $key")
    end

    function clear_effects_cache()
        for (key, texture) in EFFECT_CACHE
            if texture != C_NULL
                SDL2.SDL_DestroyTexture(texture)
            end
        end
        empty!(EFFECT_CACHE)
    end

    function get_effect_cache_snapshot()
        snapshot = NamedTuple[]
        for (key, texture) in EFFECT_CACHE
            width = 0
            height = 0
            if texture != C_NULL
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

    #  effects API
    function UI.apply_effects!(this::UIImage, effects::Vector)
        this.effects = Any[effect for effect in effects]
        # compute cache key and flag update only when changed
        newKey = generate_effect_cache_key(this)
        if this.effectCacheKey != newKey
            this.effectCacheKey = newKey
            this.needsEffectUpdate = true
        else
            @debug "UIImage.apply_effects!: cache key unchanged; skipping recompute" name=this.name
        end
        return this
    end
    
    function apply_style!(this::UIImage, style)
        return apply_effects!(this, style.effects)
    end
    
    function update_effects(this::UIImage)
        if isempty(this.effects)
            return
        end
        # Use cached texture if available (never use "" — that collides across path changes)
        if !isempty(this.effectCacheKey) && haskey(EFFECT_CACHE, this.effectCacheKey)
            @debug("UIImage using cached effect texture", name=this.name, key=this.effectCacheKey)
            cached_texture = EFFECT_CACHE[this.effectCacheKey]
            
            # Since cache keys include instance ID, cached texture is ours
            # Just use it directly (it's already assigned to this instance)
            this.effectTexture = cached_texture
            if this.effectTexture != C_NULL
                w = Ref{Cint}(0); h = Ref{Cint}(0)
                fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
                SDL2.SDL_QueryTexture(this.effectTexture, fmt, access, w, h)
                this.effectSize = Math.Vector2(w[], h[])
            end
            this.needsEffectUpdate = false
            return
        end

        if this.texture == C_NULL || JulGame.Renderer == C_NULL
            return
        end
        
        # Scale surface to match desired size before applying effects
        if this.surface != C_NULL && this.size != Math.Vector2(0, 0)
            surf_arr = unsafe_wrap(Array, this.surface, 10; own=false)
            current_w = Int(surf_arr[1].w)
            current_h = Int(surf_arr[1].h)
            desired_w = Int(this.size.x)
            desired_h = Int(this.size.y)
            
            if current_w != desired_w || current_h != desired_h
                @debug("Scaling surface from $(current_w)x$(current_h) to $(desired_w)x$(desired_h)")
                scaled = SDL2.SDL_CreateRGBSurfaceWithFormat(0, desired_w, desired_h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
                if scaled != C_NULL
                    SDL2.SDL_BlitScaled(this.surface, C_NULL, scaled, C_NULL)
                    SDL2.SDL_FreeSurface(this.surface)
                    this.surface = scaled
                end
            end
        end
        
        # Destroy old effect texture before creating new one
        # (cache keys include instance ID, so this texture is exclusively ours)
        if this.effectTexture != C_NULL
            SDL2.SDL_DestroyTexture(this.effectTexture)
            this.effectTexture = C_NULL
        end
        
        # Create target for effects and apply
        target = EffectsModule.ImageTarget(this)
        try
            result = EffectRendererModule.apply_effects!(target, this.effects)
            if result isa EffectsModule.ImageTarget
                # effectTexture should be set by renderer
                if this.effectTexture != C_NULL
                    w = Ref{Cint}(0); h = Ref{Cint}(0)
                    fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
                    SDL2.SDL_QueryTexture(this.effectTexture, fmt, access, w, h)
                    this.effectSize = Math.Vector2(w[], h[])
                    
                    # Cache it (cache key includes instance ID, so no sharing issues)
                    cache_effect_texture(this.effectCacheKey, this.effectTexture)
                end
                this.needsEffectUpdate = false
            end
        catch e
            @error "Failed to apply effects to UIImage" exception=(e, catch_backtrace())
            this.needsEffectUpdate = false
        end
    end
end