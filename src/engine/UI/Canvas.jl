module CanvasModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI

    export Canvas
    export add_child, remove_child, get_children, set_active, is_child_active

    """
    Canvas - A container UI element that can hold other UI elements as children.
    Provides hierarchical organization, anchoring, and collective activation/deactivation.
    """
    mutable struct Canvas <: UI.UIElement
        # Canvas-specific properties
        children::Vector{UI.UIElement}
        isVisible::Bool  # Whether the canvas itself is visible (separate from isActive)
        clipChildren::Bool  # Whether to clip children to canvas bounds
        
        # Canvas constructor
        function Canvas(;
            id::String=JulGame.generate_uuid(),
            name::String="Canvas",
            anchor::Symbol=:none,
            anchorOffset::Math.Vector2=Math.Vector2(0, 0),
            isWorldEntity::Bool=false,
            layer::Int=0,
            position::Math.Vector2=Math.Vector2(0, 0),
            size::Math.Vector2=Math.Vector2(800, 600),
            clickEvent::Union{Function, Nothing}=nothing,
            hoverEnterEvent::Union{Function, Nothing}=nothing,
            hoverExitEvent::Union{Function, Nothing}=nothing,
            isActive::Bool=true,
            persistentBetweenScenes::Bool=false,
            color::NTuple{4, Int}=(255, 255, 255, 255),
            isVisible::Bool=true,
            clipChildren::Bool=false,
            parent::Union{UI.UIElement, Nothing, Any}=nothing,
            rotation::Float64=0.0
        )
            this = new()
            
            # Initialize children collection
            this.children = UI.UIElement[]
            
            # Canvas-specific properties
            this.isVisible = isVisible
            this.clipChildren = clipChildren
            
            # Set up anchor enum
            this.anchor = JulGame.Enum{Any}(
                :center,
                :top,
                :bottom,
                :left,
                :right,
                :topLeft,
                :topRight,
                :bottomLeft,
                :bottomRight,
                :centerLeft,
                :centerRight,
                :centerTop,
                :centerBottom,
                :none
            )
            
            # Initialize common UI element properties
            this.anchor.current_state = anchor
            this.anchorOffset = anchorOffset
            this.clickEvents = clickEvent !== nothing ? Function[clickEvent] : Function[]
            this.hoverEnterEvents = hoverEnterEvent !== nothing ? Function[hoverEnterEvent] : Function[]
            this.hoverExitEvents = hoverExitEvent !== nothing ? Function[hoverExitEvent] : Function[]
            this.id = id
            this.isActive = isActive
            this.isHovered = false
            this.layer = layer
            this.name = name
            this.position = position
            this.size = size
            this.color = color
            this.isWorldEntity = isWorldEntity
            this.persistentBetweenScenes = persistentBetweenScenes
            this.parent = parent
            this.rotation = rotation
            this.forceClickCheck = false
            
            return this
        end
    end

    """
    add_child(canvas::Canvas, child::UI.UIElement)
    
    Adds a UI element as a child of the canvas.
    Sets the child's parent to this canvas and updates its anchoring.
    """
    function add_child(canvas::Canvas, child::UI.UIElement)
        if child in canvas.children
            @warn "Child $(child.name) is already a child of canvas $(canvas.name)"
            return
        end
        
        push!(canvas.children, child)
        child.parent = canvas
        
        # If the canvas is not active, deactivate the child
        if !canvas.isActive
            child.isActive = false
        end
        
        # Update child's anchoring relative to the canvas
        if child.anchor.current_state != :none
            UI.align_to_anchor(child)
        end
        
        @debug "Added $(child.name) as child of canvas $(canvas.name)"
    end

    """
    remove_child(canvas::Canvas, child::UI.UIElement)
    
    Removes a UI element from the canvas's children.
    """
    function remove_child(canvas::Canvas, child::UI.UIElement)
        index = findfirst(x -> x === child, canvas.children)
        if index !== nothing
            deleteat!(canvas.children, index)
            child.parent = nothing
            @debug "Removed $(child.name) from canvas $(canvas.name)"
        else
            @warn "Child $(child.name) is not a child of canvas $(canvas.name)"
        end
    end

    """
    get_children(canvas::Canvas) -> Vector{UI.UIElement}
    
    Returns all children of the canvas.
    """
    function get_children(canvas::Canvas)
        return canvas.children
    end

    """
    set_active(canvas::Canvas, active::Bool)
    
    Sets the canvas active state and propagates to all children.
    """
    function set_active(canvas::Canvas, active::Bool)
        canvas.isActive = active
        
        # Propagate to all children
        for child in canvas.children
            child.isActive = active
        end
        
        @debug "Canvas $(canvas.name) active state set to $(active)"
    end

    """
    is_child_active(canvas::Canvas, child::UI.UIElement) -> Bool
    
    Checks if a child is active, considering both the child's and canvas's active state.
    """
    function is_child_active(canvas::Canvas, child::UI.UIElement)
        return canvas.isActive && child.isActive
    end

    """
    get_all_descendants(canvas::Canvas) -> Vector{UI.UIElement}
    
    Recursively gets all descendants of the canvas (children, grandchildren, etc.).
    """
    function get_all_descendants(canvas::Canvas)
        descendants = UI.UIElement[]
        
        function collect_descendants(element::UI.UIElement)
            if isa(element, Canvas)
                for child in element.children
                    push!(descendants, child)
                    collect_descendants(child)
                end
            end
        end
        
        collect_descendants(canvas)
        return descendants
    end

    """
    find_child_by_name(canvas::Canvas, name::String) -> Union{UI.UIElement, Nothing}
    
    Finds a child by name (searches recursively through all descendants).
    """
    function find_child_by_name(canvas::Canvas, name::String)
        for child in canvas.children
            if child.name == name
                return child
            end
            
            # If child is also a canvas, search recursively
            if isa(child, Canvas)
                result = find_child_by_name(child, name)
                if result !== nothing
                    return result
                end
            end
        end
        
        return nothing
    end

    """
    find_child_by_id(canvas::Canvas, id::String) -> Union{UI.UIElement, Nothing}
    
    Finds a child by ID (searches recursively through all descendants).
    """
    function find_child_by_id(canvas::Canvas, id::String)
        for child in canvas.children
            if child.id == id
                return child
            end
            
            # If child is also a canvas, search recursively
            if isa(child, Canvas)
                result = find_child_by_id(child, id)
                if result !== nothing
                    return result
                end
            end
        end
        
        return nothing
    end

    """
    get_canvas_bounds(canvas::Canvas) -> (position::Vector2, size::Vector2)
    
    Gets the world-space bounds of the canvas.
    """
    function get_canvas_bounds(canvas::Canvas)
        return (canvas.position, canvas.size)
    end

    """
    is_point_in_canvas(canvas::Canvas, point::Vector2) -> Bool
    
    Checks if a point is within the canvas bounds.
    """
    function is_point_in_canvas(canvas::Canvas, point::Math.Vector2)
        return point.x >= canvas.position.x && 
               point.x <= canvas.position.x + canvas.size.x &&
               point.y >= canvas.position.y && 
               point.y <= canvas.position.y + canvas.size.y
    end

    """
    get_children_in_layer_order(canvas::Canvas) -> Vector{UI.UIElement}
    
    Returns children sorted by layer for proper rendering order.
    """
    function get_children_in_layer_order(canvas::Canvas)
        return sort(canvas.children, by=child -> child.layer)
    end

    """
    destroy_canvas(canvas::Canvas)
    
    Properly destroys the canvas and all its children.
    """
    function destroy_canvas(canvas::Canvas)
        # Destroy all children first
        for child in canvas.children
            if isa(child, Canvas)
                destroy_canvas(child)
            else
                # Use the appropriate destroy method for other UI elements
                if hasmethod(UI.destroy, (typeof(child),))
                    UI.destroy(child)
                end
            end
        end
        
        # Clear children array
        empty!(canvas.children)
        
        # Remove from relationships if it exists
        UI.delete_relationship(canvas)
        
        @debug "Destroyed canvas $(canvas.name) and all its children"
    end

    # Override the setproperty! function to handle canvas-specific properties
    function Base.setproperty!(canvas::Canvas, property::Symbol, value)
        # Call the parent setproperty! first
        UI.setproperty!(canvas, property, value)
        
        # Handle canvas-specific property changes
        if property == :isActive
            # Propagate active state to all children
            for child in canvas.children
                child.isActive = value
            end
        elseif property == :position || property == :size
            # Update anchoring for all children when canvas moves or resizes
            for child in canvas.children
                if child.anchor.current_state != :none
                    UI.align_to_anchor(child)
                end
            end
        end
    end

    """
    UI.render(canvas::Canvas)
    
    Renders the canvas and all its children in proper layer order.
    """
    function UI.render(canvas::Canvas)
        if !canvas.isActive || !canvas.isVisible
            return
        end
        
        # Render the canvas background if it has a visible color
        if canvas.color[4] > 0  # Alpha > 0
            camera = MAIN.scene.camera
            
            # Calculate drawing coordinates based on world or screen position
            if canvas.isWorldEntity && camera !== nothing
                # Calculate position in screen space
                posX = (canvas.position.x - (camera.position.x + camera.offset.x)) * SCALE_UNITS
                posY = (canvas.position.y - (camera.position.y + camera.offset.y)) * SCALE_UNITS
                
                # For world entities, size needs to be scaled by SCALE_UNITS
                width = canvas.size.x * SCALE_UNITS
                height = canvas.size.y * SCALE_UNITS
                
                rect = SDL2.SDL_FRect(
                    Float32(posX),
                    Float32(posY),
                    Float32(width),
                    Float32(height)
                )
            else
                rect = SDL2.SDL_FRect(
                    Float32(canvas.position.x),
                    Float32(canvas.position.y),
                    Float32(canvas.size.x),
                    Float32(canvas.size.y)
                )
            end
            
            # Save current render draw color
            r = Ref(UInt8(0))
            g = Ref(UInt8(0))
            b = Ref(UInt8(0))
            a = Ref(UInt8(0))
            SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r, g, b, a)
            
            # Set canvas color
            SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
                UInt8(canvas.color[1]), UInt8(canvas.color[2]), 
                UInt8(canvas.color[3]), UInt8(canvas.color[4]))
            
            SDL2.SDL_SetRenderDrawBlendMode(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, SDL2.SDL_BLENDMODE_BLEND)
            
            # Draw the canvas background
            SDL2.SDL_RenderFillRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rect)
            
            # Restore original color
            SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r[], g[], b[], a[])
        end
        
        # Render all children in layer order
        children_in_order = get_children_in_layer_order(canvas)
        for child in children_in_order
            if is_child_active(canvas, child)
                # Apply clipping if enabled
                if canvas.clipChildren
                    # Set up clipping rectangle for children
                    clip_rect = SDL2.SDL_Rect(
                        Int32(canvas.position.x),
                        Int32(canvas.position.y),
                        Int32(canvas.size.x),
                        Int32(canvas.size.y)
                    )
                    SDL2.SDL_RenderSetClipRect(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, clip_rect)
                end
                
                # Render the child
                UI.render(child)
                
                # Reset clipping if it was applied
                if canvas.clipChildren
                    SDL2.SDL_RenderSetClipRect(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, C_NULL)
                end
            end
        end
    end

    """
    UI.initialize(canvas::Canvas)
    
    Initializes the canvas (currently no special initialization needed).
    """
    function UI.initialize(canvas::Canvas)
        # Canvas doesn't need special initialization
        # Children will be initialized when they are added
    end

    """
    UI.destroy(canvas::Canvas)
    
    Destroys the canvas and all its children.
    """
    function UI.destroy(canvas::Canvas)
        destroy_canvas(canvas)
    end

end # module CanvasModule
