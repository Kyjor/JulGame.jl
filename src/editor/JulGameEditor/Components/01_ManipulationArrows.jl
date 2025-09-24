"""
ManipulationArrows.jl

A modular component for creating interactive manipulation arrows in ImGui for moving and resizing entities.
Supports position manipulation (X, Y, XY) and size manipulation with optional grid snapping.
"""

# Arrow size flag enum
@enum ArrowSizeFlag begin
    NoResize
    OnlyX  
    Default
end

# Global state for manipulation
mutable struct ManipulationState
    offset::Math.Vector2f
    need_update::Bool
    mode::Int
    can_update::Bool
    
    ManipulationState() = new(Math.Vector2f(0.0, 0.0), true, -1, true)
end

# Global manipulation states (one per widget type)
const POSITION_STATE = ManipulationState()
const RESIZE_STATE = ManipulationState()

"""
    draw_border(id::String, color::NTuple{4, Int}, size::Math.Vector2f, rounding::Float32 = 1.0f0)

Draws a colored rectangular border at the current cursor position.
"""
function draw_border(id::String, color::NTuple{4, Int}, size::Math.Vector2f, rounding::Float32 = 1.0f0)
    if CImGui.IsWindowCollapsed()
        return
    end
    
    cursor_pos = CImGui.GetCursorScreenPos()
    draw_list = CImGui.GetWindowDrawList()
    
    # Convert color tuple to ImU32
    color_u32 = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(color[1]/255, color[2]/255, color[3]/255, color[4]/255))
    
    # Draw filled rectangle
    CImGui.AddRectFilled(
        draw_list,
        cursor_pos,
        CImGui.ImVec2(cursor_pos.x + size.x, cursor_pos.y + size.y),
        color_u32,
        rounding
    )
    
    # Reserve space for the item
    #CImGui.SetCursorScreenPos(CImGui.ImVec2(cursor_pos.x + size.x, cursor_pos.y + size.y))
    CImGui.Dummy(CImGui.ImVec2(size.x, size.y))
end

