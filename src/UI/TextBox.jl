module TextBoxModule
    using ..UI.JulGame
    using ..UI.JulGame.Math

    export TextBox      
    mutable struct TextBox
        alpha
        autoSizeText
        basePath
        font
        fontPath
        fontSize
        id
        isCentered    
        isDefaultFont
        isTextUpdated
        name
        position
        renderer
        renderText
        size
        sizePercentage
        text
        textTexture
        zoom

        function TextBox(name::String, basePath::String, fontPath::String, fontSize::Number, position::Math.Vector2, size::Math.Vector2, sizePercentage::Math.Vector2, text::String, isCentered::Bool, isDefaultFont::Bool = false, isEditor::Bool = false) # TODO: replace bool with enum { left, center, right, etc }
            this = new()

            this.alpha = 255
            this.basePath = isDefaultFont ? ( isEditor ? joinpath(pwd(), "..", "..", "..", "src", "Fonts") : joinpath(pwd(), "..", "assets", "fonts")) : basePath
            this.fontPath = fontPath
            this.fontSize = fontSize
            this.autoSizeText = false
            this.id = 0
            this.isCentered = isCentered
            this.isDefaultFont = isDefaultFont
            this.isTextUpdated = false
            this.name = name
            this.position = position
            this.size = size
            this.sizePercentage = sizePercentage
            this.text = text
            this.zoom = 1.0
            this.renderer = C_NULL
            this.initialize()

            return this
        end
    end

    function Base.getproperty(this::TextBox, s::Symbol)
        if s == :render
            function(DEBUG)
                if DEBUG
                    SDL2.SDL_RenderDrawLines(this.renderer, [
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
                # @assert 
                SDL2.SDL_RenderCopy(
                    this.renderer, this.textTexture, C_NULL, Ref(SDL2.SDL_Rect((this.position.x), this.position.y, this.size.x, this.size.y))
                ) 
                # == 0 "error rendering textbox text: $(unsafe_string(SDL2.SDL_GetError()))"
            end
        elseif s == :initialize
            function()
                this.zoom = MAIN.zoom
                this.renderer = MAIN.renderer
                path = this.isDefaultFont ? joinpath(this.basePath, this.fontPath) : joinpath(this.basePath, "assets", "fonts", this.fontPath)
                font = SDL2.TTF_OpenFont(path, this.fontSize)
                println(unsafe_string(SDL2.SDL_GetError()))
                this.font = font
                this.renderText = SDL2.TTF_RenderText_Blended(this.font, this.text, SDL2.SDL_Color(255,255,255,this.alpha))
                this.textTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer, this.renderText)
                w,h = Int32[1], Int32[1]
                SDL2.TTF_SizeText(this.font, this.text, pointer(w), pointer(h))
                this.size = Math.Vector2(w[1], h[1])
                
                if this.isCentered 
                    this.position = Math.Vector2(max(((1920/this.zoom) - this.size.x)/2, 0), this.position.y/this.zoom)
                end
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
                this.renderText = SDL2.TTF_RenderText_Blended( this.font, this.text, SDL2.SDL_Color(255,255,255,this.alpha))
                this.textTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer, this.renderText)

                if this.autoSizeText
                    w,h = Int32[1], Int32[1]
                    SDL2.TTF_SizeText(this.font, this.text, pointer(w), pointer(h))
                    this.size = Math.Vector2(w[1], h[1])
                end
                if this.isCentered 
                    this.position = Math.Vector2(max(((1920/this.zoom) - this.size.x)/2, 0), this.position.y)
                end
            end
        elseif s == :setVector2Value
            function(field, x, y)
                setfield!(this, field, Math.Vector2(x,y))
                println("set $(field) to $(getfield(this, field))")
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