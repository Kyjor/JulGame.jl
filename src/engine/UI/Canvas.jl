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
    mutable struct Canvas <: JulGame.ICanvas
        # Canvas-specific properties
        children::Vector{JulGame.IUIElement}
        clipChildren::Bool  # Whether to clip children to canvas bounds
        
        # Canvas constructor
        function Canvas(;
            id::String=JulGame.generate_uuid(),
            name::String="Canvas",
            anchor::Symbol=:none,
            anchorOffset::Math.Vector2=Math.Vector2(0, 0),
            layer::Int=0,
            position::Math.Vector2=Math.Vector2(0, 0),
            size::Math.Vector2=Math.Vector2(0, 0),
            clickEvents::Vector{Function}=Function[],
            hoverEnterEvents::Vector{Function}=Function[],
            hoverExitEvents::Vector{Function}=Function[],
            isActive::Bool=true,
            persistentBetweenScenes::Bool=false,
            color::NTuple{4, Int}=(0, 0, 0, 0),
            clipChildren::Bool=false,
            parent::Union{JulGame.IUIElement, Nothing, Any}=nothing,
            rotation::Float64=0.0,
            forceClickCheck::Bool=false
        )
            this = new()
            
            # Initialize children collection
            this.children = JulGame.IUIElement[]
            
            # Canvas-specific properties
            this.clipChildren = clipChildren
            
            # Set up anchor enum
            this.anchor = deepcopy(UI.anchor_types)
            
            # Initialize common UI element properties
            this.anchor.current_state = anchor
            this.anchorOffset = anchorOffset
            this.id = id
            this.isActive = isActive
            this.isHovered = false
            this.layer = layer
            this.name = name
            this.position = position
            this.size = size
            this.color = color
            this.persistentBetweenScenes = persistentBetweenScenes
            this.parent = parent
            this.rotation = rotation
            this.forceClickCheck = forceClickCheck
            this.clickEvents = clickEvents
            this.hoverEnterEvents = hoverEnterEvents
            this.hoverExitEvents = hoverExitEvents
            
            return this
        end
    end

    """
    remove_child(canvas::Canvas, child::UI.UIElement)
    
    Removes a UI element from the canvas's children.
    """
    function remove_child(canvas::Canvas, child::JulGame.IUIElement)
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
    UI.render(canvas::Canvas)
    
    Renders the canvas and all its children in proper layer order.
    """
    function UI.render(canvas::Canvas)
    end
        # function UI.render(canvas::Canvas)
    #     if !canvas.isActive
    #         return
    #     end
        
    #     # Render the canvas background if it has a visible color
    #     if canvas.color[4] > 0  # Alpha > 0
    #         rect = SDL2.SDL_FRect(
    #             Float32(canvas.position.x),
    #             Float32(canvas.position.y),
    #             Float32(canvas.size.x),
    #             Float32(canvas.size.y)
    #         )
            
    #         # Save current render draw color
    #         r = Ref(UInt8(0))
    #         g = Ref(UInt8(0))
    #         b = Ref(UInt8(0))
    #         a = Ref(UInt8(0))
    #         SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r, g, b, a)
            
    #         # Set canvas color
    #         SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
    #             UInt8(canvas.color[1]), UInt8(canvas.color[2]), 
    #             UInt8(canvas.color[3]), UInt8(canvas.color[4]))
            
    #         SDL2.SDL_SetRenderDrawBlendMode(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, SDL2.SDL_BLENDMODE_BLEND)
            
    #         # Draw the canvas background
    #         SDL2.SDL_RenderFillRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rect)
            
    #         # Restore original color
    #         SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r[], g[], b[], a[])
    #     end
    # end

    """
    UI.destroy(canvas::Canvas)
    
    Destroys the canvas and all its children.
    """
    function UI.destroy(canvas::Canvas)
        @error "Destroy method not implemented for Canvas"
    end

end # module CanvasModule
