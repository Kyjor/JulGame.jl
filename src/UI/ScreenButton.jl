module ScreenButtonModule    
    using ..UI.JulGame
    using ..UI.JulGame.Math

    export ScreenButton
    mutable struct ScreenButton
        clickEvents::Vector{Function}
        currentTexture
        buttonDownSprite
        buttonDownTexture
        #TODO: add buttonHoverSprite/Color Mod 
        buttonUpSprite
        buttonUpTexture
        dimensions
        fontPath::Union{String, Ptr{Nothing}}
        isInitialized::Bool
        mouseOverSprite
        position::Math.Vector2
        text::String
        textOffset::Math.Vector2
        textSize::Math.Vector2
        textTexture

        function ScreenButton(buttonUpSpritePath::String, buttonDownSpritePath::String, dimensions::Math.Vector2, position::Math.Vector2, fontPath::Union{String, Ptr{Nothing}} = C_NULL, text::String="", textOffset::Math.Vector2=Math.Vector2(0,0); isCreatedInEditor::Bool=false)
            this = new()
            
            this.buttonDownSprite = CallSDLFunction(SDL2.IMG_Load, joinpath(JulGame.BasePath, "assets", "images", buttonDownSpritePath))
            this.buttonUpSprite = CallSDLFunction(SDL2.IMG_Load, joinpath(JulGame.BasePath, "assets", "images", buttonUpSpritePath))
            this.clickEvents = []
            this.currentTexture = C_NULL
            this.dimensions = dimensions
            this.fontPath = fontPath
            this.mouseOverSprite = false
            this.position = position
            this.text = text
            this.textOffset = textOffset
            this.textTexture = C_NULL
            this.isInitialized = false

            return this
        end
    end

    function Base.getproperty(this::ScreenButton, s::Symbol)
        if s == :render
            function()
                if !this.isInitialized
                    this.initialize()
                end

                if this.currentTexture == C_NULL || this.textTexture == C_NULL
                    return
                end

                if !this.mouseOverSprite && this.currentTexture == this.buttonDownTexture
                    this.currentTexture = this.buttonUpTexture
                end    
                @assert SDL2.SDL_RenderCopyExF(
                    JulGame.Renderer, 
                    this.currentTexture, 
                    C_NULL, 
                    Ref(SDL2.SDL_FRect(this.position.x, this.position.y, this.dimensions.x,this.dimensions.y)), 
                    0.0, 
                    C_NULL, 
                    SDL2.SDL_FLIP_NONE) == 0 "error rendering image: $(unsafe_string(SDL2.SDL_GetError()))"

                @assert SDL2.SDL_RenderCopyF(JulGame.Renderer, this.textTexture, C_NULL, Ref(SDL2.SDL_FRect(this.position.x + this.textOffset.x, this.position.y + this.textOffset.y,this.textSize.x,this.textSize.y))) == 0 "error rendering button text: $(unsafe_string(SDL2.SDL_GetError()))"
            end
        elseif s == :initialize
            function()
                this.buttonDownTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer, this.buttonDownSprite)
                this.buttonUpTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer, this.buttonUpSprite)
                this.currentTexture = this.buttonUpTexture

                if this.fontPath == C_NULL
                    this.isInitialized = true
                    return
                end

                font = CallSDLFunction(SDL2.TTF_OpenFont, joinpath(JulGame.BasePath, "assets", "fonts", this.fontPath), 64)
                text = font != C_NULL ? CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, font, this.text, SDL2.SDL_Color(255,255,255,255)) : C_NULL
                surface = unsafe_wrap(Array, text, 10; own = false)
                this.textSize = Math.Vector2(surface[1].w, surface[1].h)
                this.textTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer, text)
                this.isInitialized = true
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
        elseif s == :destroy
            function()
                if !this.buttonDownTexture == C_NULL
                    SDL2.SDL_DestroyTexture(this.buttonDownTexture)
                end
                if !this.buttonUpTexture == C_NULL
                    SDL2.SDL_DestroyTexture(this.buttonUpTexture)
                end
                this.buttonDownTexture = C_NULL
                this.buttonUpTexture = C_NULL
                this.currentTexture = C_NULL
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
                Base.show_backtrace(stdout, catch_backtrace())
            end
        end
    end
end