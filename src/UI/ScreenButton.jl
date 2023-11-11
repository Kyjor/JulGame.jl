module ScreenButtonModule    
    using ..UI.JulGame
    using ..UI.JulGame.Math

    export ScreenButton
    mutable struct ScreenButton
        clickEvents::Array{Any}
        currentTexture
        buttonDownSprite
        buttonDownTexture
        buttonUpSprite
        buttonUpTexture
        dimensions
        mouseOverSprite
        position
        renderer
        text
        textTexture

        function ScreenButton(dimensions::Math.Vector2, position::Math.Vector2, buttonUpSprite, buttonDownSprite, text)
            this = new()
            
            this.buttonDownSprite = SDL2.IMG_Load(buttonDownSprite)
            this.buttonUpSprite = SDL2.IMG_Load(buttonUpSprite)
            this.clickEvents = []
            this.dimensions = dimensions
            this.mouseOverSprite = false
            this.position = position
            this.text = text

            return this
        end
    end

    function Base.getproperty(this::ScreenButton, s::Symbol)
        if s == :render
            function()
                if !this.mouseOverSprite && this.currentTexture == this.buttonDownTexture
                    this.currentTexture = this.buttonUpTexture
                end    
                @assert SDL2.SDL_RenderCopyEx(
                    this.renderer, 
                    this.currentTexture, 
                    C_NULL, 
                    Ref(SDL2.SDL_Rect(this.position.x, this.position.y, this.dimensions.x,this.dimensions.y)), 
                    0.0, 
                    C_NULL, 
                    SDL_FLIP_NONE) == 0 "error rendering image: $(unsafe_string(SDL_GetError()))"

                @assert SDL2.SDL_RenderCopy(this.renderer, this.textTexture, C_NULL, Ref(SDL2.SDL_Rect(this.position.x + 50, this.position.y + 10,150,50))) == 0 "error rendering button text: $(unsafe_string(SDL2.SDL_GetError()))"
            end
        elseif s == :injectRenderer
            function(renderer, font)
                this.renderer = renderer
                this.buttonDownTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer, this.buttonDownSprite)
                this.buttonUpTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer, this.buttonUpSprite)
                this.currentTexture = this.buttonUpTexture
                text = SDL2.TTF_RenderText_Blended(font, this.text, SDL2.SDL_Color(255,255,255,255) )
                this.textTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer, text)

            end
        elseif s == :setPosition
            function(position::Math.Vector2)
            end
        elseif s == :addClickEvent
            function(event)
                push!(this.clickEvents, event)
            end
        elseif s == :handleEvent
            function(evt, x, y)
                if evt.type == evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                    this.currentTexture = this.buttonDownTexture
                elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
                    this.currentTexture = this.buttonUpTexture
                    for eventToCall in this.clickEvents
                        eventToCall()
                    end
                elseif evt.type == SDL2.SDL_MOUSEMOTION
                    #println("mouse move")
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
end