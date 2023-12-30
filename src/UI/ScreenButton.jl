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
        isInitialized::Bool
        mouseOverSprite
        position
        text
        textTexture

        function ScreenButton(basePath::String, buttonUpSpritePath::String, buttonDownSpritePath::String, dimensions::Math.Vector2, position::Math.Vector2, text::String)
            this = new()
            
            this.buttonDownSprite = SDL2.IMG_Load(joinpath(basePath, "assets", "images", buttonDownSpritePath))
            this.buttonUpSprite = SDL2.IMG_Load(joinpath(basePath, "assets", "images", buttonUpSpritePath))
            #this.basePath = isDefaultFont ? ( isEditor ? joinpath(pwd(), "..", "..", "..", "src", "Fonts") : joinpath(pwd(), "..", "assets", "fonts")) : basePath
            this.clickEvents = []
            this.currentTexture = C_NULL
            this.dimensions = dimensions
            this.mouseOverSprite = false
            this.position = position
            this.text = text
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

                if this.currentTexture == C_NULL
                    return
                end

                if !this.mouseOverSprite && this.currentTexture == this.buttonDownTexture
                    this.currentTexture = this.buttonUpTexture
                end    
                @assert SDL2.SDL_RenderCopyEx(
                    JulGame.Renderer, 
                    this.currentTexture, 
                    C_NULL, 
                    Ref(SDL2.SDL_Rect(this.position.x, this.position.y, this.dimensions.x,this.dimensions.y)), 
                    0.0, 
                    C_NULL, 
                    SDL2.SDL_FLIP_NONE) == 0 "error rendering image: $(unsafe_string(SDL2.SDL_GetError()))"

                #@assert SDL2.SDL_RenderCopy(JulGame.Renderer, this.textTexture, C_NULL, Ref(SDL2.SDL_Rect(this.position.x + 50, this.position.y + 10,150,50))) == 0 "error rendering button text: $(unsafe_string(SDL2.SDL_GetError()))"
            end
        elseif s == :initialize
            function()
                this.buttonDownTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, this.buttonDownSprite)
                this.buttonUpTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, this.buttonUpSprite)
                this.currentTexture = this.buttonUpTexture
                # text = SDL2.TTF_RenderText_Blended(font, this.text, SDL2.SDL_Color(255,255,255,255) )
                # this.textTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, text)
                this.isInitialized = true
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