module ImmediateUIModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    using ..UI.TextBoxModule
    using ..UI.ScreenButtonModule
    import ..UI

    export immediate_text, immediate_button, render_all_immediate_components, cleanup_all_immediate_components

    # Dictionary to store active immediate UI components by their id and type
    const IMMEDIATE_UI_CACHE = Dict{String, Any}()
    
    # Stores the last update timestamp for each component
    const IMMEDIATE_UI_TIMESTAMPS = Dict{String, UInt64}()
    
    # Lifetime in milliseconds before an unused immediate component is removed (default: 5 seconds)
    const DEFAULT_LIFETIME = 5000

    """
    immediate_text(id::String, text::String, fontPath::String, fontSize::Number, position::Math.Vector2, 
                  width::Number=0, height::Number=0, isCenteredX::Bool=false, isCenteredY::Bool=false; 
                  anchorOffset::Math.Vector2=Math.Vector2(0,0), isWorldEntity::Bool=false, alpha::Number=255)

    Creates or updates an immediate text component.
    
    # Arguments
    - `id::String`: Unique identifier for this immediate component
    - `text::String`: The text to display
    - `fontPath::String`: Path to the font file
    - `fontSize::Number`: Size of the font
    - `position::Math.Vector2`: Position of the text
    - `width::Number`: Width of the text box (0 for auto-size)
    - `height::Number`: Height of the text box (0 for auto-size)
    - `isCenteredX::Bool`: Whether to center the text horizontally
    - `isCenteredY::Bool`: Whether to center the text vertically
    - `anchorOffset::Math.Vector2`: Offset from the anchor point
    - `isWorldEntity::Bool`: Whether this text should be positioned in world space
    - `alpha::Number`: Transparency (0-255)
    
    # Returns
    The TextBox object
    """
    function immediate_text(id::String, text::String, fontPath::String, fontSize::Number, 
        position::Math.Vector2, isCenteredX::Bool=false, isCenteredY::Bool=false; 
        anchorOffset::Math.Vector2=Math.Vector2(0,0), isWorldEntity::Bool=false, alpha::Number=255)
        
        # Generate a composite ID that includes the component type
        composite_id = "text_$(id)"
        
        # Update timestamp
        IMMEDIATE_UI_TIMESTAMPS[composite_id] = SDL2.SDL_GetTicks()
        
        if haskey(IMMEDIATE_UI_CACHE, composite_id)
            # Update existing text component
            textBox = IMMEDIATE_UI_CACHE[composite_id]
            
            # Only update if something has changed
            needsUpdate = false
            
            if textBox.text != text
                textBox.text = text
                needsUpdate = true
            end
            
            if textBox.position != position
                textBox.position = position
                needsUpdate = true
            end
            
            if textBox.fontSize != fontSize
                textBox.fontSize = Int32(fontSize)
                needsUpdate = true
            end
            
            if textBox.fontPath != fontPath
                textBox.fontPath = fontPath
                needsUpdate = true
            end
            
            if textBox.isCenteredX != isCenteredX || textBox.isCenteredY != isCenteredY
                textBox.isCenteredX = isCenteredX
                textBox.isCenteredY = isCenteredY
                needsUpdate = true
            end
            
            if textBox.anchorOffset != anchorOffset
                textBox.anchorOffset = anchorOffset
                needsUpdate = true
            end
            
            if textBox.isWorldEntity != isWorldEntity
                textBox.isWorldEntity = isWorldEntity
                needsUpdate = true
            end
            
            if textBox.alpha != alpha
                textBox.alpha = alpha
                needsUpdate = true
            end
            
            if needsUpdate
                # Reload font and regenerate texture
                UI.load_font(textBox, joinpath(BasePath, "assets", "fonts"), fontPath)
                UI.rerender_text(textBox)
                
                if isCenteredX || isCenteredY
                    UI.center_text(textBox)
                end
            end
            
            # Ensure the component is in the scene's uiElements
            if !(textBox in MAIN.scene.uiElements)
                push!(MAIN.scene.uiElements, textBox)
            end
            
            return textBox
        else
            # Create new text component
            textBox = TextBox("immediate_$(id)", fontPath, fontSize, position, text, isCenteredX, isCenteredY; 
                             anchorOffset=anchorOffset, id=id, isWorldEntity=isWorldEntity)
            
            textBox.alpha = alpha
            textBox.persistentBetweenScenes = false
            
            # Store in cache
            IMMEDIATE_UI_CACHE[composite_id] = textBox
            
            # Add to scene's uiElements
            push!(MAIN.scene.uiElements, textBox)
            
            return textBox
        end
    end

    """
    immediate_button(id::String, text::String, fontPath::String, fontSize::Number, position::Math.Vector2,
                     width::Number, height::Number, isCentered::Bool=true, callback::Function=() -> nothing;
                     buttonUpPath::String="", buttonDownPath::String="", textOffset::Math.Vector2=Math.Vector2(0,0),
                     alpha::Number=255)

    Creates or updates an immediate button component.
    
    # Arguments
    - `id::String`: Unique identifier for this immediate component
    - `text::String`: The text label on the button
    - `fontPath::String`: Path to the font file
    - `fontSize::Number`: Size of the font
    - `position::Math.Vector2`: Position of the button
    - `width::Number`: Width of the button
    - `height::Number`: Height of the button
    - `isCentered::Bool`: Whether the button is centered at its position
    - `callback::Function`: Function to call when the button is clicked
    - `buttonUpPath::String`: Image for button normal state (optional)
    - `buttonDownPath::String`: Image for button pressed state (optional)
    - `textOffset::Math.Vector2`: Offset for positioning the text
    - `alpha::Number`: Transparency (0-255)
    
    # Returns
    The ScreenButton object
    """
    function immediate_button(id::String, text::String, fontPath::String, fontSize::Number, position::Math.Vector2,
                             width::Number, height::Number, isCentered::Bool=true, callback::Function=() -> nothing;
                             buttonUpPath::String="", buttonDownPath::String="", textOffset::Math.Vector2=Math.Vector2(0,0),
                             alpha::Number=255)
        
        # Generate a composite ID that includes the component type
        composite_id = "button_$(id)"
        
        # Update timestamp
        IMMEDIATE_UI_TIMESTAMPS[composite_id] = SDL2.SDL_GetTicks()
        
        size = Math.Vector2(width, height)
        
        # Center if requested
        local adjusted_position = position
        if isCentered
            adjusted_position = Math.Vector2(position.x - width/2, position.y - height/2)
        end
        
        if haskey(IMMEDIATE_UI_CACHE, composite_id)
            # Update existing button component
            button = IMMEDIATE_UI_CACHE[composite_id]
            
            # Only update if something has changed
            needsReinitialize = false
            
            if button.text != text
                button.text = text
            end
            
            if button.position != adjusted_position
                button.position = adjusted_position
            end
            
            if button.size != size
                button.size = size
            end
            
            if button.textOffset != textOffset
                button.textOffset = textOffset
            end
            
            if button.alpha != alpha
                button.alpha = alpha
            end
            
            # Check if button sprites need updating
            if (buttonUpPath != "" && button.buttonUpSpritePath != buttonUpPath) ||
               (buttonDownPath != "" && button.buttonDownSpritePath != buttonDownPath)
                
                if buttonUpPath != "" && button.buttonUpSpritePath != buttonUpPath
                    button.buttonUpSpritePath = buttonUpPath
                    needsReinitialize = true
                end
                
                if buttonDownPath != "" && button.buttonDownSpritePath != buttonDownPath
                    button.buttonDownSpritePath = buttonDownPath
                    needsReinitialize = true
                end
                
                if needsReinitialize
                    # Reinitialize button with new sprites
                    UI.initialize(button)
                end
            end
            
            # Update click handler
            if !isempty(button.clickEvents)
                button.clickEvents[1] = callback
            else
                UI.add_click_event(button, callback)
            end
            
            # Ensure the component is in the scene's uiElements
            if !(button in MAIN.scene.uiElements)
                push!(MAIN.scene.uiElements, button)
            end
            
            return button
        else
            # Use default button images if not provided
            if buttonUpPath == ""
                buttonUpPath = "ButtonUp.png" # Default button up image
            end
            
            if buttonDownPath == ""
                buttonDownPath = "ButtonDown.png" # Default button down image
            end
            
            # Create new button component
            button = ScreenButton("immediate_$(id)", buttonUpPath, buttonDownPath, size, adjusted_position, 
                                 fontPath, text, textOffset; id=id)
            
            # Set button properties
            button.alpha = alpha
            button.persistentBetweenScenes = false
            UI.add_click_event(button, callback)
            
            # Initialize the button to load sprites
            UI.initialize(button)
            
            # Store in cache
            IMMEDIATE_UI_CACHE[composite_id] = button
            
            # Add to scene's uiElements
            push!(MAIN.scene.uiElements, button)
            
            return button
        end
    end

    """
    render_all_immediate_components(debug::Bool=false)
    
    Renders all active immediate UI components.
    Should be called once per frame in the main render loop.
    Also handles cleanup of unused components based on their last update time.
    
    # Arguments
    - `debug::Bool`: Whether to draw debug visualizations
    """
    function render_all_immediate_components()
        current_time = SDL2.SDL_GetTicks()
        expired_ids = String[]
        
        # Check for expired components and render active ones
        for (id, component) in IMMEDIATE_UI_CACHE
            # Skip if the component is not properly initialized
            if !isdefined(component, :isActive) || component === nothing
                push!(expired_ids, id)
                continue
            end
            
            # Check if this component hasn't been used for a while
            if !haskey(IMMEDIATE_UI_TIMESTAMPS, id) || current_time - IMMEDIATE_UI_TIMESTAMPS[id] > DEFAULT_LIFETIME
                push!(expired_ids, id)
                continue
            end
            
            # Skip inactive components
            if isdefined(component, :isActive) && !component.isActive
                continue
            end
            
            # Render the component based on its type
            if component isa TextBox
                UI.render(component)
            elseif component isa ScreenButton
                UI.render(component)
            end
        end
        
        # Clean up expired components
        for id in expired_ids
            cleanup_immediate_component(id)
        end
    end

    """
    cleanup_immediate_component(id::String)
    
    Removes an immediate UI component from the cache and cleans up its resources.
    """
    function cleanup_immediate_component(id::String)
        if haskey(IMMEDIATE_UI_CACHE, id)
            component = IMMEDIATE_UI_CACHE[id]
            
            # Remove from scene's uiElements if present
            if component in MAIN.scene.uiElements
                filter!(x -> x !== component, MAIN.scene.uiElements)
            end
            
            # Clean up component resources
            if component isa TextBox
                if isdefined(component, :texture) && component.texture !== nothing
                    SDL2.SDL_DestroyTexture(component.texture)
                end
                if isdefined(component, :font) && component.font !== nothing
                    TTF_CloseFont(component.font)
                end
            elseif component isa ScreenButton
                if isdefined(component, :buttonUpTexture) && component.buttonUpTexture !== nothing
                    SDL2.SDL_DestroyTexture(component.buttonUpTexture)
                end
                if isdefined(component, :buttonDownTexture) && component.buttonDownTexture !== nothing
                    SDL2.SDL_DestroyTexture(component.buttonDownTexture)
                end
                if isdefined(component, :font) && component.font !== nothing
                    TTF_CloseFont(component.font)
                end
            end
            
            # Remove from cache
            delete!(IMMEDIATE_UI_CACHE, id)
            delete!(IMMEDIATE_UI_TIMESTAMPS, id)
        end
    end

    """
    cleanup_all_immediate_components()
    
    Cleans up all immediate UI components.
    Useful when changing scenes or shutting down the game.
    """
    function cleanup_all_immediate_components()
        # Get all IDs to avoid modifying the dict during iteration
        ids = collect(keys(IMMEDIATE_UI_CACHE))
        
        for id in ids
            cleanup_immediate_component(id)
        end
        
        # Clear the dictionaries
        empty!(IMMEDIATE_UI_CACHE)
        empty!(IMMEDIATE_UI_TIMESTAMPS)
    end
end 