include("../Constants.jl")
include("../Math/Vector2.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct TextBox
    fontSize
    position
    renderer
    size
    sizePercentage
    text
    textTexture

    function TextBox(position::Vector2, size::Vector2, sizePercentage::Vector2, text::String)
        this = new()
        
        this.size = size
        this.sizePercentage = sizePercentage
        this.position = position
        this.text = text

        return this
    end
end

function Base.getproperty(this::TextBox, s::Symbol)
    if s == :render
        function(DEBUG)
            if DEBUG
                SDL_RenderDrawLines(this.renderer, [
                    SDL_Point(this.position.x, this.position.y), 
                    SDL_Point(this.position.x + this.size.x, this.position.y),
                    SDL_Point(this.position.x + this.size.x, this.position.y + this.size.y), 
                    SDL_Point(this.position.x, this.position.y + this.size.y), 
                    SDL_Point(this.position.x, this.position.y)], 5)
            end
            @assert SDL_RenderCopy(this.renderer, this.textTexture, C_NULL, Ref(SDL_Rect((this.position.x), this.position.y, round(this.size.x), round(this.size.y)))) == 0 "error rendering textbox text: $(unsafe_string(SDL_GetError()))"
        end
    elseif s == :injectRenderer
        function(renderer, font)
            this.renderer = renderer
            text = TTF_RenderText_Blended_Wrapped(font, this.text, SDL_Color(255,255,255,255), 1000)
            this.textTexture = SDL_CreateTextureFromSurface(this.renderer, text)
        end
    elseif s == :setPosition
        function(position::Vector2)
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    elseif s == :updateText
        function(newText)
            
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end