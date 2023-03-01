include("../Math/Vector2.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct ScreenButton
    clickEvents
    currentTexture
    buttonDownSprite
    buttonDownTexture
    buttonUpSprite
    buttonUpTexture
    dimensions
    mouseOverSprite
    position
    renderer

    function ScreenButton(dimensions::Vector2, position::Vector2, buttonUpSprite, buttonDownSprite)
        this = new()
        
        this.buttonDownSprite = buttonDownSprite == C_NULL ? IMG_Load(joinpath(@__DIR__, "..", "..", "assets", "images", "ButtonDown.png")) : IMG_Load(buttonDownSprite)
        this.buttonUpSprite = buttonUpSprite == C_NULL ? IMG_Load(joinpath(@__DIR__, "..", "..", "assets", "images", "ButtonUp.png")) : IMG_Load(buttonUpSprite)
        this.clickEvents = []
        this.dimensions = dimensions
        this.mouseOverSprite = false
        this.position = position

        return this
    end
end

function Base.getproperty(this::ScreenButton, s::Symbol)
    if s == :render
        function()
            if !this.mouseOverSprite && this.currentTexture == this.buttonDownTexture
                this.currentTexture = this.buttonUpTexture
            end    
            @assert SDL_RenderCopyEx(
                this.renderer, 
                this.currentTexture, 
                C_NULL, 
                Ref(SDL_Rect(this.position.x, this.position.y, this.dimensions.x,this.dimensions.y)), 
                0.0, 
                C_NULL, 
                SDL_FLIP_NONE) == 0 "error rendering image: $(unsafe_string(SDL_GetError()))"
        end
    elseif s == :injectRenderer
        function(renderer)
            this.renderer = renderer
            this.buttonDownTexture = SDL_CreateTextureFromSurface(this.renderer, this.buttonDownSprite)
            this.buttonUpTexture = SDL_CreateTextureFromSurface(this.renderer, this.buttonUpSprite)
            this.currentTexture = this.buttonUpTexture
        end
    elseif s == :setPosition
        function(position::Vector2)
        end
    elseif s == :addClickEvent
        function(event)
            push!(this.clickEvents, event)
        end
    elseif s == :handleEvent
        function(evt, x, y)
            if evt.type == evt.type == SDL_MOUSEBUTTONDOWN
                this.currentTexture = this.buttonDownTexture
            elseif evt.type == SDL_MOUSEBUTTONUP
                this.currentTexture = this.buttonUpTexture
                for eventToCall in this.clickEvents
                    eventToCall()
                end
            elseif evt.type == SDL_MOUSEMOTION
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