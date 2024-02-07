module TextBoxModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI.JulGame: deprecated_get_property
    import ..UI
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
        persistentBetweenScenes::Bool
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
            this.persistentBetweenScenes = false

            return this
        end
    end

    function Base.getproperty(this::TextBox, s::Symbol)
        method_props = (
            render = UI.render,
            initialize = UI.initialize,
            setPosition = UI.set_position,
            setParent = UI.set_parent,
            updateText = UI.update_text,
            setVector2Value = UI.set_vector2_value,
            setColor = UI.set_color,
            centerText = UI.center_text,
            destroy = UI.destroy
        )
        deprecated_get_property(method_props, this, s)
    end

    function UI.render(this::TextBox, DEBUG)
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

        @assert SDL2.SDL_RenderCopyF(JulGame.Renderer, this.textTexture, C_NULL, Ref(SDL2.SDL_FRect(this.position.x - cameraDiff.x, this.position.y - cameraDiff.y, this.size.x, this.size.y))) == 0 "error rendering textbox text: $(unsafe_string(SDL2.SDL_GetError()))"
    end

    function UI.initialize(this::TextBox)
        Initialize(this)
    end

    function UI.set_position(this::TextBox, position::Math.Vector2)
    end

    function UI.set_parent(this::TextBox, parent)
        this.parent = parent
    end

    function UI.update_text(this::TextBox, newText)
        this.text = newText
        SDL2.SDL_FreeSurface(this.renderText)
        SDL2.SDL_DestroyTexture(this.textTexture)
        this.renderText = SDL2.TTF_RenderUTF8_Blended(this.font, this.text, SDL2.SDL_Color(255,255,255,(this.alpha+1)%256))
        surface = unsafe_wrap(Array, this.renderText, 10; own = false)

        this.size = Math.Vector2(surface[1].w, surface[1].h)
        this.textTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, this.renderText)
        
        if !this.isWorldEntity
            this.centerText()
        end
    end

    function UI.set_vector2_value(this::TextBox, field, x, y)
        setfield!(this, field, Math.Vector2(x,y))
        println("set $(field) to $(getfield(this, field))")
    end

    function UI.set_color(this::TextBox, r,g,b)
        SDL2.SDL_SetTextureColorMod(this.textTexture, r%256, g%256, b%256);
    end

    function UI.center_text(this::TextBox)
        if this.isCenteredX
            this.position = Math.Vector2(max(MAIN.scene.camera.dimensions.x/2 - this.size.x/2, 0), this.position.y)
        end
        if this.isCenteredY
            this.position = Math.Vector2(this.position.x, max(MAIN.scene.camera.dimensions.y/2 - this.size.y/2, 0))
        end
    end

    function UI.destroy(this::TextBox)
        if this.textTexture == C_NULL
            return
        end

        SDL2.SDL_DestroyTexture(this.textTexture)
        this.textTexture = C_NULL
    end

    function UI.Initialize(this)
        path = this.isDefaultFont ? joinpath(this.basePath, this.fontPath) : joinpath(this.basePath, "assets", "fonts", this.fontPath)
        # println("loading font from $(path)")
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
