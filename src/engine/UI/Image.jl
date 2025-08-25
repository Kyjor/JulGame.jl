module ImageModule    
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI

    export Image
    mutable struct Image <: UI.UIElement
        imagePath::String
        texture
        sprite
        isInitialized::Bool

        function Image(;
            id::String=JulGame.generate_uuid(), 
            name::String="Image",
            anchor::Symbol = :none,
            anchorOffset::Math.Vector2 = Math.Vector2(0,0), 
            isWorldEntity::Bool=false, 
            layer::Int=0,
            position::Math.Vector2 = Math.Vector2(0,0), 
            imagePath::String="", 
            hoverEnterEvent::Union{Function, Nothing} = nothing,
            hoverExitEvent::Union{Function, Nothing} = nothing,
            isActive::Bool=true,
            persistentBetweenScenes::Bool=false,
            color::NTuple{4, Int}=(255, 255, 255, 255), 
            size::Math.Vector2=Math.Vector2(100,100), 
            parent::Union{UI.UIElement, Nothing}=nothing,
            rotation::Float64=0.0
        )
            this = new()
            
            this.imagePath = imagePath
            this.sprite = C_NULL
            this.texture = C_NULL

            this.anchor = JulGame.Enum{Any}(
                :center,
                :top,
                :bottom,
                :left,
                :right,
                :topLeft,
                :topRight,
                :bottomLeft,
                :bottomRight,
                :centerLeft,
                :centerRight,
                :centerTop,
                :centerBottom,
                :none
            )
            this.isInitialized = false

            this.anchor.current_state = anchor
            this.anchorOffset = anchorOffset

            this.clickEvents = Function[]
            this.hoverEnterEvents = Function[]
            this.hoverExitEvents = Function[]
            this.id = id
            this.size = size
            this.name = name
            this.position = position
            this.persistentBetweenScenes = persistentBetweenScenes
            this.isHovered = false
            this.isActive = isActive
            this.layer = layer
            this.color = color
            this.isWorldEntity = isWorldEntity
            this.parent = parent
            this.rotation = rotation

            if hoverEnterEvent !== nothing
                push!(this.hoverEnterEvents, hoverEnterEvent)
            end
            if hoverExitEvent !== nothing
                push!(this.hoverExitEvents, hoverExitEvent)
            end

            return this
        end
    end

    function UI.render(this::Image)
        if !this.isInitialized
            UI.initialize(this)
        end

        if !this.isActive
            return
        end

        if this.texture == C_NULL || this.texture === nothing
            return
        end

        if !this.isWorldEntity
            UI.align_to_anchor(this)
        end

        # Check and set color if necessary
        colorRefs = (Ref(UInt8(0)), Ref(UInt8(0)), Ref(UInt8(0)))
        alphaRef = Ref(UInt8(0))
        SDL2.SDL_GetTextureColorMod(this.texture, colorRefs...)
        SDL2.SDL_GetTextureAlphaMod(this.texture, alphaRef)
        if colorRefs[1] != this.color[1] || colorRefs[2] != this.color[2] || colorRefs[3] != this.color[3] || this.color[4] != alphaRef
            UI.set_color(this, r=this.color[1], g=this.color[2], b=this.color[3], a=this.color[4])
        end

        @assert SDL2.SDL_RenderCopyExF(
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
            this.texture, 
            C_NULL, 
            Ref(SDL2.SDL_FRect(this.position.x, this.position.y, this.size.x, this.size.y)), 
            this.rotation, 
            C_NULL, 
            SDL2.SDL_FLIP_NONE) == 0 "error rendering image: $(unsafe_string(SDL2.SDL_GetError()))"
    end

    function UI.initialize(this::Image)
        if this.imagePath != "" && this.imagePath != "Default"
            this.sprite = load_image_sdl(joinpath(JulGame.BasePath, "assets", "images"), this.imagePath)
            if this.sprite != C_NULL
                this.texture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.sprite)
            end
        end

        if !this.isWorldEntity
            UI.align_to_anchor(this)
        end

        this.isInitialized = true
    end

    function UI.set_color(this::Image; r::Int=255, g::Int=255, b::Int=255, a::Int=255)
        this.color = (r%256, g%256, b%256, a%256)
        if this.texture != C_NULL
            SDL2.SDL_SetTextureColorMod(this.texture, UInt8(clamp(this.color[1], 0, 255)), UInt8(clamp(this.color[2], 0, 255)), UInt8(clamp(this.color[3], 0, 255)));
            SDL2.SDL_SetTextureAlphaMod(this.texture, UInt8(clamp(this.color[4], 0, 255)));
        end
    end

    function load_image_sdl(fullPath::String, imagePath::String)
        if haskey(JulGame.IMAGE_CACHE, get_comma_separated_path(imagePath))
            raw_data = JulGame.IMAGE_CACHE[get_comma_separated_path(imagePath)]
            rw = SDL2.SDL_RWFromConstMem(pointer(raw_data), length(raw_data))
            if rw != C_NULL
                @debug("loading image at $(imagePath) from cache")
                @debug("comma separated path: ", get_comma_separated_path(imagePath))
                return SDL2.IMG_Load_RW(rw, 1)
            end
        end
        @debug "Loading image from disk, there are $(length(JulGame.IMAGE_CACHE)) images in cache"

        return CallSDLFunction(SDL2.IMG_Load, joinpath(fullPath, imagePath))
    end

    function get_comma_separated_path(path::String)
        # Normalize the path to use forward slashes
        normalized_path = replace(path, '\\' => '/')
        
        # Split the path into components
        parts = split(normalized_path, '/')
        
        result = join(parts[1:end], ",")
    
        return result  
    end

    function UI.destroy(this::Image)
        if this.texture != C_NULL
            SDL2.SDL_DestroyTexture(this.texture)
        end
        this.texture = C_NULL
        this.sprite = C_NULL
    end

    function update_image_path(this::Image, new_path::String)
        if this.imagePath == new_path
            return # No change needed
        end
        
        this.imagePath = new_path
        
        # Clean up previous texture if it exists
        if this.texture != C_NULL
            SDL2.SDL_DestroyTexture(this.texture)
            this.texture = C_NULL
        end
        
        # Skip loading if path is empty
        if this.imagePath == ""
            return
        end
        
        # Load new image
        this.sprite = load_image_sdl(joinpath(JulGame.BasePath, "assets", "images"), this.imagePath)
        if this.sprite != C_NULL
            this.texture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.sprite)
        end
    end
end