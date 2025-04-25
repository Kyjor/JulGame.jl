module ImmediateUIModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    using ..UI.TextBoxModule
    using ..UI.ScreenButtonModule
    using ..UI.RectangleModule
    using ..UI.LineModule
    using ..UI.CircleModule
    using ..UI.ProgressBarModule
    import ..UI

    export immediate_text, immediate_button, immediate_rect, immediate_line, immediate_circle, immediate_progress_bar, render_all_immediate_components, cleanup_all_immediate_components

    # Dictionary to store active immediate UI components by their id and type
    const IMMEDIATE_UI_CACHE = Dict{String, Any}()
    
    # Stores the last update timestamp for each component
    const IMMEDIATE_UI_TIMESTAMPS = Dict{String, UInt64}()
    
    # Lifetime in milliseconds before an unused immediate component is removed (default: 5 seconds)
    const DEFAULT_LIFETIME = 1000

    """
    immediate_text(id::String, text::String; 
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
        fontPath::String = "Default", 
        fontSize::Int = 16, 
        maxLineWidth::Int=0, 
        wrapWords::Bool=true,
        lifetime::Int=DEFAULT_LIFETIME)

    Creates or updates a text component that will be rendered on the screen. This can be called once (short-lived text) or be placed in an update loop for continuous rendering.
    
    # Arguments
    - `id::String`: Unique identifier for this immediate component
    - `text::String`: The text to display
    - `name::String`: Name of the text box
    - `anchor::Symbol`: Anchor point for positioning (:center, :top, :bottom, :left, :right, :topLeft, :topRight, :bottomLeft, :bottomRight)
    - `anchorOffset::Math.Vector2`: Offset from the anchor point
    - `isWorldEntity::Bool`: Whether this text should be positioned in world space
    - `layer::Int`: Rendering layer (higher values render on top)
    - `position::Math.Vector2`: Position of the text
    - `clickEvents::Vector{Function}`: Functions to call when clicked
    - `hoverEnterEvents::Vector{Function}`: Functions to call when hover starts
    - `hoverExitEvents::Vector{Function}`: Functions to call when hover ends
    - `isActive::Bool`: Whether the text is active/visible
    - `persistentBetweenScenes::Bool`: Whether the text persists between scene changes
    - `color::NTuple{4, Int}`: Color of the text (r,g,b,a)
    - `fontPath::String`: Path to the font file
    - `fontSize::Int`: Size of the font
    - `maxLineWidth::Int`: Maximum width before text wrapping (0 for no wrapping)
    - `wrapWords::Bool`: Whether to wrap at word boundaries (true) or characters (false)
    - `lifetime::Int`: How long the component should persist without updates (ms)
    
    # Returns
    The TextBox object
    """
    function immediate_text(id::String, text::String = "TextBox"; 
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
        fontPath::String = "Default", 
        fontSize::Int = 16, 
        maxLineWidth::Int=0, 
        wrapWords::Bool=true,
        lifetime::Int=DEFAULT_LIFETIME,
        parent::Union{UI.UIElement, Nothing}=nothing,
    )
        
        # Generate a composite ID that includes the component type
        composite_id = "text_$(id)"
        
        # Update timestamp
        IMMEDIATE_UI_TIMESTAMPS[composite_id] = SDL2.SDL_GetTicks()
        
        if haskey(IMMEDIATE_UI_CACHE, composite_id)
            # Update existing text component
            textBox = IMMEDIATE_UI_CACHE[composite_id].element
            
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
                textBox.fontSize = fontSize
                needsUpdate = true
            end
            
            if textBox.fontPath != fontPath
                textBox.fontPath = fontPath
                needsUpdate = true
            end
            
            if textBox.anchor.current_state != anchor
                textBox.anchor.current_state = anchor
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
            
            if textBox.color != color
                textBox.color = color
                needsUpdate = true
            end

            if textBox.isActive != isActive
                textBox.isActive = isActive
                needsUpdate = true
            end
            
            if textBox.layer != layer
                textBox.layer = layer
                needsUpdate = true
            end
            
            if textBox.maxLineWidth != maxLineWidth
                textBox.maxLineWidth = maxLineWidth
                needsUpdate = true
            end
            
            if textBox.wrapWords != wrapWords
                textBox.wrapWords = wrapWords
                needsUpdate = true
            end

            if textBox.parent != parent
                textBox.parent = parent
                needsUpdate = true
            end 
            
            if needsUpdate
                # Reload font and regenerate texture
                if textBox.fontSize != fontSize
                    UI.load_font(textBox, joinpath(BasePath, "assets", "fonts"), fontPath)
                end
                UI.rerender_text(textBox)
            end
            
            # Ensure the component is in the scene's uiElements
            if !(textBox in MAIN.scene.uiElements)
                push!(MAIN.scene.uiElements, textBox)
            end

            # if doesn't have click events, add click events 
            # if !contains(textBox.clickEvents, clickEvents)
            #     for event in clickEvents
            #         UI.add_click_event(textBox, event)
            #     end
            # end
            
            return textBox
        else
            @debug "creating new text component with id $(composite_id): $(length(IMMEDIATE_UI_CACHE))"
            # Create new text component
            textBox = TextBox(text; 
                id=id,
                name=name,
                anchor=anchor,
                anchorOffset=anchorOffset,
                isWorldEntity=isWorldEntity,
                layer=layer,
                position=position,
                clickEvents=clickEvents,
                hoverEnterEvents=hoverEnterEvents,
                hoverExitEvents=hoverExitEvents,
                isActive=isActive,
                persistentBetweenScenes=persistentBetweenScenes,
                color=color,
                fontPath=fontPath,
                fontSize=fontSize,
                maxLineWidth=maxLineWidth,
                wrapWords=wrapWords,
                parent=parent)
            
            # Store in cache
            IMMEDIATE_UI_CACHE[composite_id] = (element = textBox, lifetime = lifetime)
            
            # Add to scene's uiElements
            push!(MAIN.scene.uiElements, textBox)

            if textBox.anchor.current_state != :none
                UI.align_to_anchor(textBox)
            end
            
            return textBox
        end
    end

    """
    immediate_button(id::String, text::String, fontPath::String, fontSize::Int, position::Math.Vector2,
                     width::Int, height::Int, isCentered::Bool=true, callback::Function=() -> nothing;
                     buttonUpPath::String="", buttonDownPath::String="", textOffset::Math.Vector2=Math.Vector2(0,0),
                     alpha::Int=255, layer::Int=0, lifetime::Int=DEFAULT_LIFETIME)

    Creates or updates an immediate button component.
    
    # Arguments
    - `id::String`: Unique identifier for this immediate component
    - `text::String`: The text label on the button
    - `fontPath::String`: Path to the font file
    - `fontSize::Int`: Size of the font
    - `position::Math.Vector2`: Position of the button
    - `width::Int`: Width of the button
    - `height::Int`: Height of the button
    - `isCentered::Bool`: Whether the button is centered at its position
    - `callback::Function`: Function to call when the button is clicked
    - `buttonUpPath::String`: Image for button normal state (optional)
    - `buttonDownPath::String`: Image for button pressed state (optional)
    - `textOffset::Math.Vector2`: Offset for positioning the text
    - `alpha::Int`: Transparency (0-255)
    - `layer::Int`: Rendering layer (higher values render on top)
    - `lifetime::Int`: How long the component should persist without updates (ms)
    
    # Returns
    The ScreenButton object
    """
    function immediate_button(id::String, text::String, fontPath::String, fontSize::Int, position::Math.Vector2,
                             width::Int, height::Int, isCentered::Bool=true, callback::Function=() -> nothing;
                             buttonUpPath::String="", buttonDownPath::String="", textOffset::Math.Vector2=Math.Vector2(0,0),
                             alpha::Int=255, isActive::Bool=true, layer::Int=0, lifetime::Int=DEFAULT_LIFETIME)
        
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
            button = IMMEDIATE_UI_CACHE[composite_id].element
            
            # Only update if something has changed
            needsReinitialize = false
            
            if button.text != text
                # Use the update_button_text function which handles rerendering
                UI.update_button_text(button, text)
            end
            
            if button.position != adjusted_position
                button.position = adjusted_position
            end
            
            if button.size != size
                button.size = size
                # If the size changed, we need to recenter the text
                center_text_on_button(button)
            end
            
            if button.fontSize != fontSize
                button.fontSize = fontSize
                needsReinitialize = true
            end
            
            if button.textOffset != textOffset
                button.textOffset = textOffset
            end
            
            if button.color[4] != alpha
                JulGame.UI.set_color(button; a=alpha)
            end

            if button.isActive != isActive
                button.isActive = isActive
            end
            
            if button.layer != layer
                button.layer = layer
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
            end
            
            if needsReinitialize
                # Reinitialize button with new sprites and text
                UI.initialize(button)
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
                                 fontPath, text, textOffset; id=id, fontSize=fontSize, layer=layer)
            
            # Set button properties
            JulGame.UI.set_color(button; a=alpha)
            button.persistentBetweenScenes = false
            UI.add_click_event(button, callback)
            
            # Initialize the button to load sprites
            UI.initialize(button)
            
            # Store in cache
            IMMEDIATE_UI_CACHE[composite_id] = (element = button, lifetime = lifetime)
            
            # Add to scene's uiElements
            push!(MAIN.scene.uiElements, button)
           #=  if textBox.anchor.current_state != :none
                UI.align_to_anchor(button)
            end =#

            return button
        end
    end

    """
    immediate_rect(id::String, x::Int, y::Int, width::Int, height::Int, 
                  color::NTuple{4, Int}=(255, 255, 255, 255),
                  borderWidth::Int=0, fillMode::Bool=true;
                  isWorldEntity::Bool=false, borderColor::NTuple{4, Int}=(0, 0, 0, 255),
                  borderRadius::Int=0, layer::Int=0, lifetime::Int=DEFAULT_LIFETIME)

    Creates or updates an immediate rectangle component.
    
    # Arguments
    - `id::String`: Unique identifier for this immediate component
    - `x::Int`: X position of the rectangle
    - `y::Int`: Y position of the rectangle
    - `width::Int`: Width of the rectangle
    - `height::Int`: Height of the rectangle
    - `color::Tuple{<:Int, <:Int, <:Int, <:Int}`: Color of the rectangle (RGBA)
    - `borderWidth::<:Int`: Width of the border (0 for no border)
    - `fillMode::Bool`: Whether to fill the rectangle or just draw the outline
    - `isWorldEntity::Bool`: Whether this rectangle should be positioned in world space
    - `borderColor::Tuple{<:Int, <:Int, <:Int, <:Int}`: Color of the border (RGBA)
    - `borderRadius::<:Int`: Radius of the rounded corners (0 for sharp corners)
    - `layer::<:Int`: Rendering layer (higher values render on top)
    - `lifetime::Int`: How long the component should persist without updates (ms)
    
    # Returns
    The Rectangle object
    """
    function immediate_rect(
        id::String;
        name::String = "Rectangle",
        anchor::Symbol = :none,
        anchorOffset::Math.Vector2 = Math.Vector2(0, 0),
        isWorldEntity::Bool=false, 
        layer::Int=0,
        position::Math.Vector2 = Math.Vector2(0, 0), 
        clickEvents::Vector{Function} = Function[],
        hoverEnterEvents::Vector{Function} = Function[],
        hoverExitEvents::Vector{Function} = Function[],
        isActive::Bool=true,
        persistentBetweenScenes::Bool=false,
        color::NTuple{4, Int}=(255, 255, 255, 255),
        borderWidth::Int=0, 
        fillMode::Bool=true,
        borderColor::NTuple{4, Int}=(0, 0, 0, 255),
        borderRadius::Int=0, 
        lifetime::Int=DEFAULT_LIFETIME,
        parent::Union{UI.UIElement, Nothing}=nothing,
        size::Math.Vector2 = Math.Vector2(1, 1)
    )
        
        # Convert colors to Int32 tuples
        color = (color[1],
                color[2],
                color[3],
                color[4])
        
        borderColor = (borderColor[1],
                      borderColor[2],
                      borderColor[3],
                      borderColor[4])
        
        # Convert other integer parameters
        borderWidth = borderWidth
        borderRadius = borderRadius
        layer = layer
        
        # Generate a composite ID that includes the component type
        composite_id = "rect_$(id)"
        
        # Update timestamp
        IMMEDIATE_UI_TIMESTAMPS[composite_id] = SDL2.SDL_GetTicks()
        
        if haskey(IMMEDIATE_UI_CACHE, composite_id)
            # Update existing rect component
            rect = IMMEDIATE_UI_CACHE[composite_id].element
            
            # Only update if something has changed
            needsUpdate = false
            
            if rect.position != position
                rect.position = position
                needsUpdate = true
            end
            
            if rect.size != size
                rect.size = size
                needsUpdate = true
            end
            
            if rect.color != color
                rect.color = color
                JulGame.UI.set_color(rect; a=color[4])
                needsUpdate = true
            end
            
            if rect.borderWidth != borderWidth
                rect.borderWidth = borderWidth
                needsUpdate = true
            end
            
            if rect.fillMode != fillMode
                rect.fillMode = fillMode
                needsUpdate = true
            end
            
            if rect.isWorldEntity != isWorldEntity
                rect.isWorldEntity = isWorldEntity
                needsUpdate = true
            end
            
            if rect.borderColor != borderColor
                rect.borderColor = borderColor
                needsUpdate = true
            end
            
            if rect.borderRadius != borderRadius
                rect.borderRadius = borderRadius
                needsUpdate = true
            end

            if rect.isActive != isActive
                rect.isActive = isActive
                needsUpdate = true
            end
            
            if rect.layer != layer
                rect.layer = layer
                needsUpdate = true
            end
            
            if rect.parent != parent
                rect.parent = parent
                needsUpdate = true
            end

            if rect.name != name
                rect.name = name
                needsUpdate = true
            end

            if rect.anchor.current_state != anchor
                println("anchor: $anchor")
                rect.anchor.current_state = anchor
                needsUpdate = true
            end
            
            if rect.anchorOffset != anchorOffset
                rect.anchorOffset = anchorOffset
                needsUpdate = true
            end

            if rect.position != position
                rect.position = position
                needsUpdate = true
            end

            if rect.size != size
                rect.size = size
                needsUpdate = true
            end

            if needsUpdate
                UI.align_to_anchor(rect)
            end

            # Ensure the component is in the scene's uiElements
            if !(rect in MAIN.scene.uiElements)
                push!(MAIN.scene.uiElements, rect)
            end

           # if doesn't have click events, add click events 
        #    if !contains(rect.clickEvents, clickEvents)
        #         for event in clickEvents
        #             UI.add_click_event(rect, event)
        #         end
        #     end
            
            return rect
        else
            # Create new rect component
            rect = Rectangle(;
                id="immediate_$(id)", 
                name=name,
                anchor=anchor,
                anchorOffset=anchorOffset,
                isWorldEntity=isWorldEntity, 
                layer=layer,
                position=position, 
                color=color, 
                fillMode=fillMode,
                borderRadius=borderRadius, 
                borderWidth=borderWidth, 
                borderColor=borderColor,
                isActive=isActive,
                persistentBetweenScenes=persistentBetweenScenes,
                clickEvents=clickEvents,
                hoverEnterEvents=hoverEnterEvents,
                hoverExitEvents=hoverExitEvents,
                parent=parent,
                size=size
            )
            
            rect.isActive = isActive
            rect.persistentBetweenScenes = false
            
            # Store in cache
            IMMEDIATE_UI_CACHE[composite_id] = (element = rect, lifetime = lifetime)
            
            # Add to scene's uiElements
            push!(MAIN.scene.uiElements, rect)

            if rect.anchor.current_state != :none
                UI.align_to_anchor(rect)
            end

            return rect
        end
    end

    """
    immediate_line(id::String, x1::Int, y1::Int, x2::Int, y2::Int, 
                  color::NTuple{4, Int}=(255, 255, 255, 255),
                  thickness::Int=1; isWorldEntity::Bool=false, isActive::Bool=true, 
                  layer::Int=0, lifetime::Int=DEFAULT_LIFETIME)

    Creates or updates an immediate line component.
    
    # Arguments
    - `id::String`: Unique identifier for this immediate component
    - `x1::Int`: X position of the start point
    - `y1::Int`: Y position of the start point
    - `x2::Int`: X position of the end point
    - `y2::Int`: Y position of the end point
    - `color::Tuple{<:Int, <:Int, <:Int, <:Int}`: Color of the line (RGBA)
    - `thickness::<:Int`: Thickness of the line in pixels
    - `isWorldEntity::Bool`: Whether this line should be positioned in world space
    - `layer::<:Int`: Rendering layer (higher values render on top)
    - `lifetime::Int`: How long the component should persist without updates (ms)
    
    # Returns
    The Line object
    """
    function immediate_line(id::String, x1::Int, y1::Int, x2::Int, y2::Int,
                           color::NTuple{4, Int}=(255, 255, 255, 255),
                           thickness::Int=1; isWorldEntity::Bool=false, isActive::Bool=true, 
                           layer::Int=0, lifetime::Int=DEFAULT_LIFETIME)
        
        # Convert color to Int32 tuple
        color = (color[1],
                color[2],
                color[3],
                color[4])
        
        # Convert other integer parameters
        thickness = thickness
        layer = layer
        
        # Generate a composite ID that includes the component type
        composite_id = "line_$(id)"
        
        # Update timestamp
        IMMEDIATE_UI_TIMESTAMPS[composite_id] = SDL2.SDL_GetTicks()
        
        startPoint = Math.Vector2(x1, y1)
        endPoint = Math.Vector2(x2, y2)
        
        if haskey(IMMEDIATE_UI_CACHE, composite_id)
            # Update existing line component
            line = IMMEDIATE_UI_CACHE[composite_id].element
            
            # Only update if something has changed
            needsUpdate = false
            
            if line.startPoint != startPoint
                line.startPoint = startPoint
                needsUpdate = true
            end
            
            if line.endPoint != endPoint
                line.endPoint = endPoint
                needsUpdate = true
            end
            
            if line.color != color
                line.color = color
                JulGame.UI.set_color(line; a=color[4])
                needsUpdate = true
            end
            
            if line.thickness != thickness
                line.thickness = thickness
                needsUpdate = true
            end
            
            if line.isWorldEntity != isWorldEntity
                line.isWorldEntity = isWorldEntity
                needsUpdate = true
            end

            if line.isActive != isActive
                line.isActive = isActive
                needsUpdate = true
            end
            
            if line.layer != layer
                line.layer = layer
                needsUpdate = true
            end
            
            # Ensure the component is in the scene's uiElements
            if !(line in MAIN.scene.uiElements)
                push!(MAIN.scene.uiElements, line)
            end
            
            return line
        else
            # Create new line component
            line = Line("immediate_$(id)", startPoint, endPoint, color, thickness; 
                        id=id, isWorldEntity=isWorldEntity, layer=layer)
            
            line.isActive = isActive
            line.persistentBetweenScenes = false
            
            # Store in cache
            IMMEDIATE_UI_CACHE[composite_id] = (element = line, lifetime = lifetime)
            
            # Add to scene's uiElements
            push!(MAIN.scene.uiElements, line)
            
            return line
        end
    end

    """
    immediate_circle(id::String, x::Int, y::Int, radius::Int,
                    color::NTuple{4, Int}=(255, 255, 255, 255),
                    fillMode::Bool=true; isWorldEntity::Bool=false, 
                    borderWidth::Int=0, borderColor::NTuple{4, Int}=(0, 0, 0, 255),
                    layer::Int=0, lifetime::Int=DEFAULT_LIFETIME)

    Creates or updates an immediate circle component.
    
    # Arguments
    - `id::String`: Unique identifier for this immediate component
    - `x::Int`: X position of the circle center
    - `y::Int`: Y position of the circle center
    - `radius::Int`: Radius of the circle
    - `color::Tuple{<:Int, <:Int, <:Int, <:Int}`: Color of the circle (RGBA)
    - `fillMode::Bool`: Whether to fill the circle or just draw the outline
    - `isWorldEntity::Bool`: Whether this circle should be positioned in world space
    - `borderWidth::<:Int`: Width of the border (0 for no border)
    - `borderColor::Tuple{<:Int, <:Int, <:Int, <:Int}`: Color of the border (RGBA)
    - `layer::<:Int`: Rendering layer (higher values render on top)
    - `lifetime::Int`: How long the component should persist without updates (ms)
    
    # Returns
    The Circle object
    """
    function immediate_circle(id::String, x::Int, y::Int, radius::Int,
                             color::NTuple{4, Int}=(255, 255, 255, 255),
                             fillMode::Bool=true; isWorldEntity::Bool=false, 
                             borderWidth::Int=0, borderColor::NTuple{4, Int}=(0, 0, 0, 255),
                             isActive::Bool=true, layer::Int=0, lifetime::Int=DEFAULT_LIFETIME)
        
        # Convert colors to Int32 tuples
        color = (color[1],
                color[2],
                color[3],
                color[4])
        
        borderColor = (borderColor[1],
                      borderColor[2],
                      borderColor[3],
                      borderColor[4])
        
        # Convert other integer parameters
        borderWidth = borderWidth
        layer = layer

        # Generate a composite ID that includes the component type
        composite_id = "circle_$(id)"
        
        # Update timestamp
        IMMEDIATE_UI_TIMESTAMPS[composite_id] = SDL2.SDL_GetTicks()
        
        center = Math.Vector2(x, y)
        
        if haskey(IMMEDIATE_UI_CACHE, composite_id)
            # Update existing circle component
            circle = IMMEDIATE_UI_CACHE[composite_id].element
            
            # Only update if something has changed
            needsUpdate = false
            
            if circle.center != center
                circle.center = center
                needsUpdate = true
            end
            
            if circle.radius != radius
                circle.radius = radius
                needsUpdate = true
            end
            
            if circle.color != color
                circle.color = color
                JulGame.UI.set_color(circle; a=color[4])
                needsUpdate = true
            end
            
            if circle.fillMode != fillMode
                circle.fillMode = fillMode
                needsUpdate = true
            end
            
            if circle.isWorldEntity != isWorldEntity
                circle.isWorldEntity = isWorldEntity
                needsUpdate = true
            end
            
            if circle.borderWidth != borderWidth
                circle.borderWidth = borderWidth
                needsUpdate = true
            end
            
            if circle.borderColor != borderColor
                circle.borderColor = borderColor
                needsUpdate = true
            end

            if circle.isActive != isActive
                circle.isActive = isActive
                needsUpdate = true
            end
            
            if circle.layer != layer
                circle.layer = layer
                needsUpdate = true
            end
            
            # Ensure the component is in the scene's uiElements
            if !(circle in MAIN.scene.uiElements)
                push!(MAIN.scene.uiElements, circle)
            end
            
            return circle
        else
            # Create new circle component
            circle = Circle("immediate_$(id)", center, radius, color, fillMode; 
                           id=id, isWorldEntity=isWorldEntity, 
                           borderWidth=borderWidth, borderColor=borderColor,
                           layer=layer)
            
            circle.isActive = isActive
            circle.persistentBetweenScenes = false
            
            # Store in cache
            IMMEDIATE_UI_CACHE[composite_id] = (element = circle, lifetime = lifetime)
            
            # Add to scene's uiElements
            push!(MAIN.scene.uiElements, circle)
            
            return circle
        end
    end

    """
    immediate_progress_bar(id::String, x::Int, y::Int, width::Int, height::Int,
                           progress::Int=0.0, 
                           fillColor::NTuple{4, Int}=(0, 120, 215, 255),
                           backgroundColor::NTuple{4, Int}=(230, 230, 230, 255);
                           isWorldEntity::Bool=false,
                           borderWidth::Int=0, 
                           borderColor::NTuple{4, Int}=(200, 200, 200, 255),
                           borderRadius::Int=0,
                           vertical::Bool=false,
                           showBackground::Bool=true,
                           isActive::Bool=true,
                           layer::Int=0,
                           lifetime::Int=DEFAULT_LIFETIME)

    Creates or updates an immediate progress bar component.
    
    # Arguments
    - `id::String`: Unique identifier for this immediate component
    - `x::Int`: X position of the progress bar
    - `y::Int`: Y position of the progress bar
    - `width::Int`: Width of the progress bar
    - `height::Int`: Height of the progress bar
    - `progress::Int`: Progress value (0.0 to 1.0)
    - `fillColor::Tuple{<:Int, <:Int, <:Int, <:Int}`: Color of the fill (RGBA)
    - `backgroundColor::Tuple{<:Int, <:Int, <:Int, <:Int}`: Color of the background (RGBA)
    - `isWorldEntity::Bool`: Whether this progress bar should be positioned in world space
    - `borderWidth::<:Int`: Width of the border (0 for no border)
    - `borderColor::Tuple{<:Int, <:Int, <:Int, <:Int}`: Color of the border (RGBA)
    - `borderRadius::<:Int`: Radius of the border rounded corners (0 for sharp corners)
    - `vertical::Bool`: Whether the progress bar fills vertically instead of horizontally
    - `showBackground::Bool`: Whether to show the background
    - `layer::<:Int`: Rendering layer (higher values render on top)
    - `lifetime::Int`: How long the component should persist without updates (ms)
    
    # Returns
    The ProgressBar object
    """
    function immediate_progress_bar(id::String, x::Int, y::Int, width::Int, height::Int,
                                   progress::Int=0.0, 
                                   fillColor::NTuple{4, Int}=(0, 120, 215, 255),
                                   backgroundColor::NTuple{4, Int}=(230, 230, 230, 255);
                                   isWorldEntity::Bool=false,
                                   borderWidth::Int=0, 
                                   borderColor::NTuple{4, Int}=(200, 200, 200, 255),
                                   borderRadius::Int=0,
                                   vertical::Bool=false,
                                   showBackground::Bool=true,
                                   isActive::Bool=true,
                                   layer::Int=0,
                                   lifetime::Int=DEFAULT_LIFETIME)
        
        # Convert colors to Int32 tuples
        fillColor = (fillColor[1],
                    fillColor[2],
                    fillColor[3],
                    fillColor[4])
        
        backgroundColor = (backgroundColor[1],
                          backgroundColor[2],
                          backgroundColor[3],
                          backgroundColor[4])
        
        borderColor = (borderColor[1],
                      borderColor[2],
                      borderColor[3],
                      borderColor[4])
        
        # Convert other integer parameters
        borderWidth = borderWidth
        borderRadius = borderRadius
        layer = layer

        # Generate a composite ID that includes the component type
        composite_id = "progress_bar_$(id)"
        
        # Update timestamp
        IMMEDIATE_UI_TIMESTAMPS[composite_id] = SDL2.SDL_GetTicks()
        
        position = Math.Vector2(x, y)
        size = Math.Vector2(width, height)
        
        if haskey(IMMEDIATE_UI_CACHE, composite_id)
            # Update existing progress bar component
            progressBar = IMMEDIATE_UI_CACHE[composite_id].element
            
            # Only update if something has changed
            needsUpdate = false
            
            if progressBar.position != position
                progressBar.position = position
                needsUpdate = true
            end
            
            if progressBar.size != size
                progressBar.size = size
                needsUpdate = true
            end
            
            if progressBar.progress != progress
                progressBar.progress = clamp(Float32(progress), 0.0, 1.0)
                needsUpdate = true
            end
            
            if progressBar.fillColor != fillColor
                progressBar.fillColor = fillColor
                JulGame.UI.set_color(progressBar; a=fillColor[4])
                needsUpdate = true
            end
            
            if progressBar.backgroundColor != backgroundColor
                progressBar.backgroundColor = backgroundColor
                needsUpdate = true
            end
            
            if progressBar.isWorldEntity != isWorldEntity
                progressBar.isWorldEntity = isWorldEntity
                needsUpdate = true
            end
            
            if progressBar.borderWidth != borderWidth
                progressBar.borderWidth = borderWidth
                needsUpdate = true
            end
            
            if progressBar.borderRadius != borderRadius
                progressBar.borderRadius = borderRadius
                needsUpdate = true
            end
            
            if progressBar.borderColor != borderColor
                progressBar.borderColor = borderColor
                needsUpdate = true
            end
            
            if progressBar.vertical != vertical
                progressBar.vertical = vertical
                needsUpdate = true
            end
            
            if progressBar.showBackground != showBackground
                progressBar.showBackground = showBackground
                needsUpdate = true
            end

            if progressBar.isActive != isActive
                progressBar.isActive = isActive
                needsUpdate = true
            end
            
            if progressBar.layer != layer
                progressBar.layer = layer
                needsUpdate = true
            end
            
            # Ensure the component is in the scene's uiElements
            if !(progressBar in MAIN.scene.uiElements)
                push!(MAIN.scene.uiElements, progressBar)
            end
            
            return progressBar
        else
            # Create new progress bar component
            progressBar = ProgressBar("immediate_$(id)", position, size, progress; 
                                    id=id, 
                                    fillColor=fillColor,
                                    backgroundColor=backgroundColor,
                                    isWorldEntity=isWorldEntity,
                                    borderWidth=borderWidth,
                                    borderColor=borderColor,
                                    borderRadius=borderRadius,
                                    vertical=vertical,
                                    showBackground=showBackground,
                                    layer=layer)
            
            progressBar.isActive = isActive
            progressBar.persistentBetweenScenes = false
            
            # Store in cache
            IMMEDIATE_UI_CACHE[composite_id] = (element = progressBar, lifetime = lifetime)
            
            # Add to scene's uiElements
            push!(MAIN.scene.uiElements, progressBar)
            
            return progressBar
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
        
        # Sort component IDs by layer before rendering
        component_layers = Dict{String, Int}()
        
        # First pass: collect layers for each component and check expiration
        for (composite_id, component) in IMMEDIATE_UI_CACHE     
            # Check if this component hasn't been used for a while
            if !haskey(IMMEDIATE_UI_TIMESTAMPS, composite_id) || current_time - IMMEDIATE_UI_TIMESTAMPS[composite_id] > component.lifetime
                @info "component $(composite_id) expired from lifetime $(component.lifetime)"
                push!(expired_ids, composite_id)
                continue
            end
            
            # Store the layer for sorting
            component_layers[composite_id] = component.element.layer
        end
        
        # Sort component IDs by layer
        sorted_ids = sort(collect(keys(component_layers)), by = id -> component_layers[id])
        
        # Second pass: render components in layer order
        for id in sorted_ids
            component = IMMEDIATE_UI_CACHE[id].element
            UI.render(component)
        end
        
        # Clean up expired components
        for id in expired_ids
            cleanup_immediate_component(id)
        end
    end

    """
    cleanup_immediate_component(id::String)
    
    Removes an immediate UI component from the cache and cleans up its resources.
    Also removes it from the scene's uiElements array.
    """
    function cleanup_immediate_component(id::String)
        if haskey(IMMEDIATE_UI_CACHE, id)
            component = IMMEDIATE_UI_CACHE[id].element
            
            # Remove from scene's uiElements if present
            if component in MAIN.scene.uiElements
                filter!(x -> x !== component, MAIN.scene.uiElements)
            end
            
            # Clean up component resources using appropriate destroy method
            if component isa TextBox
                UI.destroy(component)
            elseif component isa ScreenButton
                UI.destroy(component)
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

    """
    center_text_on_button(button::ScreenButton)
    
    Centers the text within the button.
    """
    function center_text_on_button(button::ScreenButton)
        # Calculate the position to center the text
        textX = (button.size.x - button.textSize.x) / 2
        textY = (button.size.y - button.textSize.y) / 2
        
        # Update the text offset
        button.textOffset = Math.Vector2(textX, textY)
    end
end 