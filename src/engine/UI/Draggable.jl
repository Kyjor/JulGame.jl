# module DraggableModule
#     using ..UI.JulGame
#     using ..UI.JulGame.Math
#     using ..UI.JulGame.InputModule
#     import ..UI
    
#     export Draggable
    
#     """
#     A component that can be attached to UI elements to make them draggable.
#     """
#     mutable struct Draggable
#         id::String
#         name::String
#         targetElement::Any  # The UI element this draggable is attached to
#         isDragging::Bool
#         dragStartPosition::Math.Vector2  # Mouse position when drag started
#         elementStartPosition::Math.Vector2  # Element position when drag started
#         constraints::Union{Nothing, Function}  # Optional function to constrain movement
#         onDragStart::Union{Nothing, Function}  # Optional callback when dragging starts
#         onDragEnd::Union{Nothing, Function}  # Optional callback when dragging ends
#         onDragMove::Union{Nothing, Function}  # Optional callback during dragging
#         isActive::Bool
#         persistentBetweenScenes::Bool
#         dragOffset::Math.Vector2  # Offset from mouse position to element position
        
#         """
#         Create a new Draggable component.
        
#         # Arguments
#         - `targetElement`: The UI element to make draggable
#         - `constraints=nothing`: Optional function to constrain movement. Function signature: (element, newPosition) -> constrainedPosition
#         - `onDragStart=nothing`: Optional callback when dragging starts. Function signature: (element, position) -> nothing
#         - `onDragEnd=nothing`: Optional callback when dragging ends. Function signature: (element, position) -> nothing
#         - `onDragMove=nothing`: Optional callback during dragging. Function signature: (element, position) -> nothing
#         - `name="Draggable"`: Name for this component
#         - `id=""`: Optional ID for this component
#         """
#         function Draggable(targetElement::Any;
#                           constraints::Union{Nothing, Function}=nothing,
#                           onDragStart::Union{Nothing, Function}=nothing,
#                           onDragEnd::Union{Nothing, Function}=nothing,
#                           onDragMove::Union{Nothing, Function}=nothing,
#                           name::String="Draggable",
#                           id::String=JulGame.generate_uuid())
#             this = new()
            
#             this.id = id
#             this.name = name
#             this.targetElement = targetElement
#             this.isDragging = false
#             this.dragStartPosition = Math.Vector2(0, 0)
#             this.elementStartPosition = Math.Vector2(0, 0)
#             this.constraints = constraints
#             this.onDragStart = onDragStart
#             this.onDragEnd = onDragEnd
#             this.onDragMove = onDragMove
#             this.isActive = true
#             this.persistentBetweenScenes = false
#             this.dragOffset = Math.Vector2(0, 0)
            
#             # Add the draggable as a component to the target element
#             if !hasproperty(targetElement, :components)
#                 targetElement.components = []
#             end
#             push!(targetElement.components, this)
            
#             # Extend handle_event for the target element to handle dragging
#             old_handle_event = targetElement.handle_event
            
#             # Store the old handle_event function if it exists
#             if old_handle_event === nothing
#                 function handle_event(target, evt, x, y)
#                     handle_draggable_event(this, evt, x, y)
#                 end
#             else
#                 function handle_event(target, evt, x, y)
#                     # Call the original event handler first
#                     old_handle_event(target, evt, x, y)
                    
#                     # Then handle dragging
#                     handle_draggable_event(this, evt, x, y)
#                 end
#             end
            
#             # Replace the handle_event function
#             targetElement.handle_event = handle_event
            
#             return this
#         end
#     end
    
#     """
#     Handle mouse events for the draggable component.
#     """
#     function handle_draggable_event(this::Draggable, evt, x, y)
#         if !this.isActive || this.targetElement === nothing || !this.targetElement.isActive
#             return
#         end
        
#         if evt.type == SDL2.SDL_MOUSEBUTTONDOWN && evt.button.button == SDL2.SDL_BUTTON_LEFT
#             # Start dragging on left mouse button press inside the element
#             this.isDragging = true
#             this.dragStartPosition = Math.Vector2(x, y)
#             this.elementStartPosition = Math.Vector2(this.targetElement.position.x, this.targetElement.position.y)
            
#             # Calculate the offset between mouse position and element position
#             this.dragOffset = Math.Vector2(
#                 this.elementStartPosition.x - x,
#                 this.elementStartPosition.y - y
#             )
            
