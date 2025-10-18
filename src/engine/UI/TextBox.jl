module TextBoxModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    using ..UI.TextStyleModule
    using ..UI.TextEffectRendererModule
    using JulGame.EffectsModule
    using JulGame.EffectRendererModule
    using JulGame.EffectCacheModule
    export TextBox
    export DEFAULT_FONT
    export apply_effects!
    export apply_style!
    export update_effects      
    DEFAULT_FONT = "Default"
    mutable struct TextBox <: UI.UIElement
        font::Union{Ptr{SDL2.TTF_Font}, Ptr{Nothing}}
        fontPath::String
        fontSize::Int
        isConstructed::Bool
        maxLineWidth::Int
        renderText::Union{Ptr{SDL2.SDL_Surface}, Ptr{Nothing}}
        text::String
        textTexture::Union{Ptr{SDL2.SDL_Texture}, Ptr{Nothing}}
        wrapWords::Bool
        textStyle::Union{TextStyleModule.TextStyle, Nothing}
        isDynamic::Bool
        #  effects support
        effects::Vector{Any}  # Will hold Effect objects
        effectTexture::Union{Ptr{SDL2.SDL_Texture}, Ptr{Nothing}}
        needsEffectUpdate::Bool

        function TextBox(text::String; 
            id::String=JulGame.generate_uuid(), 
            name::String = "TextBox", 
            anchor::Symbol = :none,
            anchorOffset::Math.Vector2 = Math.Vector2(0,0), 
            isWorldEntity::Bool=false, 
            layer::Int=0,
            position::Math.Vector2 = Math.Vector2(0,0), 
            clickEvents::Vector{Function} = Function[],
            hoverEnterEvents::Vector{Function} = Function[],
            hoverExitEvents::Vector{Function} = Function[],
            isActive::Bool=true,
            persistentBetweenScenes::Bool=false,
            color::NTuple{4, Int}=(255, 255, 255, 255), 
            fontPath::String = "FiraCode-Regular.ttf", 
            fontSize::Int = 16, 
            maxLineWidth::Int=0, 
            wrapWords::Bool=true,
            textStyle::Union{TextStyleModule.TextStyle, Nothing}=nothing,
            isDynamic::Bool=false,
            parent::Union{UI.UIElement, Nothing, JulGame.IEntity, JulGame.ISprite}=nothing
        )

            this = new()
            
            this.isConstructed = false
            this.anchor = deepcopy(UI.anchor_types)

            this.anchor.current_state = anchor
            this.anchorOffset = anchorOffset

            this.clickEvents = clickEvents
            this.hoverEnterEvents = hoverEnterEvents
            this.hoverExitEvents = hoverExitEvents

            this.font = C_NULL
            this.fontPath = fontPath
            this.fontSize = fontSize  # Store the base font size
            this.id = id
            this.layer = layer
            this.name = name
            this.position = position
            setfield!(this, :text, text)
            this.isWorldEntity = isWorldEntity
            this.persistentBetweenScenes = persistentBetweenScenes
            this.isActive = isActive
            this.color = color
            this.maxLineWidth = maxLineWidth
            this.wrapWords = wrapWords
            this.isHovered = false
            this.textStyle = textStyle
            this.isDynamic = isDynamic
            
            this.textTexture = C_NULL
            this.renderText = C_NULL
            this.parent = parent
            # Initialize effects
            this.effects = Any[]
            this.effectTexture = C_NULL
            this.needsEffectUpdate = false
            if strip(fontPath) == ""
                @debug "fontPath is empty, using default font"
                fontPath = "Default"
            end

            # Load the font with the true font size (scaled for current window size)
            UI.load_font(this, fontPath)
            this.isConstructed = true

            return this
        end
    end

    function UI.render(this::TextBox)
        if !this.isActive || JulGame.IS_CHANGING_SCENE
            return
        end
        
        # Try to apply effects if they're pending and renderer is now available
        if !isempty(this.effects) && this.needsEffectUpdate
            update_effects(this)
        end
        
        # Use effect texture if available, otherwise use regular texture
        texture_to_render = if !isempty(this.effects) && this.effectTexture != C_NULL
            this.effectTexture
        elseif this.textTexture != C_NULL
            this.textTexture
        else
            return  # No texture to render
        end
        if !this.isWorldEntity
            UI.align_to_anchor(this)
        end

        if JulGame.IS_DEBUG
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
        
        # Handle world coordinates for world entities, similar to Sprite component
        if this.isWorldEntity && camera !== nothing
            # Calculate position in screen space
            posX = (this.position.x - (camera.position.x + camera.offset.x)) * SCALE_UNITS
            posY = (this.position.y - (camera.position.y + camera.offset.y)) * SCALE_UNITS
            
            # Don't scale the size, keep it the same as screen space
            # Render with world-space positioning only, not scaling size
            @assert SDL2.SDL_RenderCopyF(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
                texture_to_render, 
                C_NULL, 
                Ref(SDL2.SDL_FRect(
                    Float32(posX), 
                    Float32(posY), 
                    Float32(this.size.x), 
                    Float32(this.size.y)
                ))
            ) == 0 "error rendering textbox text: $(unsafe_string(SDL2.SDL_GetError()))"
        else
            # Render with screen-space positioning (traditional UI)
            @assert SDL2.SDL_RenderCopyF(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
                texture_to_render, 
                C_NULL, 
                Ref(SDL2.SDL_FRect(
                    Float32(this.position.x), 
                    Float32(this.position.y), 
                    Float32(this.size.x), 
                    Float32(this.size.y)
                ))
            ) == 0 "error rendering textbox text: $(unsafe_string(SDL2.SDL_GetError()))"
        end
    end

    function UI.load_font(this::TextBox, fontPath::String)
        # Calculate the true font size based on window resolution
        #trueFontSize = get_true_font_size(this.fontSize)
        trueFontSize = this.fontSize

        # If the font is already loaded, clean it up
        if this.font != C_NULL
            @debug("closing font")
            #println(this.font)
            SDL2.TTF_CloseFont(this.font)
            this.font = C_NULL
        end
        free_text_resources(this)

        
        this.font = load_font_sdl(fontPath, trueFontSize)
        if this.font == C_NULL
            error("Failed to load font, $(unsafe_string(SDL2.SDL_GetError())), loading default font")
            this.fontPath = DEFAULT_FONT
            this.font = CallSDLFunction(SDL2.TTF_OpenFontRW, SDL2.SDL_RWFromConstMem(pointer(JulGame.BUILT_IN_ASSETS["Font"]), length(JulGame.BUILT_IN_ASSETS["Font"])), 1, Math.TypeConversions.safe_int32_convert(fontSize))
        end
        if fontPath != "Default"
            this.fontPath = fontPath
        end

        # prevents segfault when text is empty
        if this.text == ""
            this.text = " "
        end

        # Use high-quality font rendering with or without effects
        if this.textStyle === nothing || isempty((this.textStyle::Any).effects)
            this.renderText = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, this.font, this.text, SDL2.SDL_Color(Math.TypeConversions.safe_int32_convert(this.color[1]), Math.TypeConversions.safe_int32_convert(this.color[2]), Math.TypeConversions.safe_int32_convert(this.color[3]), Math.TypeConversions.safe_int32_convert(this.color[4])))
            if this.renderText == C_NULL
                error("Failed to render text for textbox $(this.name)")
                return
            end
            surface = unsafe_wrap(Array, this.renderText, 10; own = false)
            this.size = Math.Vector2(surface[1].w, surface[1].h)
            this.textTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.renderText)
        else
            # Styled path renders directly to texture using cache
            this.textTexture = TextEffectRendererModule.render_styled_text!(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.text, this.font, this.color, this.textStyle, this.fontPath, this.fontSize)
            if this.textTexture == C_NULL
                @debug("Styled text rendering failed, falling back to basic rendering for $(this.name)")
                # Fallback to basic rendering
                this.renderText = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, this.font, this.text, SDL2.SDL_Color(Math.TypeConversions.safe_int32_convert(this.color[1]), Math.TypeConversions.safe_int32_convert(this.color[2]), Math.TypeConversions.safe_int32_convert(this.color[3]), Math.TypeConversions.safe_int32_convert(this.color[4])))
                if this.renderText == C_NULL
                    error("Failed to render text for textbox $(this.name)")
                    return
                end
                surface = unsafe_wrap(Array, this.renderText, 10; own = false)
                this.size = Math.Vector2(surface[1].w, surface[1].h)
                this.textTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.renderText)
            else
                w = Ref{Cint}(0); h = Ref{Cint}(0)
                fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
                SDL2.SDL_QueryTexture(this.textTexture, fmt, access, w, h)
                this.size = Math.Vector2(w[], h[])
            end
        end

        # Set texture scaling quality to linear (applies to styled path too)
        if this.textTexture != C_NULL
            SDL2.SDL_SetTextureScaleMode(this.textTexture, SDL2.SDL_ScaleModeLinear)
        end

        if !this.isWorldEntity
            UI.align_to_anchor(this)
        end
    end

    function UI.initialize(this::TextBox)
        # Ensure font is properly scaled for the current window size
        UI.handle_window_resize(this)
        # Only center screen-space UI, not world entities
        if !this.isWorldEntity
            UI.align_to_anchor(this)
        end
    end

    function UI.add_click_event(this::TextBox, event)
        push!(this.clickEvents, event)
    end

    function load_font_sdl(fontPath::String, fontSize::Int)
        if haskey(JulGame.FONT_CACHE, get_comma_separated_path(fontPath)) || fontPath == "Default" || fontPath == ""
            if fontPath == "Default" || fontPath == ""
                raw_data = JulGame.BUILT_IN_ASSETS["Font"]
                @debug "loading default font"
            else
                raw_data = JulGame.FONT_CACHE[get_comma_separated_path(fontPath)]
                @debug "loading font from cache"
            end
            rw = SDL2.SDL_RWFromConstMem(pointer(raw_data), length(raw_data))
            if rw != C_NULL
                @debug("loading font from cache")
                @debug("comma separated path: ", get_comma_separated_path(fontPath))
                return CallSDLFunction(SDL2.TTF_OpenFontRW, rw, 1, Math.TypeConversions.safe_int32_convert(fontSize))
            end
        end
        @debug "Loading font from disk, there are $(length(JulGame.FONT_CACHE)) fonts in cache"
        
        basePath = joinpath(JulGame.BasePath, "assets", "fonts")
        return CallSDLFunction(SDL2.TTF_OpenFont, joinpath(basePath, fontPath), Math.TypeConversions.safe_int32_convert(fontSize))
    end

    function get_comma_separated_path(path::String)
        # Normalize the path to use forward slashes
        normalized_path = replace(path, '\\' => '/')
        
        # Split the path into components
        parts = split(normalized_path, '/')
        
        result = join(parts[1:end], ",")
    
        return result  
    end

    """
        rerender_text(this::TextBox)

    Recreates the font surface and texture. If the TextBox is not a world entity, it centers the text.

    # Arguments
    - `this::TextBox`: The TextBox object to update.

    # Examples
    """
    function UI.rerender_text(this::TextBox)
        if JulGame.IS_CHANGING_SCENE
            return
        end
        free_text_resources(this)

        if this.text == ""
            this.text = " "
        end

        if this.textStyle === nothing || isempty((this.textStyle::Any).effects)
            # Check if we need to wrap text
            color = SDL2.SDL_Color(Math.TypeConversions.safe_int32_convert(this.color[1]), Math.TypeConversions.safe_int32_convert(this.color[2]), Math.TypeConversions.safe_int32_convert(this.color[3]), Math.TypeConversions.safe_int32_convert(this.color[4]))
            this.renderText = if this.maxLineWidth > 0 && this.font != C_NULL && this.text != ""
                SDL2.TTF_RenderUTF8_Blended_Wrapped(this.font, this.wrapWords ? this.text : wrap_text(this.text, this.font, this.maxLineWidth, this.wrapWords), color, Math.TypeConversions.safe_int32_convert(this.maxLineWidth))
            elseif this.font != C_NULL && this.text != ""
                this.renderText = SDL2.TTF_RenderUTF8_Blended(this.font, this.text, color)
            else
                C_NULL
            end
            if this.renderText == C_NULL
                @debug("Failed to render text for textbox $(this.name)")
                return
            end
            surface = unsafe_wrap(Array, this.renderText, 10; own = false)
            this.size = Math.Vector2(surface[1].w, surface[1].h)
            this.textTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.renderText)
        else
            # Styled path: use single line render for now, wrapping handled upstream
            this.textTexture = TextEffectRendererModule.render_styled_text!(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.text, this.font, this.color, this.textStyle, this.fontPath, this.fontSize)
            if this.textTexture == C_NULL
                @debug("Styled text rendering failed in rerender_text, falling back to basic rendering for $(this.name)")
                # Fallback to basic rendering
                color = SDL2.SDL_Color(Math.TypeConversions.safe_int32_convert(this.color[1]), Math.TypeConversions.safe_int32_convert(this.color[2]), Math.TypeConversions.safe_int32_convert(this.color[3]), Math.TypeConversions.safe_int32_convert(this.color[4]))
                this.renderText = if this.maxLineWidth > 0 && this.font != C_NULL && this.text != ""
                    SDL2.TTF_RenderUTF8_Blended_Wrapped(this.font, this.wrapWords ? this.text : wrap_text(this.text, this.font, this.maxLineWidth, this.wrapWords), color, Math.TypeConversions.safe_int32_convert(this.maxLineWidth))
                elseif this.font != C_NULL && this.text != ""
                    this.renderText = SDL2.TTF_RenderUTF8_Blended(this.font, this.text, color)
                else
                    C_NULL
                end
                if this.renderText == C_NULL
                    @debug("Failed to render text for textbox $(this.name)")
                    return
                end
                surface = unsafe_wrap(Array, this.renderText, 10; own = false)
                this.size = Math.Vector2(surface[1].w, surface[1].h)
                this.textTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.renderText)
            else
                w = Ref{Cint}(0); h = Ref{Cint}(0)
                fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
                SDL2.SDL_QueryTexture(this.textTexture, fmt, access, w, h)
                this.size = Math.Vector2(w[], h[])
            end
        end

        if !this.isWorldEntity
            UI.align_to_anchor(this)
        end
        
        # Update effects if needed
        if !isempty(this.effects)
            update_effects(this)
        end
    end

    function free_text_resources(this::TextBox)
        if this.renderText != C_NULL
            SDL2.SDL_FreeSurface(this.renderText)
            this.renderText = C_NULL
        end
        # Only destroy texture if it's NOT from the effect cache
        # Effect cache manages its own texture lifecycle
        if this.textTexture != C_NULL && (this.textStyle === nothing || isempty((this.textStyle::Any).effects))
            @debug("Destroying non-cached texture for $(this.name)")
            SDL2.SDL_DestroyTexture(this.textTexture)
            this.textTexture = C_NULL
        elseif this.textTexture != C_NULL
            # Styled texture is managed by cache, just clear our reference
            @debug("Clearing cached texture reference for $(this.name)")
            this.textTexture = C_NULL
        end
    end

    # Helper function to manually wrap text at character boundaries
    function wrap_text(text::String, font, maxWidth::Int, wrapWords::Bool)
        if maxWidth <= 0 || isempty(text)
            return text
        end

        lines = String[]
        current_line = ""
        current_width = 0
        
        # If wrapping at word boundaries
        if wrapWords
            words = split(text)
            for word in words
                w, h = Ref{Cint}(0), Ref{Cint}(0)
                word_with_space = word * " "
                SDL2.TTF_SizeUTF8(font, word_with_space, w, h)
                
                if current_width + w[] > maxWidth && !isempty(current_line)
                    push!(lines, rstrip(current_line))
                    current_line = word * " "
                    current_width = w[]
                else
                    current_line *= word * " "
                    current_width += w[]
                end
            end
            
            if !isempty(current_line)
                push!(lines, rstrip(current_line))
            end
        else
            # Character by character wrapping
            for c in text
                char_str = string(c)
                w, h = Ref{Cint}(0), Ref{Cint}(0)
                SDL2.TTF_SizeUTF8(font, char_str, w, h)
                
                if current_width + w[] > maxWidth && !isempty(current_line)
                    push!(lines, current_line)
                    current_line = char_str
                    current_width = w[]
                else
                    current_line *= char_str
                    current_width += w[]
                end
            end
            
            if !isempty(current_line)
                push!(lines, current_line)
            end
        end
        
        return join(lines, "\n")
    end

    function UI.set_color(this::TextBox; r::Int=255, g::Int=255, b::Int=255, a::Int=255)
        this.color = (r%256, g%256, b%256, a%256)
        UI.rerender_text(this)
    end
    
    function UI.update_font_size(this::TextBox, newSize::Int; basePath::String = "")
        # Store the base font size (the size specified by the user)
        this.fontSize = newSize
        
        # Calculate the true font size based on window resolution
        trueFontSize = get_true_font_size(this.fontSize)
        
        # Close the current font
        if this.font != C_NULL
            #println("closing font from update_font_size")
            SDL2.TTF_CloseFont(this.font)
            this.font = C_NULL
        end

        UI.load_font(this, joinpath(this.fontPath))
    end

    """
        get_true_font_size(baseFontSize::Int)::Int

    Calculates the true font size based on the current window size and base resolution.
    This ensures text appears at a consistent size regardless of window resolution.

    # Arguments
    - `baseFontSize::Int`: The base font size (designed for the base resolution)

    # Returns
    - `Int`: The scaled font size for the current window resolution
    """
    function get_true_font_size(baseFontSize::Int)::Int
        # Get current window size and base resolution
        windowSize = JulGame.get_window_size()
        baseResolution = JulGame.MAIN.windowManager.baseResolution
        
        # Calculate scaling factors
        scaleX = windowSize.x / baseResolution.x
        scaleY = windowSize.y / baseResolution.y
        
        # Use the smaller scaling factor to ensure text fits in both dimensions
        scale = min(scaleX, scaleY)
        
        # Calculate and return the scaled font size
        return Math.TypeConversions.safe_int32_convert(round(baseFontSize * scale))
    end

    function UI.destroy(this::TextBox)
        if this.font != C_NULL
            SDL2.TTF_CloseFont(this.font)
            this.font = C_NULL
        end
        free_text_resources(this)
        
        # Clean up effect texture
        if this.effectTexture != C_NULL
            SDL2.SDL_DestroyTexture(this.effectTexture)
            this.effectTexture = C_NULL
        end

        MAIN.scene.uiElements = filter(x -> x !== this, MAIN.scene.uiElements)
    end
    
    #  effects API
    function apply_effects!(this::TextBox, effects::Vector)
        this.effects = Any[effect for effect in effects]
        this.needsEffectUpdate = true
        # Try to apply effects now, but don't fail if renderer isn't ready
        update_effects(this)
        return this
    end
    
    function apply_style!(this::TextBox, style)
        return apply_effects!(this, style.effects)
    end
    
    function update_effects(this::TextBox)
        if isempty(this.effects) || !this.needsEffectUpdate
            return
        end
        
        # Check if renderer is available
        if JulGame.Renderer == C_NULL
            @debug("Renderer not available yet, deferring effects for $(this.name)")
            return
        end
        
        # Check if font is available
        if this.font == C_NULL
            @debug("Font not available for effects on $(this.name)")
            return
        end
        
        # Create a fresh base surface for effects processing (like the old system does)
        baseSurface = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, this.font, this.text, SDL2.SDL_Color(Math.TypeConversions.safe_int32_convert(this.color[1]), Math.TypeConversions.safe_int32_convert(this.color[2]), Math.TypeConversions.safe_int32_convert(this.color[3]), Math.TypeConversions.safe_int32_convert(this.color[4])))
        if baseSurface == C_NULL
            @debug("Failed to create base surface for effects on $(this.name)")
            return
        end
        
        # Create target for effects with original color
        target = EffectsModule.SurfaceTarget(baseSurface, this.color)
        
        # Apply effects
        try
            result = EffectRendererModule.apply_effects!(target, this.effects)
            if result isa EffectsModule.SurfaceTarget && result.surface != C_NULL
                # Verify renderer is still valid before creating texture
                if JulGame.Renderer == C_NULL
                    @error("Renderer became null during effects processing for $(this.name)")
                    SDL2.SDL_FreeSurface(result.surface)
                    return
                end
                
                # Convert surface to texture
                if this.effectTexture != C_NULL
                    SDL2.SDL_DestroyTexture(this.effectTexture)
                end
                
                # Use CallSDLFunction like the old system for better error handling
                this.effectTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer, result.surface)
                
                if this.effectTexture != C_NULL
                    # Update size from the effect texture
                    w = Ref{Cint}(0); h = Ref{Cint}(0)
                    fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
                    SDL2.SDL_QueryTexture(this.effectTexture, fmt, access, w, h)
                    this.size = Math.Vector2(w[], h[])
                    
                    this.needsEffectUpdate = false
                else
                    @error("Failed to create texture from effect surface for $(this.name)")
                end
                
                # Clean up the result surface
                if result.surface != baseSurface
                    SDL2.SDL_FreeSurface(result.surface)
                end
            else
                @error("Effects application returned invalid result for $(this.name)")
            end
            
            # Clean up base surface if it wasn't consumed by effects
            if baseSurface != C_NULL && (!isdefined(result, :surface) || result.surface != baseSurface)
                SDL2.SDL_FreeSurface(baseSurface)
            end
        catch e
            @error("Failed to apply effects to $(this.name): $e")
            Base.show_backtrace(stderr, catch_backtrace())
            # Clean up on error
            if baseSurface != C_NULL
                SDL2.SDL_FreeSurface(baseSurface)
            end
        end
    end
