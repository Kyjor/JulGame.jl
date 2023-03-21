include("../Constants.jl")
include("../Math/Vector2.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct TextBox
    font
    isCentered    
    position
    renderer
    size
    sizePercentage
    text
    textTexture

    function TextBox(position::Vector2, size::Vector2, sizePercentage::Vector2, text::String, isCentered::Bool) # TODO: replace bool with enum { left, center, right, etc }
        this = new()
        
        this.isCentered = isCentered
        this.position = position
        this.size = size
        this.sizePercentage = sizePercentage
        this.text = text

        return this
    end
end

function Base.getproperty(this::TextBox, s::Symbol)
    if s == :render
        function(DEBUG)
            if DEBUG
                println("textbox size: $(this.size.x)")
                SDL_RenderDrawLines(this.renderer, [
                    SDL_Point(this.position.x, this.position.y), 
                    SDL_Point(this.position.x + this.size.x, this.position.y),
                    SDL_Point(this.position.x + this.size.x, this.position.y + this.size.y), 
                    SDL_Point(this.position.x, this.position.y + this.size.y), 
                    SDL_Point(this.position.x, this.position.y)], 5)
            end

            @assert SDL_RenderCopy(this.renderer, this.textTexture, C_NULL, Ref(SDL_Rect((this.position.x), this.position.y, this.size.x, this.size.y))) == 0 "error rendering textbox text: $(unsafe_string(SDL_GetError()))"
        end
    elseif s == :initialize
        function(renderer, font, windowInfo)
            this.renderer = renderer
            this.font = font
            text = TTF_RenderText_Blended_Wrapped(this.font, this.text, SDL_Color(255,255,255,255), 1900)
            this.textTexture = SDL_CreateTextureFromSurface(this.renderer, text)
            w,h = Int32[1], Int32[1]
            TTF_SizeText(this.font, this.text, pointer(w), pointer(h))
            this.size = Vector2(w[1], h[1])
            println((1920 - this.size.x)/2)
            
            if this.isCentered 
                this.position = Vector2(max((1920 - this.size.x)/2, 0), this.position.y)
            end
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