module ScreenButtonModule    
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI

    export ScreenButton
    mutable struct ScreenButton
        color::NTuple{4, Int}
        clickEvents::Vector{Function}
        currentTexture
        buttonDownSprite
        buttonDownSpritePath::String
        buttonDownTexture
        #TODO: add buttonHoverSprite/Color Mod 
        buttonUpSprite
        buttonUpSpritePath::String
        buttonUpTexture
        fontPath::Union{String, Ptr{Nothing}}
        fontSize::Int
        id::String
        isActive::Bool
        isHovered::Bool
        isInitialized::Bool
        layer::Int
        name::String
        persistentBetweenScenes::Bool
        position::Math.Vector2
        size::Math.Vector2
        text::String
        textOffset::Math.Vector2
        textSize::Math.Vector2
        textTexture

        function ScreenButton(name::String, buttonUpSpritePath::String, buttonDownSpritePath::String, size::Math.Vector2, position::Math.Vector2, fontPath::Union{String, Ptr{Nothing}} = C_NULL, text::String="", textOffset::Math.Vector2=Math.Vector2(0,0); color::NTuple{4, Int}=(255, 255, 255, 255), id::String=JulGame.generate_uuid(), fontSize::Int=24, layer::Int=0)
            this = new()
            
            this.buttonDownSpritePath = buttonDownSpritePath
            this.buttonUpSpritePath = buttonUpSpritePath
            this.buttonDownSprite = load_image_sdl(joinpath(JulGame.BasePath, "assets", "images"), buttonDownSpritePath)
            this.buttonUpSprite = load_image_sdl(joinpath(JulGame.BasePath, "assets", "images"), buttonUpSpritePath)
            # TODO: if buttonUp/DownSpritePath is not found, use a default sprite

            this.clickEvents = []
            this.currentTexture = C_NULL
            this.fontSize = fontSize
            this.id = id
            this.size = size
            this.fontPath = fontPath
            this.name = name
            this.position = position
            this.text = text
            this.textOffset = textOffset
            this.textTexture = C_NULL
            this.textSize = Math.Vector2(0, 0)
            this.isInitialized = false
            this.persistentBetweenScenes = false
            this.isHovered = false
            this.isActive = true
            this.layer = layer
            this.color = color
            # If the textOffset is at (0,0), we'll consider it as "should center text"
            # This ensures text is centered by default if no explicit offset is provided
            if this.textOffset == Math.Vector2(0, 0) && this.text != ""
                # Even though we don't have the text size yet, we'll mark it for centering
                # The actual centering will happen in UI.initialize
                this.textOffset = Math.Vector2(-1, -1)  # Special value to indicate centering is needed
            end

            return this
        end
    end

    function UI.render(this::ScreenButton)
        if !this.isInitialized
            UI.initialize(this)
        end

        if !this.isActive
            return
        end

        if this.currentTexture == C_NULL || 
            this.currentTexture === nothing
            return
        end

        if this.currentTexture == this.buttonDownTexture && !this.isHovered
            this.currentTexture = this.buttonUpTexture
        end
        
        @assert SDL2.SDL_RenderCopyExF(
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
            this.currentTexture, 
            C_NULL, 
            Ref(SDL2.SDL_FRect(this.position.x, this.position.y, this.size.x,this.size.y)), 
            0.0, 
            C_NULL, 
            SDL2.SDL_FLIP_NONE) == 0 "error rendering image: $(unsafe_string(SDL2.SDL_GetError()))"

        # Render the text if it exists
        if this.textTexture != C_NULL && this.text != ""
            center_text_on_button(this)
            # Position the text exactly in the center of the button
            text_x = this.position.x + this.textOffset.x
            text_y = this.position.y + this.textOffset.y
            
            # Ensure sizes and positions are precise
            rect = SDL2.SDL_FRect(
                Float32(text_x),
                Float32(text_y),
                Float32(this.textSize.x),
                Float32(this.textSize.y)
            )
            
            @assert SDL2.SDL_RenderCopyF(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
                this.textTexture, 
                C_NULL, 
                Ref(rect)
            ) == 0 "error rendering button text: $(unsafe_string(SDL2.SDL_GetError()))"
        end
    end

    function UI.initialize(this::ScreenButton)
        this.buttonDownTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.buttonDownSprite)
        this.buttonUpTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.buttonUpSprite)
        this.currentTexture = this.buttonUpTexture

        # Initialize text if a font path is provided and text is not empty
        if this.fontPath != C_NULL && this.text != ""
            # Load the font using the cache
            font = load_font_sdl(joinpath(JulGame.BasePath, "assets", "fonts"), this.fontPath, this.fontSize)
            
            if font != C_NULL
                # Render the text
                textSurface = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, font, this.text, SDL2.SDL_Color(255, 255, 255, 255))
                
                if textSurface != C_NULL
                    # Get the size of the rendered text
                    surface = unsafe_wrap(Array, textSurface, 10; own = false)
                    width = Float32(surface[1].w)
                    height = Float32(surface[1].h)
                    this.textSize = Math.Vector2(width, height)
                    
                    # Debug the exact text dimensions
                    #println("Text dimensions for '$(this.text)': $(width)x$(height)")
                    
                    # Create texture from surface
                    this.textTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, textSurface)
                    
                    # Always center the text by default
                    center_text_on_button(this)
                    
                    # Free the surface
                    SDL2.SDL_FreeSurface(textSurface)
                end
                
                # Close the font
                SDL2.TTF_CloseFont(font)
            end
        end
        
        this.isInitialized = true
    end

    """
    center_text_on_button(button::ScreenButton)
    
    Centers the text within the button.
    """
    function center_text_on_button(button::ScreenButton)
        # Reset any previous offset settings
        if button.textSize.x == 0 || button.textSize.y == 0
            # If text size isn't set yet, just use 0,0 offset
            button.textOffset = Math.Vector2(0, 0)
            return
        end
        
        # Calculate the position to center the text
        # Make sure we're using exact calculations with floats
        button_width = Float32(button.size.x)
        button_height = Float32(button.size.y)
        text_width = Float32(button.textSize.x)
        text_height = Float32(button.textSize.y)
        
        # Calculate center position with floating-point precision
        textX = (button_width - text_width) / 2
        textY = (button_height - text_height) / 2
        
        # Debug information
        #println("Button: $(button.name), Size: $(button_width)x$(button_height), TextSize: $(text_width)x$(text_height)")
        #println("Calculated offsets - X: $textX, Y: $textY")
        
        # Update the text offset with precise floating-point coordinates
        button.textOffset = Math.Vector2(textX, textY)
    end

    function UI.load_button_sprite_editor(this::ScreenButton, path::String, up::Bool)
        sprite = load_image_sdl(joinpath(JulGame.BasePath, "assets", "images"), path)
        texture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, sprite)
        if up
            this.buttonUpSpritePath = path
            this.buttonUpSprite = sprite
            this.buttonUpTexture = texture
        else
            this.buttonDownSpritePath = path
            this.buttonDownSprite = sprite
            this.buttonDownTexture = texture
        end

        this.currentTexture = texture
    end

    function UI.set_color(this::ScreenButton; r::Int=255, g::Int=255, b::Int=255, a::Int=255)
        this.color = (r%256, g%256, b%256, a%256)
    end

    function load_image_sdl(fullPath::String, imagePath::String)
        if haskey(JulGame.IMAGE_CACHE, get_comma_separated_path(imagePath))
            raw_data = JulGame.IMAGE_CACHE[get_comma_separated_path(imagePath)]
            rw = SDL2.SDL_RWFromConstMem(pointer(raw_data), length(raw_data))
            if rw != C_NULL
                @debug("loading image at $(imagePath) from cache")
                @debug("comma separated path: ", get_comma_separated_path(imagePath))
                return SDL2.IMG_Load_RW(rw, 1)
            end
        end
        @debug "Loading image from disk, there are $(length(JulGame.IMAGE_CACHE)) images in cache"

        return CallSDLFunction(SDL2.IMG_Load, joinpath(fullPath, imagePath))
    end

    function get_comma_separated_path(path::String)
        # Normalize the path to use forward slashes
        normalized_path = replace(path, '\\' => '/')
        
        # Split the path into components
        parts = split(normalized_path, '/')
        
        result = join(parts[1:end], ",")
    
        return result  
    end

    function UI.add_click_event(this::ScreenButton, event)
        push!(this.clickEvents, event)
    end

    function UI.handle_event(this::ScreenButton, evt, x, y)
        if evt.type == evt.type == SDL2.SDL_MOUSEBUTTONDOWN
        this.currentTexture = this.buttonDownTexture
        elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
            this.currentTexture = this.buttonUpTexture
            for eventToCall in this.clickEvents
                try
                    Base.invokelatest(eventToCall,(evt = evt, x = x, y = y))
                catch
                    Base.invokelatest(eventToCall)
                end
            end
        elseif evt.type == SDL2.SDL_MOUSEMOTION
            this.isHovered = true
        end 
    end
    
    function UI.destroy(this::ScreenButton)
        if this.buttonDownTexture != C_NULL
            SDL2.SDL_DestroyTexture(this.buttonDownTexture)
        end
        if this.buttonUpTexture != C_NULL
            SDL2.SDL_DestroyTexture(this.buttonUpTexture)
        end
        if this.textTexture != C_NULL
            SDL2.SDL_DestroyTexture(this.textTexture)
        end
        this.buttonDownTexture = C_NULL
        this.buttonUpTexture = C_NULL
        this.textTexture = C_NULL
        this.currentTexture = C_NULL
    end

    """
    UI.update_button_text(button::ScreenButton, new_text::String)
    
    Updates the button's text and rerenders it.
    
    # Arguments
    - `button::ScreenButton`: The button to update
    - `new_text::String`: The new text to display on the button
    
    # Examples
    ```julia
    UI.update_button_text(my_button, "New Text")
    ```
    """
    function UI.update_button_text(this::ScreenButton, new_text::String)
        if this.text == new_text
            return # No change needed
        end
        
        this.text = new_text
        
        # Clean up previous texture if it exists
        if this.textTexture != C_NULL
            SDL2.SDL_DestroyTexture(this.textTexture)
            this.textTexture = C_NULL
        end
        
        # Skip rendering if text is empty or no font
        if this.text == "" || this.fontPath == C_NULL
            return
        end
        
        # Load the font using the cache
        font = load_font_sdl(joinpath(JulGame.BasePath, "assets", "fonts"), this.fontPath, this.fontSize)
        
        if font != C_NULL
            # Render the text
            textSurface = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, font, this.text, SDL2.SDL_Color(255, 255, 255, 255))
            
            if textSurface != C_NULL
                # Get the size of the rendered text
                surface = unsafe_wrap(Array, textSurface, 10; own = false)
                width = Float32(surface[1].w)
                height = Float32(surface[1].h)
                this.textSize = Math.Vector2(width, height)
                
                # Debug the exact text dimensions
                #println("Text dimensions for '$(this.text)': $(width)x$(height)")
                
                # Create texture from surface
                this.textTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, textSurface)
                
                # Always center the text on the button
                center_text_on_button(this)
                
                # Free the surface
                SDL2.SDL_FreeSurface(textSurface)
            end
            
            # Close the font
            SDL2.TTF_CloseFont(font)
        end
    end

    """
    load_font_sdl(basePath::String, fontPath::String, fontSize::Int)
    
    Loads a font from the specified path, using the font cache if available.
    
    # Arguments
    - `basePath::String`: The base path to load the font from
    - `fontPath::String`: The path to the font file
    - `fontSize::Int`: The size of the font
    
    # Returns
    A pointer to the loaded font
    """
    function load_font_sdl(basePath::String, fontPath::String, fontSize::Int)
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
                @debug("loading font from cache for button")
                @debug("comma separated path: ", get_comma_separated_path(fontPath))
                return SDL2.TTF_OpenFontRW(rw, 1, Math.TypeConversions.safe_int32_convert(fontSize))
            end
        end
        @debug "Loading font from disk for button, there are $(length(JulGame.FONT_CACHE)) fonts in cache"
        return CallSDLFunction(SDL2.TTF_OpenFont, joinpath(basePath, fontPath), Math.TypeConversions.safe_int32_convert(fontSize))
    end
end
