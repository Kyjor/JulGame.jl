using SimpleDirectMediaLayer.LibSDL2

mutable struct ScreenButton
    currentSprite
    buttonDownSprite
    buttonUpSprite
    dimensions
    image
    mouseOverSprite
    position
    renderer
    texture

    function ScreenButton(dimensions::Vector2f, position::Vector2f, image)
        this = new()
        
        this.dimensions = dimensions
        this.position = position
        if image != C_NULL
            this.image = IMG_Load(image)
        else
            this.image = IMG_Load(joinpath(@__DIR__, "..", "..", "assets", "images", "buttons.png"))
        end

        return this
    end
end

function Base.getproperty(this::ScreenButton, s::Symbol)
    if s == :render
        function()
            println(this.dimensions)
            @assert SDL_RenderCopyEx(
                this.renderer, 
                this.texture, 
                Ref(SDL_Rect(this.position.x,this.position.y,256,64)), 
                Ref(SDL_Rect(convert(Int32,round((this.position.x))), 
                convert(Int32,round((this.position.y))),
                convert(Int32,round(1 * this.dimensions.x)), 
                convert(Int32,round(1 * this.dimensions.y)))), 
                0.0, 
                C_NULL, 
                SDL_FLIP_NONE) == 0 "error rendering image: $(unsafe_string(SDL_GetError()))"
        end
    elseif s == :injectRenderer
        function(renderer)
            this.renderer = renderer
            this.texture = SDL_CreateTextureFromSurface(this.renderer, this.image)
        end
    elseif s == :setPosition
        function(position::Vector2f)
        end
    elseif s == :handleEvent
        function(evt, x, y)
            if evt.type == SDL_MOUSEMOTION || evt.type == SDL_MOUSEBUTTONDOWN || evt.type == SDL_MOUSEBUTTONUP
                #println("mouse event")
            end 
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end