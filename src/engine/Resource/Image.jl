module ImageModule
    using ..ResourceModule.JulGame
    include("InternalImages.jl")

    export Image
    mutable struct Image
        path::String
        rotation::Float64
        center::Math.Vector2f
        color::NTuple{4, Int}
        crop::Union{Ptr{Nothing}, Math.Vector4}
        isFlipped::Bool
        isFloatPrecision::Bool
        screenPosition::Union{Math.Vector2f, Nothing}
        size::Math.Vector2
        surface::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Surface}}
        texture::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Texture}}
        
        function Image(path::String, crop::Union{Ptr{Nothing}, Math.Vector4}=C_NULL, isFlipped::Bool=false, color::NTuple{4, Int} = (255,255,255,255), isCreatedInEditor::Bool=false; pixelsPerUnit::Int=0, position::Math.Vector2f = Math.Vector2f(0,0), rotation::Float64 = 0.0, center::Math.Vector2f = Math.Vector2f(0.5,0.5), anchor::Symbol = :center, offset::Math.Vector2f = Math.Vector2f(0,0))
            this = new()

            this.isFlipped = isFlipped
            @debug "attemping to load Image with path: $(path)"
            this.path = path
            this.center = center
            this.color = color
            this.crop = crop
            this.surface = C_NULL
            this.rotation = rotation
            this.texture = C_NULL
            this.isFloatPrecision = false
            this.screenPosition = nothing
            this.screenSize = nothing

            if isCreatedInEditor
                return this
            end
        
            Component.load_image(this::Image, path::String)
            if this.surface == C_NULL
                error = unsafe_string(SDL2.SDL_GetError())
                @error(string("Couldn't open image! path: $(path) SDL Error: ", error))
                Base.show_backtrace(stdout, catch_backtrace())
                return
            end
            surface = unsafe_wrap(Array, this.surface, 10; own = false)
            this.size = Math.Vector2(surface[1].w, surface[1].h)
        
            return this
        end
    end
    
    function initialize(this::Image)
        if this.surface == C_NULL
            return
        end

        this.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.surface)
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

    function load_image(this::Image, path::String)
        SDL2.SDL_ClearError()

        fullPath = joinpath(BasePath, "assets", "images", path)
        this.surface = load_image_sdl(fullPath, path)
        error = unsafe_string(SDL2.SDL_GetError())
    
        if !isempty(error) || this.surface == C_NULL
            @error("Couldn't open image '$path'! SDL Error: ", error)
            SDL2.SDL_ClearError()
    
            # Load from byte array
            this.surface = load_fallback_image()
            setfield!(this, :path, "fallback.png")
            this.pixelsPerUnit = 0
            if this.surface == C_NULL
                @error("Fallback image also failed to load! $(unsafe_string(SDL2.SDL_GetError()))")
                return
            end
        elseif this.path != path
            this.path = path
        end
    
        # Get image size
        surface = unsafe_wrap(Array, this.surface, 10; own = false)
        this.size = Math.Vector2(surface[1].w, surface[1].h)
    
        # Create texture
        this.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.surface)
    
        if this.texture == C_NULL
            @error("Failed to create texture from image.")
            return
        end
    
        Component.set_color(this)
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
        @debug "Loading image from disk $(fullPath) for Image, there are $(length(JulGame.IMAGE_CACHE)) images in cache"

        return SDL2.IMG_Load(fullPath)
    end

    function destroy(this::Image)
        if this.surface == C_NULL
            return
        end

        SDL2.SDL_DestroyTexture(this.texture)
        this.surface = C_NULL
        this.texture = C_NULL
    end

    function set_color(this::Image)
        SDL2.SDL_SetTextureColorMod(this.texture, UInt8(clamp(this.color[1], 0, 255)), UInt8(clamp(this.color[2], 0, 255)), UInt8(clamp(this.color[3], 0, 255)));
        SDL2.SDL_SetTextureAlphaMod(this.texture, UInt8(clamp(this.color[4], 0, 255)));
    end

    function is_mouse_hovering(this::Image)
       # TODO: check if the mouse is hovering over any of the Images pixels
       return false
    end

    function Base.setproperty!(this::Image, s::Symbol, x)
        @debug("setting Image property $(s) to: $(x)")
        try
            if s == :path
                @debug("setting path to: $(x)")
                if !isdefined(this, :path) || (this.path != x && !isempty(x))
                    # Reload the image, cleaning up the old one first
                    setfield!(this, s, String(x))
                    Component.load_image(this, String(x))
                end
                return
            end
            setfield!(this, s, x)
        catch e
            @error "Error setting Image property $(s) to: $(x)"
            @error "Error: $e"
            Base.show_backtrace(stderr, catch_backtrace())
        end
    end
end
