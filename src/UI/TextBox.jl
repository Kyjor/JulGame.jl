module TextBoxModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    using SimpleDirectMediaLayer.LibSDL2

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

        function TextBox(name, basePath, fontPath, fontSize, position::Math.Vector2, size::Math.Vector2, sizePercentage::Math.Vector2, text::String, isCentered::Bool, isDefaultFont = false) # TODO: replace bool with enum { left, center, right, etc }
            this = new()

            this.alpha = 255
            this.basePath = isDefaultFont ? joinpath(@__DIR__, "..", "Fonts") : basePath
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

                if this.isTextUpdated
                    this.updateText(this.text)
                    this.isTextUpdated = false
                end
                # @assert 
                SDL_RenderCopy(
                    this.renderer, this.textTexture, C_NULL, Ref(SDL_Rect((this.position.x), this.position.y, this.size.x, this.size.y))
                ) 
                # == 0 "error rendering textbox text: $(unsafe_string(SDL_GetError()))"
            end
        elseif s == :initialize
            function(renderer, zoom)
                this.zoom = zoom
                this.renderer = renderer
                path = this.isDefaultFont ? joinpath(this.basePath, this.fontPath) : joinpath(this.basePath, "projectFiles", "assets", "fonts", this.fontPath)
                font = TTF_OpenFont(path, this.fontSize)
                println(unsafe_string(SDL_GetError()))
                this.font = font
                this.renderText = TTF_RenderText_Blended(this.font, this.text, SDL_Color(255,255,255,this.alpha))
                this.textTexture = SDL_CreateTextureFromSurface(this.renderer, this.renderText)
                w,h = Int32[1], Int32[1]
                TTF_SizeText(this.font, this.text, pointer(w), pointer(h))
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
                SDL_FreeSurface(this.renderText)
                SDL_DestroyTexture(this.textTexture)
                this.renderText = TTF_RenderText_Blended( this.font, this.text, SDL_Color(255,255,255,this.alpha))
                this.textTexture = SDL_CreateTextureFromSurface(this.renderer, this.renderText)

                if this.autoSizeText
                    w,h = Int32[1], Int32[1]
                    TTF_SizeText(this.font, this.text, pointer(w), pointer(h))
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