"""
    draw_position_arrows(position::Ref{Math.Vector2f}, positioning::Int = 0) -> Bool

Draws interactive arrows for position manipulation. Returns true if position was modified.

# Arguments
- `position`: Reference to the position vector to modify
- `positioning`: Grid snap value (0 = no snapping)

# Returns
- `Bool`: true if the position was modified during this frame
"""
function draw_position_arrows(position::Ref{Math.Vector2f}, positioning::Int = 0)::Bool
    io = CImGui.GetIO()
    state = POSITION_STATE
    modified = false
    
    # Handle mouse state
    if CImGui.IsMouseDown(0)
        if state.need_update
            window_pos = CImGui.GetWindowPos()
            mouse_pos = CImGui.GetMousePos()
            # Convert mouse position to window-relative coordinates
            mouse_window_pos = Math.Vector2f(
                mouse_pos.x - window_pos.x,
                mouse_pos.y - window_pos.y
            )
            state.offset = Math.Vector2f(
                position[].x - mouse_window_pos.x,
                position[].y - mouse_window_pos.y
            )
            state.need_update = false
        end
    else
        state.mode = -1
        state.need_update = true
        state.can_update = true
    end
    
    # Get current item size and calculate center
    item_size = CImGui.GetItemRectSize()
    center_pos = Math.Vector2f(
        position[].x + item_size.x / 2,
        position[].y + item_size.y / 2
    )
    
    # Draw X-axis arrow (red)
    CImGui.SetCursorPos(CImGui.ImVec2(center_pos.x + 9, center_pos.y - 3))
    draw_border("###ArrowX", (255, 0, 0, 255), Math.Vector2f(41.0, 8.0))
    if state.can_update && CImGui.IsItemHovered()
        state.mode = 0
    end
    
    # Draw Y-axis arrow (green)  
    CImGui.SetCursorPos(CImGui.ImVec2(center_pos.x - 3, center_pos.y - 41))
    draw_border("###ArrowY", (0, 255, 0, 255), Math.Vector2f(8.0, 41.0))
    if state.can_update && CImGui.IsItemHovered()
        state.mode = 1
    end
    
    # Draw XY center handle (white)
    CImGui.SetCursorPos(CImGui.ImVec2(center_pos.x - 9, center_pos.y - 9))
    draw_border("###ArrowXY", (255, 255, 255, 255), Math.Vector2f(18.0, 18.0))
    if state.can_update && CImGui.IsItemHovered()
        state.mode = 2
    end
    
    # Handle dragging
    if !state.need_update && CImGui.IsMouseDragging(0)
        mouse_pos = CImGui.GetMousePos()
        window_pos = CImGui.GetWindowPos()
        state.can_update = false
        
        # Draw grid lines if positioning is enabled
        if positioning > 0
            #draw_grid_lines(window_pos, CImGui.GetWindowSize(), positioning, Math.Vector2f(item_size.x, item_size.y))
        end
        
        if state.mode == 0  # X-axis only
            mouse_local_x = mouse_pos.x - window_pos.x
            new_x = mouse_local_x + state.offset.x
            if positioning > 0
                new_x = Float64(div(Int(new_x), positioning) * positioning)
            end
            position[] = Math.Vector2f(new_x, position[].y)
            modified = true
            
        elseif state.mode == 1  # Y-axis only
            mouse_local_y = mouse_pos.y - window_pos.y
            new_y = mouse_local_y + state.offset.y
            if positioning > 0
                new_y = Float64(div(Int(new_y), positioning) * positioning)
            end
            position[] = Math.Vector2f(position[].x, new_y)
            modified = true
            
        elseif state.mode == 2  # Both axes
            mouse_local_x = mouse_pos.x - window_pos.x
            mouse_local_y = mouse_pos.y - window_pos.y
            new_x = mouse_local_x + state.offset.x
            new_y = mouse_local_y + state.offset.y
            if positioning > 0
                new_x = Float64(div(Int(new_x), positioning) * positioning)
                new_y = Float64(div(Int(new_y), positioning) * positioning)
            end
            position[] = Math.Vector2f(new_x, new_y)
            modified = true
        end
    end
    
    return modified
end

