module ImageModule    
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI

    export Image
    mutable struct Image
        alpha
        imagePath::String
        imageSprite
        imageTexture
        isInitialized::Bool
        name::String
        persistentBetweenScenes::Bool
        position::Math.Vector2
        size::Math.Vector2

        function Image(name::String, imagePath::String, size::Math.Vector2, position::Math.Vector2)
            this = new()
            
            this.alpha = 255
            this.imagePath = imagePath
            this.imageSprite = C_NULL
            this.imageTexture = C_NULL
            this.isInitialized = false
            this.name = name
            this.persistentBetweenScenes = false
            this.position = position
            this.size = size

            if imagePath != ""
                this.imageSprite = CallSDLFunction(SDL2.IMG_Load, joinpath(JulGame.BasePath, "assets", "images", imagePath))
            end

            return this
        end
    end

    function UI.render(this::Image, debug)
        if !this.isInitialized
            UI.initialize(this)
        end

        if this.imageTexture == C_NULL
            return
        end

        if debug
            SDL2.SDL_RenderDrawLines(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, [
                SDL2.SDL_Point(this.position.x, this.position.y), 
                SDL2.SDL_Point(this.position.x + this.size.x, this.position.y),
                SDL2.SDL_Point(this.position.x + this.size.x, this.position.y + this.size.y), 
                SDL2.SDL_Point(this.position.x, this.position.y + this.size.y), 
                SDL2.SDL_Point(this.position.x, this.position.y)], 5)
        end

        @assert SDL2.SDL_RenderCopyExF(
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
            this.imageTexture, 
            C_NULL, 
            Ref(SDL2.SDL_FRect(this.position.x, this.position.y, this.size.x, this.size.y)), 
            0.0, 
            C_NULL, 
            SDL2.SDL_FLIP_NONE) == 0 "error rendering image: $(unsafe_string(SDL2.SDL_GetError()))"
    end

    function UI.initialize(this::Image)
        if this.imageSprite != C_NULL
            this.imageTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.imageSprite)
        end
        this.isInitialized = true
    end

    function UI.load_image_sprite_editor(this::Image, path::String)
        if this.imageSprite != C_NULL
            SDL2.SDL_FreeSurface(this.imageSprite)
        end
        if this.imageTexture != C_NULL
            SDL2.SDL_DestroyTexture(this.imageTexture)
        end
        
        this.imageSprite = CallSDLFunction(SDL2.IMG_Load, joinpath(JulGame.BasePath, "assets", "images", path))
        this.imageTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.imageSprite)
        this.imagePath = path
    end

    function UI.set_position(this::Image, position::Math.Vector2)
        this.position = position
    end

    function UI.destroy(this::Image)
        if this.imageTexture != C_NULL
            SDL2.SDL_DestroyTexture(this.imageTexture)
            this.imageTexture = C_NULL
        end
        if this.imageSprite != C_NULL
            SDL2.SDL_FreeSurface(this.imageSprite)
            this.imageSprite = C_NULL
        end
    end

end