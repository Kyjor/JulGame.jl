module ImmediateTextModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI

    export ImmediateText, immediate

    # Dictionary to store active immediate text elements by their id
    const IMMEDIATE_TEXT_CACHE = Dict{String, Any}()

    mutable struct ImmediateText
        alpha::UInt8
        anchorOffset::Vector2
        font
        fontPath::String
        fontSize::Int32
        id::String
        isCenteredX::Bool
        isCenteredY::Bool
        isWorldEntity::Bool
        position::Vector2
        renderText
        size::Vector2
        text::String
        textTexture
        isConstructed::Bool
        lastUpdate::UInt64

        function ImmediateText(text::String, fontPath::String, fontSize::Number, position::Math.Vector2, id::String, isCenteredX::Bool = false, isCenteredY::Bool = false; anchorOffset::Math.Vector2 = Math.Vector2(0,0), isWorldEntity::Bool=false)
            this = new()

            this.isConstructed = false
            this.alpha = 255
            this.fontPath = fontPath
            this.fontSize = Int32(fontSize)
            this.id = id
            this.anchorOffset = anchorOffset
            this.isCenteredX = isCenteredX
            this.isCenteredY = isCenteredY
            this.position = position
            setfield!(this, :text, text)
            this.isWorldEntity = isWorldEntity
            this.textTexture = C_NULL
            this.renderText = C_NULL
            this.lastUpdate = SDL2.SDL_GetTicks()
            
            if fontPath == ""
                fontPath = joinpath("FiraCode-Regular.ttf")
            end

            UI.load_font(this, joinpath(BasePath, "assets", "fonts"), fontPath)
            
            if this.isCenteredX || this.isCenteredY
                UI.center_text(this)
            end
            
            this.isConstructed = true

            return this
        end
    end

    """
    immediate(id::String, text::String, fontPath::String, fontSize::Number, position::Math.Vector2, isCenteredX::Bool = false, isCenteredY::Bool = false; anchorOffset::Math.Vector2 = Math.Vector2(0,0), isWorldEntity::Bool=false)

    Creates a new immediate text or updates an existing one with the given id.
    
    # Arguments
    - `id::String`: Unique identifier for this immediate text
    - `text::String`: The text to display
    - `fontPath::String`: Path to the font file
    - `fontSize::Number`: Size of the font
    - `position::Math.Vector2`: Position of the text
    - `isCenteredX::Bool`: Whether to center the text horizontally
    - `isCenteredY::Bool`: Whether to center the text vertically
    - `anchorOffset::Math.Vector2`: Offset from the anchor point
    - `isWorldEntity::Bool`: Whether this text should be positioned in world space
    
    # Returns
    The immediate text object
    """
    function immediate(id::String, text::String, fontPath::String, fontSize::Number, position::Math.Vector2, isCenteredX::Bool = false, isCenteredY::Bool = false; anchorOffset::Math.Vector2 = Math.Vector2(0,0), isWorldEntity::Bool=false)
        if haskey(IMMEDIATE_TEXT_CACHE, id)
            # Update existing immediate text
            immediateText = IMMEDIATE_TEXT_CACHE[id]
            
            # Only update if something has changed
            needsUpdate = false
            if immediateText.text != text
                setfield!(immediateText, :text, text)
                needsUpdate = true
            end
            
            if immediateText.position != position
                immediateText.position = position
                needsUpdate = true
            end
            
            if immediateText.fontSize != fontSize
                immediateText.fontSize = Int32(fontSize)
                needsUpdate = true
            end
            
            if immediateText.fontPath != fontPath
                immediateText.fontPath = fontPath
                needsUpdate = true
            end
            
            if immediateText.isCenteredX != isCenteredX || immediateText.isCenteredY != isCenteredY
                immediateText.isCenteredX = isCenteredX
                immediateText.isCenteredY = isCenteredY
                needsUpdate = true
            end
            
            if immediateText.anchorOffset != anchorOffset
                immediateText.anchorOffset = anchorOffset
                needsUpdate = true
            end
            
            if immediateText.isWorldEntity != isWorldEntity
                immediateText.isWorldEntity = isWorldEntity
                needsUpdate = true
            end
            
            if needsUpdate
                # Reload font and regenerate texture
                UI.load_font(immediateText, joinpath(BasePath, "assets", "fonts"), fontPath)
                if immediateText.isCenteredX || immediateText.isCenteredY
                    UI.center_text(immediateText)
                end
            end
            
            # Update the last update timestamp
            immediateText.lastUpdate = SDL2.SDL_GetTicks()
            
            return immediateText
        else
            # Create new immediate text
            immediateText = ImmediateText(text, fontPath, fontSize, position, id, isCenteredX, isCenteredY; anchorOffset=anchorOffset, isWorldEntity=isWorldEntity)
            IMMEDIATE_TEXT_CACHE[id] = immediateText
            return immediateText
        end
    end

    """
    render_all_immediate_texts()
    
    Renders all active immediate texts.
    Should be called once per frame in the main render loop.
    Also handles cleanup of unused immediate texts.
    """
    function render_all_immediate_texts(debug::Bool = false)
        current_time = SDL2.SDL_GetTicks()
        expired_ids = String[]
        
        # Render all immediate texts and track which ones are unused
        for (id, immediateText) in IMMEDIATE_TEXT_CACHE
            # Check if this immediate text hasn't been used for a while (5 seconds)
            if current_time - immediateText.lastUpdate > 5000
                push!(expired_ids, id)
                continue
            end
            
            render_immediate_text(immediateText, debug)
        end
        
        # Clean up expired immediate texts
        for id in expired_ids
            cleanup_immediate_text(id)
        end
    end

    """
    render_immediate_text(immediateText::ImmediateText, debug::Bool = false)
    
    Renders a single immediate text element.
    """
    function render_immediate_text(this::ImmediateText, debug::Bool = false)
        if this.textTexture == C_NULL
            return
        end

        if debug
            rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(255)))
            SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)
            SDL2.SDL_SetRenderDrawColor(Renderer, 0, 255, 0, 255);
            SDL2.SDL_RenderDrawLines(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, [
                SDL2.SDL_Point(this.position.x, this.position.y), 
                SDL2.SDL_Point(this.position.x + this.size.x, this.position.y),
                SDL2.SDL_Point(this.position.x + this.size.x, this.position.y + this.size.y), 
                SDL2.SDL_Point(this.position.x, this.position.y + this.size.y), 
                SDL2.SDL_Point(this.position.x, this.position.y)], 5)
            SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);
        end

        camera = MAIN.scene.camera
        cameraDiff = this.isWorldEntity && camera !== nothing ? 
        Math.Vector2((camera.position.x + camera.offset.x) * SCALE_UNITS, (camera.position.y + camera.offset.y) * SCALE_UNITS) : 
        Math.Vector2(0,0)

        @assert SDL2.SDL_RenderCopyF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.textTexture, C_NULL, Ref(SDL2.SDL_FRect(this.position.x - cameraDiff.x, this.position.y - cameraDiff.y, this.size.x, this.size.y))) == 0 "error rendering immediate text: $(unsafe_string(SDL2.SDL_GetError()))"
    end

    """
    cleanup_immediate_text(id::String)
    
    Cleans up resources for an immediate text element and removes it from the cache.
    """
    function cleanup_immediate_text(id::String)
        if haskey(IMMEDIATE_TEXT_CACHE, id)
            immediateText = IMMEDIATE_TEXT_CACHE[id]
            
            # Clean up SDL resources
            if immediateText.textTexture != C_NULL
                SDL2.SDL_DestroyTexture(immediateText.textTexture)
                immediateText.textTexture = C_NULL
            end
            
            if immediateText.renderText != C_NULL
                SDL2.SDL_FreeSurface(immediateText.renderText)
                immediateText.renderText = C_NULL
            end
            
            # Remove from cache
            delete!(IMMEDIATE_TEXT_CACHE, id)
        end
    end

    """
    UI.load_font(this::ImmediateText, basePath::String, fontPath::String)
    
    Loads a font for an immediate text element.
    """
    function UI.load_font(this::ImmediateText, basePath::String, fontPath::String)
        @debug string("loading font from $(basePath)\\$(fontPath)")
        this.font = load_font_sdl(basePath, fontPath, this.fontSize)
        if this.font == C_NULL
            error("Failed to load font")
            return
        end
        if fontPath != joinpath("FiraCode-Regular.ttf")
            this.fontPath = fontPath
        end

        # prevents segfault when text is empty
        if this.text == ""
            this.text = " "
        end

        # Clean up previous SDL resources if they exist
        if this.renderText != C_NULL
            SDL2.SDL_FreeSurface(this.renderText)
            this.renderText = C_NULL
        end
        
        if this.textTexture != C_NULL
            SDL2.SDL_DestroyTexture(this.textTexture)
            this.textTexture = C_NULL
        end

        this.renderText = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, this.font, this.text, SDL2.SDL_Color(255,255,255,this.alpha))
        if this.renderText == C_NULL
            error("Failed to render text for immediate text with id $(this.id)")
            return
        end

        surface = unsafe_wrap(Array, this.renderText, 10; own = false)
        this.size = Math.Vector2(surface[1].w, surface[1].h)
        
        this.textTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.renderText)
    end

    """
    UI.center_text(this::ImmediateText)
    
    Centers an immediate text element based on its centering options.
    """
    function UI.center_text(this::ImmediateText)
        if this.isCenteredX
            this.position = Math.Vector2(this.position.x - this.size.x / 2, this.position.y)
        end
        
        if this.isCenteredY
            this.position = Math.Vector2(this.position.x, this.position.y - this.size.y / 2)
        end
    end

    """
    load_font_sdl(basePath::String, fontPath::String, fontSize::Int32)
    
    Loads a font using SDL, either from cache or from disk.
    """
    function load_font_sdl(basePath::String, fontPath::String, fontSize::Int32)
        if haskey(JulGame.FONT_CACHE, get_comma_separated_path(fontPath))
            raw_data = JulGame.FONT_CACHE[get_comma_separated_path(fontPath)]
            rw = SDL2.SDL_RWFromConstMem(pointer(raw_data), length(raw_data))
            if rw != C_NULL
                @debug("loading font from cache")
                @debug("comma separated path: ", get_comma_separated_path(fontPath))
                return SDL2.TTF_OpenFontRW(rw, 1, fontSize)
            end
        end
        @debug "Loading font from disk, there are $(length(JulGame.FONT_CACHE)) fonts in cache"
        return CallSDLFunction(SDL2.TTF_OpenFont, joinpath(basePath, fontPath), fontSize)
    end

    """
    get_comma_separated_path(path::String)
    
    Helper function to convert a path to a comma-separated string for use as a cache key.
    """
    function get_comma_separated_path(path::String)
        return replace(path, '\\' => ',', '/' => ',')
    end
end 