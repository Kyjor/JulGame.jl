module TextBoxModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    export TextBox      
    mutable struct TextBox
        alpha
        font
        fontPath::String
        fontSize::Int32
        id::Int32
        isCenteredX::Bool
        isCenteredY::Bool
        isWorldEntity::Bool
        name::String
        persistentBetweenScenes::Bool
        position::Vector2
        renderText
        size::Vector2
        text::String
        textTexture

        function TextBox(name::String, fontPath::String, fontSize::Number, position::Math.Vector2, text::String, isCenteredX::Bool = false, isCenteredY::Bool = false; isWorldEntity::Bool=false) # TODO: replace bool with enum { left, center, right, etc }
            this = new()

            this.alpha = 255
            this.fontPath = fontPath
            this.fontSize = fontSize
            this.id = 0
            this.isCenteredX = isCenteredX
            this.isCenteredY = isCenteredY
            this.name = name
            this.position = position
            this.text = text
            this.isWorldEntity = isWorldEntity
            this.textTexture = C_NULL
            this.persistentBetweenScenes = false
            
            basePath = fontPath != "" ? joinpath(BasePath, "assets", "fonts") : joinpath(pwd(), "..", "Fonts")
            if fontPath == ""
                fontPath = joinpath("FiraCode", "ttf", "FiraCode-Regular.ttf")
            end

            UI.load_font(this, basePath, fontPath)

            return this
        end
    end

    function UI.render(this::TextBox, debug::Bool)
        if this.textTexture == C_NULL
            return
        end

        if debug
            SDL2.SDL_RenderDrawLines(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, [
                SDL2.SDL_Point(this.position.x, this.position.y), 
                SDL2.SDL_Point(this.position.x + this.size.x, this.position.y),
                SDL2.SDL_Point(this.position.x + this.size.x, this.position.y + this.size.y), 
                SDL2.SDL_Point(this.position.x, this.position.y + this.size.y), 
                SDL2.SDL_Point(this.position.x, this.position.y)], 5)
        end

        cameraDiff = this.isWorldEntity ? 
        Math.Vector2(MAIN.scene.camera.position.x * SCALE_UNITS, MAIN.scene.camera.position.y * SCALE_UNITS) : 
        Math.Vector2(0,0)

        @assert SDL2.SDL_RenderCopyF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.textTexture, C_NULL, Ref(SDL2.SDL_FRect(this.position.x - cameraDiff.x, this.position.y - cameraDiff.y, this.size.x, this.size.y))) == 0 "error rendering textbox text: $(unsafe_string(SDL2.SDL_GetError()))"
    end

    function UI.load_font(this::TextBox, basePath::String, fontPath::String)
        println("loading font from base: $(basePath)")
        println("loading font from $(fontPath)")
        this.font = CallSDLFunction(SDL2.TTF_OpenFont, joinpath(basePath, fontPath), this.fontSize)
        if this.font == C_NULL
            return
        end
        if fontPath != joinpath("FiraCode", "ttf", "FiraCode-Regular.ttf")
            this.fontPath = fontPath
        end

        this.renderText = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, this.font, this.text, SDL2.SDL_Color(255,255,255,this.alpha))
        
        surface = unsafe_wrap(Array, this.renderText, 10; own = false)
        this.size = Math.Vector2(surface[1].w, surface[1].h)
        
        this.textTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.renderText)
    end

    function UI.initialize(this::TextBox)
        if !this.isWorldEntity
            UI.center_text(this)
        end
    end

    function UI.set_parent(this::TextBox, parent)
        this.parent = parent
    end

    """
        update_text(this::TextBox, newText)

    Update the text of the TextBox with the given `newText`. This function updates the `text` field of the TextBox, renders the new text using the specified font, and creates a texture from the rendered text. If the TextBox is not a world entity, it centers the text.

    # Arguments
    - `this::TextBox`: The TextBox object to update.
    - `newText`: The new text to set for the TextBox.

    # Examples
    """
    function UI.update_text(this::TextBox, newText::String)
        if length(newText) == 0
            newText = " " # prevents segfault when text is empty
        end

        this.text = newText
        SDL2.SDL_FreeSurface(this.renderText)
        SDL2.SDL_DestroyTexture(this.textTexture)
        this.renderText = SDL2.TTF_RenderUTF8_Blended(this.font, this.text, SDL2.SDL_Color(255,255,255,(this.alpha+1)%256))
        surface = unsafe_wrap(Array, this.renderText, 10; own = false)

        this.size = Math.Vector2(surface[1].w, surface[1].h)
        this.textTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.renderText)
        
        if !this.isWorldEntity
            UI.center_text(this)
        end
    end

    function UI.set_color(this::TextBox, r,g,b)
        SDL2.SDL_SetTextureColorMod(this.textTexture, r%256, g%256, b%256);
    end

    function UI.center_text(this::TextBox)
        if this.isCenteredX
            this.position = Math.Vector2(max(MAIN.scene.camera.size.x/2 - this.size.x/2, 0), this.position.y)
        end
        if this.isCenteredY
            this.position = Math.Vector2(this.position.x, max(MAIN.scene.camera.size.y/2 - this.size.y/2, 0))
        end
    end
    
    function UI.update_font_size(this::TextBox, newSize::Int32)
        this.fontSize = newSize
        # TODO: SDL2.TTF_SetFontSize(this.font, newSize)
        # close font, reopen with new size
        SDL2.TTF_CloseFont(this.font)
        UI.load_font(this, joinpath(BasePath, "assets", "fonts"), joinpath(this.fontPath))
    end

    function UI.destroy(this::TextBox)
        if this.textTexture == C_NULL
            return
        end

        SDL2.SDL_DestroyTexture(this.textTexture)
        this.textTexture = C_NULL
    end
end
