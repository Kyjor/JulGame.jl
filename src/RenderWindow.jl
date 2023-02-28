__precompile__()
include("Math/Vector2f.jl")
include("Entity.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct RenderWindow
    renderer 
    window
    
    height
    width

    font
    color
    surface
    texture
    surface0

    function RenderWindow(title, width, height)
        this = new()
        this.window = SDL_CreateWindow(title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height, SDL_WINDOW_SHOWN)
        @assert this.window != nothing "error initializing SDL Window: $(unsafe_string(SDL_GetError()))"
        SDL_SetWindowResizable(this.window, SDL_TRUE)
        
        this.renderer = SDL_CreateRenderer(this.window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)
        this.font = TTF_OpenFont("FiraCode-Bold.ttf", 24)
        this.width = width
        this.height = height
        this.color = SDL_Color(0, 255, 0, 255)
        this.surface = TTF_RenderText_Solid(this.font, "message", this.color)
        this.texture = SDL_CreateTextureFromSurface(this.renderer, this.surface)
        this.surface0 = Base.unsafe_load(this.surface)
        
        println("RenderWindow created successfully")
        return this
    end
end

function Base.getproperty(this::RenderWindow, s::Symbol)
    if s == :loadTexture
        function(filePath)
            println("Loading texture from $filePath")
            texture = IMG_LoadTexture(this.renderer, filePath)
            #TODO: check for texture load error
            @assert texture != nothing "error initializing SDL: $(unsafe_string(SDL_GetError()))"

            return texture
        end
    elseif s == :cleanUp
        function()
            SDL_DestroyRenderer(this.renderer)
        end
    elseif s == :clear
        function()
            SDL_RenderClear(this.renderer)
        end
    elseif s == :display
        function()
            SDL_RenderPresent(this.renderer)
        end
    elseif s == :getRefreshRate
        function()
            displayIndex = SDL_GetWindowDisplayIndex(this.window)
            mode = SDL_DisplayMode(0,this.width, this.height, 60, 0)
            SDL_GetDisplayMode(displayIndex, 0, Ref(mode))
            return mode.refresh_rate
        end 
    elseif s == :getRenderer
        function()
            return this.renderer
        end
    elseif s == :drawText
        function(message::String, x::Integer, y::Integer, r::Integer, g::Integer, b::Integer, size::Integer)
            color = SDL_Color(r, g, b, 255)
            surface = TTF_RenderText_Solid(this.font, message, color)
            texture = SDL_CreateTextureFromSurface(this.renderer, surface)
            surface0 = Base.unsafe_load(surface)

            SDL_FreeSurface(surface)
            SDL_RenderCopy(this.renderer, texture, C_NULL, Ref(SDL_Rect(x, y, surface0.w, surface0.h)))
            SDL_DestroyTexture(texture)
            
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end