"""
    draw_resize_handles(widget_pos::Math.Vector2f, size::Ref{Math.Vector2f}, positioning::Int = 0, flag::ArrowSizeFlag = Default)

Draws interactive resize handles for size manipulation.

# Arguments
- `widget_pos`: Position of the widget being resized
- `size`: Reference to the size vector to modify  
- `positioning`: Grid snap value (0 = no snapping)
- `flag`: Resize mode (NoResize, OnlyX, Default)
"""
function draw_resize_handles(widget_pos::Math.Vector2f, size::Ref{Math.Vector2f}, positioning::Int = 0, flag::ArrowSizeFlag = Default)
    if flag == NoResize
        return
    end
    
    io = CImGui.GetIO()
    state = RESIZE_STATE
    
    # Handle mouse state
    if CImGui.IsMouseDown(0)
        if state.need_update
            state.need_update = false
        end
    else
        state.mode = -1
        state.need_update = true
        state.can_update = true
    end
    
    # Get item size and calculate handle positions
    item_size = CImGui.GetItemRectSize()
    bottom_right = Math.Vector2f(widget_pos.x + item_size.x - 5, widget_pos.y + item_size.y - 5)
    
    if flag == Default
        # Bottom-right corner handle (both axes)
        CImGui.SetCursorPos(CImGui.ImVec2(bottom_right.x, bottom_right.y))
        draw_border("##SizeAuto", (200, 200, 200, 255), Math.Vector2f(10.0, 10.0))
        if state.can_update && CImGui.IsItemHovered()
            state.mode = 0
        end
        
        # Right edge handle (X-axis only)
        CImGui.SetCursorPos(CImGui.ImVec2(bottom_right.x, widget_pos.y + item_size.y/2 - 5))
        draw_border("##SizeX", (200, 200, 200, 255), Math.Vector2f(10.0, 10.0))
        if state.can_update && CImGui.IsItemHovered()
            state.mode = 1
        end
        
        # Bottom edge handle (Y-axis only)
        CImGui.SetCursorPos(CImGui.ImVec2(widget_pos.x + item_size.x/2 - 5, bottom_right.y))
        draw_border("##SizeY", (200, 200, 200, 255), Math.Vector2f(10.0, 10.0))
        if state.can_update && CImGui.IsItemHovered()
            state.mode = 2
        end
    else  # OnlyX
        # Right edge handle (X-axis only)
        CImGui.SetCursorPos(CImGui.ImVec2(bottom_right.x, widget_pos.y + item_size.y/2 - 5))
        draw_border("##SizeX", (200, 200, 200, 255), Math.Vector2f(10.0, 10.0))
        if state.can_update && CImGui.IsItemHovered()
            state.mode = 1
        end
    end
    
    # Handle dragging
    if !state.need_update && CImGui.IsMouseDragging(0)
        mouse_pos = CImGui.GetMousePos()
        window_pos = CImGui.GetWindowPos()
        state.can_update = false
        
        # Draw grid lines if positioning is enabled
        if positioning > 0
            #draw_grid_lines(window_pos, CImGui.GetWindowSize(), positioning, Math.Vector2f(0.0, 0.0), widget_pos)
        end
        
        if state.mode == 0  # Both axes
            mouse_local = Math.Vector2f(
                mouse_pos.x - window_pos.x - widget_pos.x,
                mouse_pos.y - window_pos.y - widget_pos.y
            )
            if positioning > 0
                size[] = Math.Vector2f(
                    max(0, Float64(div(Int(mouse_local.x), positioning) * positioning)),
                    max(0, Float64(div(Int(mouse_local.y), positioning) * positioning))
                )
            else
                size[] = Math.Vector2f(max(0, mouse_local.x), max(0, mouse_local.y))
            end
            
        elseif state.mode == 1  # X-axis only
            mouse_local_x = mouse_pos.x - window_pos.x - widget_pos.x
            if positioning > 0
                size[] = Math.Vector2f(
                    max(0, Float64(div(Int(mouse_local_x), positioning) * positioning)),
                    size[].y
                )
            else
                size[] = Math.Vector2f(max(0, mouse_local_x), size[].y)
            end
            
        elseif state.mode == 2  # Y-axis only
            mouse_local_y = mouse_pos.y - window_pos.y - widget_pos.y
            if positioning > 0
                size[] = Math.Vector2f(
                    size[].x,
                    max(0, Float64(div(Int(mouse_local_y), positioning) * positioning))
                )
            else
                size[] = Math.Vector2f(size[].x, max(0, mouse_local_y))
            end
        end
    end
end

"""
    draw_grid_lines(window_pos::CImGui.ImVec2, window_size::CImGui.ImVec2, positioning::Int, item_size::Math.Vector2f, offset::Math.Vector2f = Math.Vector2f(0.0, 0.0))

Draws grid lines for visual alignment during manipulation.
"""
function draw_grid_lines(window_pos::CImGui.ImVec2, window_size::CImGui.ImVec2, positioning::Int, item_size::Math.Vector2f, offset::Math.Vector2f = Math.Vector2f(0.0, 0.0))
    draw_list = CImGui.GetWindowDrawList()
    grid_color = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(1.0, 1.0, 1.0, 0.16))
    
    # Vertical lines
    num_x_lines = round(Int, window_size.x / positioning)
    for x in 0:num_x_lines
        x_pos = (x * positioning) + window_pos.x + item_size.x / 2 + offset.x
        CImGui.AddLine(
            draw_list,
            CImGui.ImVec2(x_pos, window_pos.y),
            CImGui.ImVec2(x_pos, window_size.y + window_pos.y),
            grid_color
        )
    end
    
    # Horizontal lines
    num_y_lines = round(Int, window_size.y / positioning)
    for y in 0:num_y_lines
        y_pos = (y * positioning) + window_pos.y + item_size.y / 2 + offset.y
        CImGui.AddLine(
            draw_list,
            CImGui.ImVec2(window_pos.x, y_pos),
            CImGui.ImVec2(window_size.x + window_pos.x, y_pos),
            grid_color
        )
    end
end