#             # Change cursor to indicate dragging
#             SDL2.SDL_SetCursor(Input.instance().cursorBank["sizeall"])
            
#             # Call onDragStart callback if provided
#             if this.onDragStart !== nothing
#                 this.onDragStart(this.targetElement, Math.Vector2(x, y))
#             end
#         elseif evt.type == SDL2.SDL_MOUSEBUTTONUP && evt.button.button == SDL2.SDL_BUTTON_LEFT && this.isDragging
#             # Stop dragging on left mouse button release
#             this.isDragging = false
            
#             # Reset cursor
#             SDL2.SDL_SetCursor(Input.instance().defaultCursor)
            
#             # Call onDragEnd callback if provided
#             if this.onDragEnd !== nothing
#                 this.onDragEnd(this.targetElement, Math.Vector2(x, y))
#             end
#         elseif evt.type == SDL2.SDL_MOUSEMOTION && this.isDragging
#             # Update position while dragging
#             newX = x + this.dragOffset.x
#             newY = y + this.dragOffset.y
            
#             # Apply constraints if provided
#             if this.constraints !== nothing
#                 constrainedPosition = this.constraints(this.targetElement, Math.Vector2(newX, newY))
#                 newX = constrainedPosition.x
#                 newY = constrainedPosition.y
#             end
            
#             # Update the element position
#             this.targetElement.position = Math.Vector2(newX, newY)
            
#             # Call onDragMove callback if provided
#             if this.onDragMove !== nothing
#                 this.onDragMove(this.targetElement, Math.Vector2(newX, newY))
#             end
#         end
#     end
    
#     """
#     Destroy method called when the component is removed.
#     """
#     function UI.destroy(this::Draggable)
#         # Reset cursor if we were dragging
#         if this.isDragging
#             this.isDragging = false
#             SDL2.SDL_SetCursor(Input.instance().defaultCursor)
#         end
#     end
    
#     """
#     Add the ability to be dragged to an existing UI element.
    
#     # Arguments
#     - `element`: The UI element to make draggable
#     - `constraints=nothing`: Optional function to constrain movement
#     - `onDragStart=nothing`: Optional callback when dragging starts
#     - `onDragEnd=nothing`: Optional callback when dragging ends
#     - `onDragMove=nothing`: Optional callback during dragging
#     - `name="Draggable"`: Name for this component
#     - `id=""`: Optional ID for this component
    
#     # Returns
#     The Draggable component
#     """
#     function make_draggable(element::Any;
#                            constraints::Union{Nothing, Function}=nothing,
#                            onDragStart::Union{Nothing, Function}=nothing,
#                            onDragEnd::Union{Nothing, Function}=nothing,
#                            onDragMove::Union{Nothing, Function}=nothing,
#                            name::String="Draggable",
#                            id::String="")
#         return Draggable(
#             element,
#             constraints=constraints,
#             onDragStart=onDragStart,
#             onDragEnd=onDragEnd,
#             onDragMove=onDragMove,
#             name=name,
#             id=id
#         )
#     end
    
#     """
#     Constrain movement to stay within the window bounds.
    
#     # Returns
#     A constraint function that can be passed to make_draggable
#     """
#     function constrain_to_window()
#         return function(element, newPosition)
#             # Get window size
#             width, height = Ref{Int32}(0), Ref{Int32}(0)
#             SDL2.SDL_GetWindowSize(JulGame.Window, width, height)
            
#             # Constrain to window bounds, accounting for element size
#             x = clamp(newPosition.x, 0, width[] - element.size.x)
#             y = clamp(newPosition.y, 0, height[] - element.size.y)
            
#             return Math.Vector2(x, y)
#         end
#     end
    
#     """
#     Constrain movement to a specific rectangular area.
    
#     # Arguments
#     - `x`: Left edge of the constraint area
#     - `y`: Top edge of the constraint area
#     - `width`: Width of the constraint area
#     - `height`: Height of the constraint area
    
#     # Returns
#     A constraint function that can be passed to make_draggable
#     """
#     function constrain_to_rect(x::Number, y::Number, width::Number, height::Number)
#         return function(element, newPosition)
#             # Constrain to the specified rectangle, accounting for element size
#             constrainedX = clamp(newPosition.x, x, x + width - element.size.x)
#             constrainedY = clamp(newPosition.y, y, y + height - element.size.y)
            
#             return Math.Vector2(constrainedX, constrainedY)
#         end
#     end
# end 