#= 
    function Base.setproperty!(this::TextBox, s::Symbol, x)
        try
            setfield!(this, s, x)
            if s == :text || s == :isActive || s == :textColor || s == :maxLineWidth || s == :wrapWords || s == :fontSize || s == :color
                if s == :text && length(x) == 0
                    setfield!(this, s, " ")# prevents segfault when text is empty
                end
                if this.isConstructed
                    @debug("rerendering text for $(this.name) because of $(s) = $(x)")
                    UI.rerender_text(this) # this line MUST stay inside the if for specific fields as we can't call this on fields that are used in this function
                end
            end
        catch e
            error(e)
            Base.show_backtrace(stderr, catch_backtrace())
        end
    end =#

    # Add methods to set and get the maximum line width
    function set_max_line_width(this::TextBox, maxWidth::Int)
        this.maxLineWidth = Math.TypeConversions.safe_int32_convert(maxWidth)
        UI.rerender_text(this)
    end
    
    function get_max_line_width(this::TextBox)
        return this.maxLineWidth
    end
    
    # Add method to control word wrapping behavior
    function set_wrap_words(this::TextBox, wrapWords::Bool)
        this.wrapWords = wrapWords
        UI.rerender_text(this)
    end
    
    function get_wrap_words(this::TextBox)
        return this.wrapWords
    end
    
    """
        handle_window_resize(this::TextBox)

    Handles window resize events by recalculating the font size and reloading the font.
    This ensures text appears at the correct size after window resizing.

    # Arguments
    - `this::TextBox`: The TextBox object to update
    """
    function UI.handle_window_resize(this::TextBox)
        if this.font != C_NULL
            # Close the current font
            @debug("closing font from handle_window_resize")
            SDL2.TTF_CloseFont(this.font)
            this.font = C_NULL
            # Reload the font with the new scaled size
            UI.load_font(this, joinpath(this.fontPath))
            
            # Rerender the text
            UI.rerender_text(this)
        end
    end

    function UI.duplicate(this::TextBox, id::String = JulGame.generate_uuid())
        newTextBox = TextBox(this.text; 
        id=id, 
        name=this.name, 
        anchor=this.anchor.current_state,
        anchorOffset=this.anchorOffset, 
        isWorldEntity=this.isWorldEntity, 
        layer=this.layer,
        position=this.position, 
        clickEvents=this.clickEvents,
        hoverEnterEvents=this.hoverEnterEvents,
        hoverExitEvents=this.hoverExitEvents,
        isActive=this.isActive,
        persistentBetweenScenes=this.persistentBetweenScenes,
        color=this.color, 
        fontPath=this.fontPath, 
        fontSize=this.fontSize, 
        maxLineWidth=this.maxLineWidth, 
        wrapWords=this.wrapWords,
        parent=this.parent
    )
        UI.initialize(newTextBox)
        push!(MAIN.scene.uiElements, newTextBox)
        return newTextBox
    end
end
