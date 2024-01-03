module TextBoxModule
    using ..UI.JulGame
    using ..UI.JulGame.Math

    export TextBox      
    mutable struct TextBox
        alpha
        basePath::String
        font
        fontPath::String
        fontSize::Int32
        id::Int32
        isCenteredX::Bool
        isCenteredY::Bool
        isInitialized::Bool
        isDefaultFont::Bool
        isTextUpdated::Bool
        isWorldEntity::Bool
        name::String
        position::Vector2
        renderText
        size::Vector2
        text::String
        textTexture

        function TextBox(name::String, fontPath::String, fontSize::Number, position::Math.Vector2, text::String, isCenteredX::Bool = false, isCenteredY::Bool = false, isDefaultFont::Bool = false, isEditor::Bool = false; isWorldEntity::Bool=false) # TODO: replace bool with enum { left, center, right, etc }
            this = new()

            this.alpha = 255
            this.basePath = isDefaultFont ? ( isEditor ? joinpath(pwd(), "..", "Fonts") : joinpath(pwd(), "..", "assets", "fonts")) : JulGame.BasePath
            this.fontPath = (isEditor && isDefaultFont) ? joinpath("FiraCode", "ttf", "FiraCode-Medium.ttf") : fontPath
            this.fontSize = fontSize
            this.id = 0
            this.isCenteredX = isCenteredX
            this.isCenteredY = isCenteredY
            this.isDefaultFont = isDefaultFont
            this.isTextUpdated = false
            this.name = name
            this.position = position
            this.text = text
            this.isWorldEntity = isWorldEntity
            this.textTexture = C_NULL
            this.isInitialized = false

            return this
        end
    end

    function Base.getproperty(this::TextBox, s::Symbol)
        if s == :render
            function(DEBUG)
                if !this.isInitialized
                    Initialize(this)
                end

                if this.textTexture == C_NULL
                    return
                end

                if DEBUG
                    SDL2.SDL_RenderDrawLines(JulGame.Renderer, [
                        SDL2.SDL_Point(this.position.x, this.position.y), 
                        SDL2.SDL_Point(this.position.x + this.size.x, this.position.y),
                        SDL2.SDL_Point(this.position.x + this.size.x, this.position.y + this.size.y), 
                        SDL2.SDL_Point(this.position.x, this.position.y + this.size.y), 
                        SDL2.SDL_Point(this.position.x, this.position.y)], 5)
                end

                if this.isTextUpdated
                    this.updateText(this.text)
                    this.isTextUpdated = false
                end

                cameraDiff = this.isWorldEntity ? 
                Math.Vector2(MAIN.scene.camera.position.x * SCALE_UNITS, MAIN.scene.camera.position.y * SCALE_UNITS) : 
                Math.Vector2(0,0)

                @assert SDL2.SDL_RenderCopy(JulGame.Renderer, this.textTexture, C_NULL, Ref(SDL2.SDL_Rect(round(this.position.x - cameraDiff.x), round(this.position.y - cameraDiff.y), this.size.x, this.size.y))) == 0 "error rendering textbox text: $(unsafe_string(SDL2.SDL_GetError()))"
            end
        elseif s == :initialize
            function()
                Initialize(this)
            end
        elseif s == :setPosition
            function(position::Math.Vector2)
            end
        elseif s == :setParent
            function(parent)
                this.parent = parent
            end
        elseif s == :updateText
            function(newText)
                this.text = newText
                SDL2.SDL_FreeSurface(this.renderText)
                SDL2.SDL_DestroyTexture(this.textTexture)
                this.renderText = SDL2.TTF_RenderUTF8_Blended(this.font, this.text, SDL2.SDL_Color(255,255,255,this.alpha))
                surface = unsafe_wrap(Array, this.renderText, 10; own = false)

                this.size = Math.Vector2(surface[1].w, surface[1].h)
                this.textTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, this.renderText)
                
                if !this.isWorldEntity
                    this.centerText()
                end
            end
        elseif s == :setVector2Value
            function(field, x, y)
                setfield!(this, field, Math.Vector2(x,y))
                println("set $(field) to $(getfield(this, field))")
            end
        elseif s == :setColor
            function (r,g,b)
                SDL2.SDL_SetTextureColorMod(this.textTexture, r%256, g%256, b%256);
            end
        elseif s == :centerText
            function()
                if this.isCenteredX
                    this.position = Math.Vector2(max(MAIN.scene.camera.dimensions.x/2 - this.size.x/2, 0), this.position.y)
                end
                if this.isCenteredY
                    this.position = Math.Vector2(this.position.x, max(MAIN.scene.camera.dimensions.y/2 - this.size.y/2, 0))
                end
            end
        elseif s == :destroy
            function()
                if this.textTexture == C_NULL
                    return
                end

                SDL2.SDL_DestroyTexture(this.textTexture)
                this.textTexture = C_NULL
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

    function Initialize(this)
        path = this.isDefaultFont ? joinpath(this.basePath, this.fontPath) : joinpath(this.basePath, "assets", "fonts", this.fontPath)

        this.font = CallSDLFunction(SDL2.TTF_OpenFont, path, this.fontSize)
        if this.font == C_NULL
            return
        end

        this.renderText = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, this.font, this.text, SDL2.SDL_Color(255,255,255,this.alpha))
        
        surface = unsafe_wrap(Array, this.renderText, 10; own = false)
        this.size = Math.Vector2(surface[1].w, surface[1].h)
        
        this.textTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer, this.renderText)

        if !this.isWorldEntity
            this.centerText()
        end

        this.isInitialized = true
    end

end