# Global state for manipulation arrows
mutable struct SceneManipulationState
    grid_snap::Int32
    manipulation_mode::EntityManipulationMode
    
    SceneManipulationState() = new(Int32(0), Both)
end

const SCENE_MANIPULATION_STATE = SceneManipulationState()

function show_scene_window(main, scene_tex_id, scrolling, zoom_level, duplicationMode, camera)::ImVec2
  #  CImGui.SetNextWindowSize((350, 560), CImGui.ImGuiCond_FirstUseEver)
    if JulGame.IS_EDITOR_PLAY_MODE
        CImGui.PushStyleColor(CImGui.ImGuiCol_TitleBg, (0.8, 0.1, 0.1, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_TitleBgActive, (0.9, 0.2, 0.2, 1.0))
        CImGui.Begin("Scene") || (CImGui.PopStyleColor(2); CImGui.End(); return ImVec2(0,0))
        CImGui.PopStyleColor(2)
    else
        CImGui.Begin("Scene") || (CImGui.End(); return ImVec2(0,0))
    end
    
    # Add manipulation controls at the top
    render_manipulation_controls()
    CImGui.Separator()
    # GET SIZE OF SCENE TEXTURE
    # w, h = Ref{Int32}(0), Ref{Int32}(0)
    # SDL2.SDL_QueryTexture(scene_tex_id[], Ref{UInt32}(0), Ref{Int32}(0), w, h)
    # println("Size of Scene Texture: ", w[], ", ", h[])
    draw_list = CImGui.GetWindowDrawList()
    io = CImGui.GetIO()
    
    # Canvas setup
    canvas_p0 = CImGui.GetCursorScreenPos()  # ImDrawList API uses screen coordinates!
    canvas_sz = CImGui.GetContentRegionAvail()  # Resize canvas to what's available
    canvas_sz = ImVec2(max(canvas_sz.x, 50.0), max(canvas_sz.y, 50.0))
    canvas_p1 = ImVec2(canvas_p0.x + canvas_sz.x, canvas_p0.y + canvas_sz.y)
    
    canvas_max = ImVec2(340, 560)
    origin = ImVec2(0 + scrolling[].x, 0 + scrolling[].y)  # Lock scrolled origin

    # Draw border and background color
    draw_list = CImGui.GetWindowDrawList()
    
    CImGui.AddRectFilled(draw_list, canvas_p0, canvas_p1, IM_COL32(50, 50, 50, 255))
    try
        # Set tint color based on play mode
        tint_color = JulGame.IS_EDITOR_PLAY_MODE ? IM_COL32(255, 200, 200, 255) : IM_COL32(255, 255, 255, 255)
        CImGui.AddImage(draw_list, scene_tex_id, canvas_p0, canvas_p1, ImVec2(0,0), ImVec2(1,1), tint_color)
    catch
    end
    CImGui.AddRect(draw_list, canvas_p0, canvas_p1, IM_COL32(255, 255, 255, 255))

    # Add a visual indicator for play mode
    if JulGame.IS_EDITOR_PLAY_MODE
        # Add a red border to make it more obvious we're in play mode
        border_thickness = 4.0
        CImGui.AddRect(draw_list, 
                     ImVec2(canvas_p0.x - border_thickness, canvas_p0.y - border_thickness), 
                     ImVec2(canvas_p1.x + border_thickness, canvas_p1.y + border_thickness), 
                     IM_COL32(255, 50, 50, 255), 
                     0.0,  # rounding 
                     0,    # flags
                     border_thickness)
                     
        # Add a "PLAY MODE" text indicator in a semi-transparent box at the top
        text = "PLAY MODE"
        text_size = CImGui.CalcTextSize(text)
        box_pos = ImVec2(canvas_p0.x + (canvas_sz.x - text_size.x) / 2 - 10, canvas_p0.y + 10)
        box_size = ImVec2(text_size.x + 20, text_size.y + 10)
        
        CImGui.AddRectFilled(draw_list, 
                           box_pos, 
                           ImVec2(box_pos.x + box_size.x, box_pos.y + box_size.y), 
                           IM_COL32(255, 50, 50, 200))
        
        CImGui.AddText(draw_list, 
                     ImVec2(box_pos.x + 10, box_pos.y + 5), 
                     IM_COL32(255, 255, 255, 255), 
                     text)
    end

    mouse_pos_in_canvas = ImVec2(unsafe_load(io.MousePos).x - canvas_p0.x, unsafe_load(io.MousePos).y - canvas_p0.y)
    # Calculate mouse position adjusted for zoom - this is the mouse position in the zoomed canvas coordinate system
    mouse_pos_in_canvas_zoom_adjusted = ImVec2(floor(mouse_pos_in_canvas.x / zoom_level[]), floor(mouse_pos_in_canvas.y / zoom_level[]))
    # Add first and second point
    # Add debug panel in the top right corner
    draw_debug_panel(draw_list, canvas_p0, canvas_p1, mouse_pos_in_canvas_zoom_adjusted, camera, main, zoom_level)
    # Pan
    mouse_threshold_for_pan = -1.0 
    mouse_drag_movement = ImVec2(0, 0)
    scale_unit_factor = 64.0 * zoom_level[]
    old_zoom = zoom_level[]
    scale_factor = 64.0 * old_zoom
    mouse_world_pos_x = (mouse_pos_in_canvas.x + (camera.position.x * scale_factor)) / scale_factor
    mouse_world_pos_y = (mouse_pos_in_canvas.y + (camera.position.y * scale_factor)) / scale_factor

    # Draw border around actual image that is being edited TODO: Fix this
    # CImGui.AddRect(draw_list, ImVec2(canvas_p0.x + (my_tex_w * zoom_level[]), canvas_p0.y + (my_tex_h * zoom_level[])), ImVec2(canvas_p0.x, canvas_p0.y), IM_COL32(255, 255, 255, 255))

    # Invisible button for interactions
    CImGui.InvisibleButton("canvas", canvas_sz, CImGui.ImGuiButtonFlags_MouseButtonLeft | CImGui.ImGuiButtonFlags_MouseButtonRight)
    is_hovered = CImGui.IsItemHovered()  # Hovered
    is_active = CImGui.IsItemActive()  # Held
    
    # Handle drag-and-drop from file explorer (if available) - must be called immediately after the button
    if main !== nothing
        if CImGui.BeginDragDropTarget()
            # Handle single file drops
            single_file_payload = CImGui.AcceptDragDropPayload("FILE_PATH")
            if single_file_payload != C_NULL
                @debug "Received drag-drop payload for single file"
                filepath = extract_file_path_from_payload(single_file_payload)
                @debug "Extracted filepath: $filepath"
                if filepath != ""
                    JulGame.EditorState["is_from_scene_viewer"] = true
                    JulGame.EditorState["dropped_files"] = [filepath]
                    JulGame.EditorState["mouse_world_pos"] = Math.Vector2f(mouse_world_pos_x, mouse_world_pos_y)
                    JulGame.EditorState["mouse_pos_in_canvas"] = Math.Vector2f(mouse_pos_in_canvas.x, mouse_pos_in_canvas.y)
                    #create_scene_entity_from_file(filepath, main, Math.Vector2f(mouse_world_pos_x, mouse_world_pos_y))
                end
            end
            
            # Handle multiple file drops
            multi_file_payload = CImGui.AcceptDragDropPayload("MULTIPLE_FILES")
            if multi_file_payload != C_NULL
                filepaths = extract_multiple_file_paths_from_payload(multi_file_payload)
                if !isempty(filepaths)
                    create_multiple_scene_entities(filepaths, main, Math.Vector2f(mouse_world_pos_x, mouse_world_pos_y))
                end
            end
        
            CImGui.EndDragDropTarget()
        end
    end


    
   
    if is_active && CImGui.IsMouseDragging(CImGui.ImGuiMouseButton_Right, mouse_threshold_for_pan)
        scrolling[] = ImVec2(scrolling[].x + unsafe_load(io.MouseDelta).x, scrolling[].y + unsafe_load(io.MouseDelta).y)
        mouse_drag_movement = ImVec2(unsafe_load(io.MouseDelta).x, unsafe_load(io.MouseDelta).y)
        # if scene is something, update the camera position
        if main !== nothing && camera !== nothing
            # Use Vector3f to update camera position, preserving the z component
            camera.position = Math.Vector3f(
                camera.position.x - (mouse_drag_movement.x/scale_unit_factor), 
                camera.position.y - (mouse_drag_movement.y/scale_unit_factor),
                camera.position.z
            )
        end
    end

    # Zoom
    if unsafe_load(io.KeyCtrl)
        # Get mouse position in world space before zoom

        # Update zoom level
        zoom_level[] += unsafe_load(io.MouseWheel) * 0.1
        zoom_level[] = clamp(zoom_level[], 0.2, 5.0)
        
        # Only adjust camera if we have a main scene and camera, and if zoom actually changed
        if main !== nothing && camera !== nothing && old_zoom != zoom_level[]
            # Calculate new scale factor
            new_scale_factor = 64.0 * zoom_level[]
            
            # Calculate how the world position would change
            new_mouse_world_x = (mouse_pos_in_canvas.x + (camera.position.x * new_scale_factor)) / new_scale_factor
            new_mouse_world_y = (mouse_pos_in_canvas.y + (camera.position.y * new_scale_factor)) / new_scale_factor
            
            # Adjust camera position to keep world position under mouse
            offset_x = new_mouse_world_x - mouse_world_pos_x
            offset_y = new_mouse_world_y - mouse_world_pos_y
            
            # Use Vector3f to update camera position, preserving the z component
            camera.position = Math.Vector3f(
                camera.position.x - offset_x, 
                camera.position.y - offset_y,
                camera.position.z
            )
        end
    end
    
    # Pan camera with mouse wheel when Ctrl is not pressed
    if is_hovered && !unsafe_load(io.KeyCtrl) && (unsafe_load(io.MouseWheelH) != 0.0 || unsafe_load(io.MouseWheel) != 0.0) && main !== nothing && camera !== nothing
        # move camera
        camera.position = Math.Vector3f(
            camera.position.x - (unsafe_load(io.MouseWheelH)), 
            camera.position.y - (unsafe_load(io.MouseWheel)),
            camera.position.z
        )
    end

    # Apply zoom to camera position
    scale_unit_factor = 64.0 * zoom_level[]
    camPos = main !== nothing && camera !== nothing ? ImVec2((camera.position.x * scale_unit_factor), (camera.position.y * scale_unit_factor)) : ImVec2(0, 0)

    # Context menu
    drag_delta_right = CImGui.GetMouseDragDelta(CImGui.ImGuiMouseButton_Right)
    if CImGui.IsMouseReleased(CImGui.ImGuiMouseButton_Right) && drag_delta_right.x == 0.0 && drag_delta_right.y == 0.0
        CImGui.OpenPopupOnItemClick("context")
    end
    # if left click
    drag_delta_left = CImGui.GetMouseDragDelta(CImGui.ImGuiMouseButton_Left)
    if CImGui.IsMouseReleased(CImGui.ImGuiMouseButton_Left) && is_hovered && drag_delta_left.x == 0.0 && drag_delta_left.y == 0.0
        if duplicationMode
            handle_mouse_click_duplication(main)
        else
            handle_mouse_click(main, canvas_p0, camPos, mouse_pos_in_canvas_zoom_adjusted)
        end
    end
    
    # if left click and drag
    if is_hovered && (CImGui.IsMouseDragging(CImGui.ImGuiMouseButton_Left, mouse_threshold_for_pan) || duplicationMode)
        #drag_selected_entity(main, canvas_p0, camPos, mouse_pos_in_canvas_zoom_adjusted)
    end

    if CImGui.BeginPopup("context")
        if CImGui.MenuItem("Delete", "", false, main.selectedEntities !== nothing && length(main.selectedEntities) > 0)
            for entity in main.selectedEntities
                JulGame.destroy(entity)
            end
        end
        CImGui.EndPopup()
    end

     # Draw grid and lines
     CImGui.PushClipRect(draw_list, canvas_p0, canvas_p1, true)

     GRID_STEP = 64.0 * zoom_level[]
     
     # Adjust starting points for infinite grid
     start_x = canvas_p0.x - mod(camPos.x, GRID_STEP)
     start_y = canvas_p0.y - mod(camPos.y, GRID_STEP)
     
     # Draw vertical grid lines
     for x in start_x:GRID_STEP:canvas_p1.x
         CImGui.AddLine(draw_list, ImVec2(x, canvas_p0.y), ImVec2(x, canvas_p1.y), IM_COL32(200, 200, 200, 40))
     end
     
     # Draw horizontal grid lines
     for y in start_y:GRID_STEP:canvas_p1.y
         CImGui.AddLine(draw_list, ImVec2(canvas_p0.x, y), ImVec2(canvas_p1.x, y), IM_COL32(200, 200, 200, 40))
     end
     
     CImGui.PopClipRect(draw_list)
     
    
    # Draw square around selected entity and manipulation arrows
    highlight_current_entity(main, draw_list, canvas_p0, canvas_p1, zoom_level, camPos)
    
    # Draw camera debug outline
    if main !== nothing && camera !== nothing
        draw_camera_debug_outline(draw_list, canvas_p0, camPos, zoom_level, camera, main.scene.camera)
    end
    
    # Display UI elements in scene viewer if enabled
    display_ui_elements = get(JulGame.EditorState, "display_ui_elements", false)
    if display_ui_elements && main !== nothing && camera !== nothing
        render_ui_elements_in_scene(main, draw_list, canvas_p0, camPos, zoom_level, camera)
    end

    # Handle manipulation arrows for selected entity
    if main !== nothing && main.selectedEntities !== nothing && length(main.selectedEntities) > 0
        entity = main.selectedEntities[1]
        if !(entity isa UI.UIElement) && !(entity isa JulGame.CameraModule.Camera)
            handle_entity_manipulation_in_scene(entity, canvas_p0, camPos, zoom_level)
        elseif entity isa UI.UIElement && display_ui_elements
            # Handle UI element manipulation in scene viewer
            handle_ui_element_manipulation_in_scene(entity, canvas_p0, camPos, zoom_level, camera)
        end
    end

    CImGui.End()

    return canvas_sz
end

function handle_mouse_click(main, canvas_p0, camPos, mouse_pos_in_canvas_zoom_adjusted)
    # if main is nothing, return
    if main === nothing
        return
    end
    
    # Debug information
    # println("Handling mouse click at coordinates:")
    # println("Mouse position adjusted for zoom: $(mouse_pos_in_canvas_zoom_adjusted.x), $(mouse_pos_in_canvas_zoom_adjusted.y)")
    # println("Camera position: $(camPos.x), $(camPos.y)")
    
    # Check if UI elements display is enabled and try to select UI element first
    display_ui_elements = get(JulGame.EditorState, "display_ui_elements", false)
    selected_element = nothing
    
    if display_ui_elements
        # Try to select UI element first
        selected_element = get_nearest_ui_element(main, canvas_p0, camPos, mouse_pos_in_canvas_zoom_adjusted)
    end
    
    # If no UI element selected, try to select regular entity
    if selected_element === nothing
        selected_element = get_nearest_entity(main, canvas_p0, camPos, mouse_pos_in_canvas_zoom_adjusted)
    end
    
    if selected_element !== nothing
        # println("Selected element: $(selected_element.name)")
    else
        # println("No element selected")
    end
    
    main.selectedEntities = [selected_element]
end

function handle_mouse_click_duplication(main)
    # if main is nothing, return
    if main === nothing
        return
    end

    for entity in main.selectedEntities
        JulGame.duplicate(entity)
    end
end

function get_nearest_entity(main, canvas_p0, camPos, mouse_pos_in_canvas_zoom_adjusted)
    # if main is nothing, return
    if main === nothing
        return
    end
    # get all entities
    entities = main.scene.entities
    
    # Important: camPos is already scaled by zoom_level as it's calculated with scale_unit_factor = 64.0 * zoom_level[]
    # mouse_pos_in_canvas_zoom_adjusted is already divided by zoom_level, so it's in world coordinates
    # Therefore we need to use the original scale (64.0) to convert mouse click to world position
    scale_unit_factor = 64.0
    clicked_pos = ImVec2((mouse_pos_in_canvas_zoom_adjusted.x + camPos.x)/scale_unit_factor, (mouse_pos_in_canvas_zoom_adjusted.y + camPos.y)/scale_unit_factor)
    
    for entity in entities
        size = entity.transform.scale
        # entity.collider != C_NULL ? Component.get_size(entity.collider) : entity.transform.scale
        
        # get the nearest entity
        if clicked_pos.x >= entity.transform.position.x && clicked_pos.x <= entity.transform.position.x + size.x && clicked_pos.y >= entity.transform.position.y && clicked_pos.y <= entity.transform.position.y + size.y
            if length(main.selectedEntities) > 0 && main.selectedEntities[1] == entity
                continue
            end
            return entity
        end
    end

    return nothing
end

function highlight_current_entity(main, draw_list, canvas_p0, canvas_p1, zoom_level, camPos)
    # if main is nothing, return
    if main === nothing
        return
    end
    # if selected entity is nothing, return
    if main.selectedEntities === nothing || length(main.selectedEntities) == 0 || main.selectedEntities[1] isa UI.UIElement || main.selectedEntities[1] isa JulGame.CameraModule.Camera
        return
    end
    entity = main.selectedEntities[1]

    
    # Scale factor adjusted by zoom level
    scale_factor = 64.0 * zoom_level[]
    if entity === nothing
        return
    end
    # draw rect around selected entity
    CImGui.AddRect(draw_list, 
                  ImVec2(canvas_p0.x + (entity.transform.position.x * scale_factor) - camPos.x, 
                         canvas_p0.y + entity.transform.position.y * scale_factor - camPos.y), 
                  ImVec2(canvas_p0.x + entity.transform.position.x * scale_factor + (entity.transform.scale.x * scale_factor) - camPos.x, 
                         canvas_p0.y + entity.transform.position.y * scale_factor + (entity.transform.scale.y * scale_factor) - camPos.y), 
                  IM_COL32(255, 0, 0, 255))
end

function drag_selected_entity(main, canvas_p0, camPos, mouse_pos_in_canvas_zoom_adjusted)
    # if main is nothing, return
    if main === nothing
        return
    end
    # if selected entity is nothing, return
    if main.selectedEntities === nothing || length(main.selectedEntities) < 1
        return
    end
    for entity in main.selectedEntities
        # Same logic as in get_nearest_entity: camPos is already scaled by zoom_level
        # mouse_pos_in_canvas_zoom_adjusted is already adjusted for zoom
        scale_unit_factor = 64.0
        mouse_pos = ImVec2((mouse_pos_in_canvas_zoom_adjusted.x + camPos.x)/scale_unit_factor, (mouse_pos_in_canvas_zoom_adjusted.y + camPos.y)/scale_unit_factor)
        
        if unsafe_load(CImGui.GetIO().KeyCtrl)
            mouse_pos = ImVec2(floor(mouse_pos.x), floor(mouse_pos.y))
        end
        # get the selected entity position
        entity_pos = entity.transform.position
        # get the difference between the mouse position and the entity position
        diff = ImVec2(mouse_pos.x - entity_pos.x, mouse_pos.y - entity_pos.y)
        # update the entity position
        entity.transform.position = Math.Vector2f(entity_pos.x + diff.x, entity_pos.y + diff.y)
    end
end

"""
    render_manipulation_controls()

Renders UI controls for manipulation settings in the scene viewer.
"""
function render_manipulation_controls()
    # Manipulation mode control
    mode_names = ["Position", "Scale", "Both"]
    current_mode = Int32(SCENE_MANIPULATION_STATE.manipulation_mode)
    
    CImGui.SetNextItemWidth(100)
    if @c CImGui.Combo("Mode", &current_mode, mode_names, length(mode_names))
        SCENE_MANIPULATION_STATE.manipulation_mode = EntityManipulationMode(current_mode)
    end
    
    CImGui.SameLine()
    
    # Display UI Elements button
    display_ui_elements = get(JulGame.EditorState, "display_ui_elements", nothing) 
    uiElementsTitle = display_ui_elements !== nothing && display_ui_elements ? "Hide UI Elements" : "Show UI Elements"
    if CImGui.SmallButton(uiElementsTitle)
            # Clear selection by setting to empty array
        if display_ui_elements !== nothing
            JulGame.EditorState["display_ui_elements"] = !display_ui_elements
        else
            JulGame.EditorState["display_ui_elements"] = true
        end
    end
end

"""
    handle_entity_manipulation_in_scene(entity, canvas_p0, camPos, zoom_level)

Handles manipulation arrows for an entity in the scene viewer.
"""
function handle_entity_manipulation_in_scene(entity, canvas_p0, camPos, zoom_level)
    if entity === nothing
        return
    end
    transform = entity.transform
    scale_factor = 64.0 * zoom_level[]
    
    # Convert entity position to screen coordinates
    screen_pos = Math.Vector2(
        round(Int, canvas_p0.x + (transform.position.x * scale_factor) - camPos.x),
        round(Int, canvas_p0.y + (transform.position.y * scale_factor) - camPos.y)
    )
    
    # Convert screen position to window-relative coordinates for ImGui
    window_pos = CImGui.GetWindowPos()
    cursor_pos = CImGui.ImVec2(
        screen_pos.x - window_pos.x,
        screen_pos.y - window_pos.y
    )
    
    # Set cursor position relative to window
    CImGui.SetCursorPos(cursor_pos)
    
    # Create a dummy item to represent the entity for manipulation
    entity_size = Math.Vector2(transform.scale.x * scale_factor, transform.scale.y * scale_factor)
    CImGui.Dummy(CImGui.ImVec2(entity_size.x, entity_size.y))
    
    # Handle position manipulation
    if SCENE_MANIPULATION_STATE.manipulation_mode == Position || SCENE_MANIPULATION_STATE.manipulation_mode == Both
        # Use window-relative coordinates for manipulation arrows
        screen_pos_ref = Ref(Math.Vector2f(
            Float32(cursor_pos.x),  # Window-relative position
            Float32(cursor_pos.y)
        ))
        
        original_screen_pos = screen_pos_ref[]
        if draw_position_arrows(screen_pos_ref, Int(SCENE_MANIPULATION_STATE.grid_snap))
            # Calculate the screen space delta
            screen_delta = screen_pos_ref[] - original_screen_pos
            
            # Convert screen delta back to world coordinates
            world_delta_x = screen_delta.x / scale_factor
            world_delta_y = screen_delta.y / scale_factor
            
            # Apply the delta to the current world position
            new_world_pos = Math.Vector3f(
                transform.position.x + world_delta_x,
                transform.position.y + world_delta_y,
                transform.position.z
            )
            entity.transform.position = new_world_pos
            # Mark scene as modified
            JulGame.EditorState["scene_modified"] = true
        end
    end
    
    # Handle scale manipulation
    if SCENE_MANIPULATION_STATE.manipulation_mode == Scale || SCENE_MANIPULATION_STATE.manipulation_mode == Both
        if hasfield(typeof(transform), :scale)
            # Convert world scale to screen pixels for manipulation
            screen_scale = Math.Vector2f(
                transform.scale.x * scale_factor,
                transform.scale.y * scale_factor
            )
            scale_ref = Ref(screen_scale)
            
            # Use the same window-relative coordinates as position arrows
            widget_pos = Math.Vector2f(cursor_pos.x, cursor_pos.y)
            draw_resize_handles(widget_pos, scale_ref, Int(SCENE_MANIPULATION_STATE.grid_snap), Default)
            
            # Convert screen scale back to world scale
            new_world_scale = Math.Vector2f(
                scale_ref[].x / scale_factor,
                scale_ref[].y / scale_factor
            )
            
            if new_world_scale != Math.Vector2f(transform.scale.x, transform.scale.y)
                entity.transform.scale = Math.Vector3f(new_world_scale.x, new_world_scale.y, transform.scale.z)
                # Mark scene as modified
                JulGame.EditorState["scene_modified"] = true
            end
        end
    end
end

# New function to draw debug panel
function draw_debug_panel(draw_list, canvas_p0, canvas_p1, mouse_pos, camera, main, zoom_level)
    if main === nothing || camera === nothing
        return
    end

    # Track collapsed state with a proper static variable
    # Using a module-level mutable struct to maintain state
    global debug_panel_collapsed
    if !@isdefined(debug_panel_collapsed)
        global debug_panel_collapsed = false
    end

    # Panel size and position - in the top right corner
    panel_width = debug_panel_collapsed ? 25 : 200
    panel_height = debug_panel_collapsed ? 25 : 140
    padding = 10
    
    panel_pos = ImVec2(canvas_p1.x - panel_width - padding, canvas_p0.y + padding)
    panel_end = ImVec2(panel_pos.x + panel_width, panel_pos.y + panel_height)
    
    # Draw semi-transparent panel background
    CImGui.AddRectFilled(draw_list, panel_pos, panel_end, IM_COL32(50, 50, 50, 180), 5.0)
    CImGui.AddRect(draw_list, panel_pos, panel_end, IM_COL32(100, 100, 100, 255), 5.0)
    
    # Draw collapse/expand button
    collapse_button_size = 16
    collapse_button_padding = 5
    collapse_button_pos = ImVec2(panel_end.x - collapse_button_size - collapse_button_padding, panel_pos.y + collapse_button_padding)
    collapse_button_end = ImVec2(collapse_button_pos.x + collapse_button_size, collapse_button_pos.y + collapse_button_size)
    
    # Check if mouse is over collapse button
    io = CImGui.GetIO()
    mouse_pos_screen = unsafe_load(io.MousePos)
    collapse_hovered = mouse_pos_screen.x >= collapse_button_pos.x && mouse_pos_screen.x <= collapse_button_end.x &&
                       mouse_pos_screen.y >= collapse_button_pos.y && mouse_pos_screen.y <= collapse_button_end.y
    
    # Button background
    collapse_button_color = collapse_hovered ? IM_COL32(120, 120, 120, 255) : IM_COL32(100, 100, 100, 255)
    CImGui.AddRectFilled(draw_list, collapse_button_pos, collapse_button_end, collapse_button_color, 2.0)
    CImGui.AddRect(draw_list, collapse_button_pos, collapse_button_end, IM_COL32(150, 150, 150, 255), 2.0)
    
    # Draw appropriate icon (either "-" or "+")
    icon_color = IM_COL32(240, 240, 240, 255)
    if debug_panel_collapsed
        # Draw "+" for expand
        line_padding = 4
        CImGui.AddLine(draw_list, 
                    ImVec2(collapse_button_pos.x + line_padding, collapse_button_pos.y + collapse_button_size/2), 
                    ImVec2(collapse_button_end.x - line_padding, collapse_button_pos.y + collapse_button_size/2), 
                    icon_color, 1.5)
        CImGui.AddLine(draw_list, 
                    ImVec2(collapse_button_pos.x + collapse_button_size/2, collapse_button_pos.y + line_padding), 
                    ImVec2(collapse_button_pos.x + collapse_button_size/2, collapse_button_end.y - line_padding), 
                    icon_color, 1.5)
    else
        # Draw "-" for collapse
        line_padding = 4
        CImGui.AddLine(draw_list, 
                    ImVec2(collapse_button_pos.x + line_padding, collapse_button_pos.y + collapse_button_size/2), 
                    ImVec2(collapse_button_end.x - line_padding, collapse_button_pos.y + collapse_button_size/2), 
                    icon_color, 1.5)
    end
    
    # Handle button click
    if collapse_hovered && CImGui.IsMouseClicked(CImGui.ImGuiMouseButton_Left)
        global debug_panel_collapsed = !debug_panel_collapsed
    end
    
    # If collapsed, just show debug icon and return
    if debug_panel_collapsed
        # Draw debug icon (a simple "D" or gear icon)
       #=  CImGui.AddText(draw_list, 
                     ImVec2(panel_pos.x + panel_width/2 - 5, panel_pos.y + panel_height/2 - 7), 
                     IM_COL32(255, 255, 255, 255), 
                     "D") =#
        return
    end
    
    # Title
    title = "Debug Info"
    title_pos = ImVec2(panel_pos.x + 10, panel_pos.y + 5)
    CImGui.AddText(draw_list, title_pos, IM_COL32(255, 255, 255, 255), title)
    
    # Line under title
    line_y = title_pos.y + 15
    CImGui.AddLine(draw_list, 
                 ImVec2(panel_pos.x + 5, line_y), 
                 ImVec2(panel_end.x - 5, line_y), 
                 IM_COL32(150, 150, 150, 255))
    
    # Calculate world mouse position
    scale_unit_factor = 64.0 * zoom_level[]
    # We need to divide by scale_unit_factor to get world coordinates
    world_mouse_x = (mouse_pos.x + (camera.position.x * scale_unit_factor)) / scale_unit_factor
    world_mouse_y = (mouse_pos.y + (camera.position.y * scale_unit_factor)) / scale_unit_factor
    
    # Debug information text
    text_y = line_y + 10
    CImGui.AddText(draw_list, ImVec2(panel_pos.x + 10, text_y), 
                 IM_COL32(255, 255, 255, 255), 
                 "World Mouse: ($(round(world_mouse_x, digits=2)), $(round(world_mouse_y, digits=2)))")
    
    CImGui.AddText(draw_list, ImVec2(panel_pos.x + 10, text_y + 15), 
                 IM_COL32(255, 255, 255, 255), 
                 "Camera Pos: ($(round(camera.position.x, digits=2)), $(round(camera.position.y, digits=2)))")
    
    CImGui.AddText(draw_list, ImVec2(panel_pos.x + 10, text_y + 30), 
                 IM_COL32(255, 255, 255, 255), 
                 "Zoom Level: $(round(zoom_level[], digits=2))x")
    
    # Draw "Reset Camera" button
    button_width = 120
    button_height = 20
    button_x = panel_pos.x + (panel_width - button_width) / 2
    button_y = panel_end.y - button_height - 10
    
    button_pos = ImVec2(button_x, button_y)
    button_end = ImVec2(button_x + button_width, button_y + button_height)
    
    # Check if mouse is over button
    reset_hovered = mouse_pos_screen.x >= button_pos.x && mouse_pos_screen.x <= button_end.x &&
                 mouse_pos_screen.y >= button_pos.y && mouse_pos_screen.y <= button_end.y
    
    # Button background color changes when hovered
    button_color = reset_hovered ? IM_COL32(100, 120, 180, 255) : IM_COL32(70, 90, 150, 255)
    
    CImGui.AddRectFilled(draw_list, button_pos, button_end, button_color, 3.0)
    CImGui.AddRect(draw_list, button_pos, button_end, IM_COL32(120, 140, 200, 255), 3.0)
    
    # Button text
    text = "Reset Camera"
    text_size = CImGui.CalcTextSize(text)
    text_pos = ImVec2(button_pos.x + (button_width - text_size.x) / 2, 
                     button_pos.y + (button_height - text_size.y) / 2)
    
    CImGui.AddText(draw_list, text_pos, IM_COL32(255, 255, 255, 255), text)
    
    # Check for button click
    if reset_hovered && CImGui.IsMouseClicked(CImGui.ImGuiMouseButton_Left)
        # Reset camera position to 0,0,0
        camera.position = Math.Vector3f(0.0, 0.0, 0.0)
    end
    
    # Draw "Reset Zoom" button
    zoom_button_width = 120
    zoom_button_height = 20
    zoom_button_x = panel_pos.x + (panel_width - zoom_button_width) / 2
    zoom_button_y = button_pos.y - zoom_button_height - 5
    
    zoom_button_pos = ImVec2(zoom_button_x, zoom_button_y)
    zoom_button_end = ImVec2(zoom_button_x + zoom_button_width, zoom_button_y + zoom_button_height)
    
    # Check if mouse is over button
    zoom_reset_hovered = mouse_pos_screen.x >= zoom_button_pos.x && mouse_pos_screen.x <= zoom_button_end.x &&
                     mouse_pos_screen.y >= zoom_button_pos.y && mouse_pos_screen.y <= zoom_button_end.y
    
    # Button background color changes when hovered
    zoom_button_color = zoom_reset_hovered ? IM_COL32(100, 120, 180, 255) : IM_COL32(70, 90, 150, 255)
    
    CImGui.AddRectFilled(draw_list, zoom_button_pos, zoom_button_end, zoom_button_color, 3.0)
    CImGui.AddRect(draw_list, zoom_button_pos, zoom_button_end, IM_COL32(120, 140, 200, 255), 3.0)
    
    # Button text
    zoom_text = "Reset Zoom"
    zoom_text_size = CImGui.CalcTextSize(zoom_text)
    zoom_text_pos = ImVec2(zoom_button_pos.x + (zoom_button_width - zoom_text_size.x) / 2, 
                       zoom_button_pos.y + (zoom_button_height - zoom_text_size.y) / 2)
    
    CImGui.AddText(draw_list, zoom_text_pos, IM_COL32(255, 255, 255, 255), zoom_text)
    
    # Check for button click
    if zoom_reset_hovered && CImGui.IsMouseClicked(CImGui.ImGuiMouseButton_Left)
        # Reset zoom level to 1.0
        zoom_level[] = 1.0
    end
end

"""
    get_nearest_ui_element(main, canvas_p0, camPos, mouse_pos_in_canvas_zoom_adjusted)

Gets the nearest UI element to the mouse click position in the scene viewer.
"""
function get_nearest_ui_element(main, canvas_p0, camPos, mouse_pos_in_canvas_zoom_adjusted)
    if main === nothing || main.scene === nothing
        return nothing
    end
    
    camera = main.scene.camera
    if camera === nothing
        return nothing
    end
    
    scale_factor = 64.0
    camera_world_pos = Math.Vector2f(camera.position.x, camera.position.y)
    
    nearest_ui_element = nothing
    min_distance = Inf
    
    for ui_element in main.scene.uiElements
        if !ui_element.isActive
            continue
        end
        
        # Convert UI element screen position to world position relative to camera
        ui_world_pos = Math.Vector2f(
            camera_world_pos.x + (ui_element.position.x / 64.0),
            camera_world_pos.y + (ui_element.position.y / 64.0)
        )
        
        # Check if mouse click is within UI element bounds
        ui_size_world = Math.Vector2f(
            ui_element.size.x / 64.0,
            ui_element.size.y / 64.0
        )
        
        # Convert mouse position to world coordinates (similar to entities)
        mouse_world_x = mouse_pos_in_canvas_zoom_adjusted.x / scale_factor + camPos.x / scale_factor
        mouse_world_y = mouse_pos_in_canvas_zoom_adjusted.y / scale_factor + camPos.y / scale_factor
        
        # Check if mouse is within UI element bounds
        if mouse_world_x >= ui_world_pos.x && 
           mouse_world_x <= ui_world_pos.x + ui_size_world.x &&
           mouse_world_y >= ui_world_pos.y && 
           mouse_world_y <= ui_world_pos.y + ui_size_world.y
            
            # Calculate distance to center of UI element
            center_x = ui_world_pos.x + ui_size_world.x / 2
            center_y = ui_world_pos.y + ui_size_world.y / 2
            distance = sqrt((mouse_world_x - center_x)^2 + (mouse_world_y - center_y)^2)
            
            if distance < min_distance
                min_distance = distance
                nearest_ui_element = ui_element
            end
        end
    end
    
    return nearest_ui_element
end

"""
    draw_camera_debug_outline(draw_list, canvas_p0, camPos, zoom_level, camera, scene_camera)
    
Draws a debug outline showing the camera viewport in the scene viewer.
"""
function draw_camera_debug_outline(draw_list, canvas_p0, camPos, zoom_level, camera, scene_camera)
    # Use engine's pixels-per-unit for consistency
    ppu = JulGame.SCALE_UNITS
    scale_factor = ppu * zoom_level[]
    
    # Draw camera viewport in world space: subtract (camera.position + camera.offset)
    screen_pos = Math.Vector2f(
        canvas_p0.x - ((camera.position.x + camera.offset.x) * scale_factor) + ((scene_camera.position.x + scene_camera.offset.x) * scale_factor),
        canvas_p0.y - ((camera.position.y + camera.offset.y) * scale_factor) + ((scene_camera.position.y + scene_camera.offset.y) * scale_factor)
    )
    
    # Viewport size: camera.size (pixels) scaled by zoom to match scene zooming
    screen_size = Math.Vector2f(
        scene_camera.size.x * zoom_level[],
        scene_camera.size.y * zoom_level[]
    )

    # Debug: validate camera size and computed screen size
    @debug "Camera viewport size (pixels): $(camera.size.x) x $(camera.size.y)"
    @debug "Computed camera outline size (screen): $(screen_size.x) x $(screen_size.y) at zoom $(zoom_level[])"
    
    # Draw camera outline in cyan
    camera_color = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(0.0, 1.0, 1.0, 0.8))
    CImGui.AddRect(
        draw_list,
        CImGui.ImVec2(screen_pos.x, screen_pos.y),
        CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
        camera_color,
        0.0,
        CImGui.ImDrawFlags_None,
        2.0
    )
    
    # Add label
    CImGui.AddText(
        draw_list,
        CImGui.ImVec2(screen_pos.x + 5, screen_pos.y + 5),
        camera_color,
        "Camera Viewport"
    )
end

"""
    render_ui_elements_in_scene(main, draw_list, canvas_p0, camPos, zoom_level, camera)

Renders UI elements in the scene viewer with camera-relative positioning.
"""
function render_ui_elements_in_scene(main, draw_list, canvas_p0, camPos, zoom_level, camera)
    scale_factor = 64.0 * zoom_level[]
    
    # Calculate camera viewport in world coordinates
    camera_world_pos = Math.Vector2f(camera.position.x, camera.position.y)
    
    for ui_element in main.scene.uiElements
        if !ui_element.isActive
            continue
        end
        
        # UI elements are in pixels; render them like world by subtracting camera (in pixels), then zoom
        screen_pos = Math.Vector2f(
            canvas_p0.x + (ui_element.position.x * zoom_level[]) - ((camera.position.x + camera.offset.x) * 64.0 * zoom_level[]),
            canvas_p0.y + (ui_element.position.y * zoom_level[]) - ((camera.position.y + camera.offset.y) * 64.0 * zoom_level[])
        )
        
        # Convert UI element size to world scale
        ui_screen_size = Math.Vector2f(
            ui_element.size.x * zoom_level[],
            ui_element.size.y * zoom_level[]
        )
        
        # Render different UI element types
        render_ui_element_in_world_space(ui_element, draw_list, screen_pos, ui_screen_size)
    end
end

"""
    render_ui_element_in_world_space(ui_element, draw_list, screen_pos, screen_size)

Renders a specific UI element type in world space coordinates.
"""
function render_ui_element_in_world_space(ui_element, draw_list, screen_pos, screen_size)
    # Get UI element color
    color = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(
        ui_element.color[1]/255.0,
        ui_element.color[2]/255.0,
        ui_element.color[3]/255.0,
        ui_element.color[4]/255.0
    ))
    
    # Render based on UI element type
    if isa(ui_element, JulGame.UI.UIImageModule.UIImage)
        # Ensure texture is initialized
        if ui_element.texture == C_NULL && ui_element.surface != C_NULL
            try
                JulGame.UI.initialize(ui_element)
            catch
            end
        end
        if ui_element.texture != C_NULL
            CImGui.AddImage(
                draw_list,
                ui_element.texture,
                CImGui.ImVec2(screen_pos.x, screen_pos.y),
                CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
                CImGui.ImVec2(0, 0),
                CImGui.ImVec2(1, 1),
                color
            )
            return
        end
        # Fallback to block-out if no texture
        CImGui.AddRectFilled(
            draw_list,
            CImGui.ImVec2(screen_pos.x, screen_pos.y),
            CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
            color
        )
        return
    end
    
    if isa(ui_element, JulGame.UI.ScreenButtonModule.ScreenButton)
        # Draw button as filled rectangle with border
        CImGui.AddRectFilled(
            draw_list,
            CImGui.ImVec2(screen_pos.x, screen_pos.y),
            CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
            color
        )
        
        # Draw border
        border_color = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(0.8, 0.8, 0.8, 1.0))
        CImGui.AddRect(
            draw_list,
            CImGui.ImVec2(screen_pos.x, screen_pos.y),
            CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
            border_color,
            0.0,
            CImGui.ImDrawFlags_None,
            1.0
        )
        
        # Draw text if available
        if !isempty(ui_element.text)
            text_color = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(
                ui_element.textColor[1]/255.0,
                ui_element.textColor[2]/255.0,
                ui_element.textColor[3]/255.0,
                ui_element.textColor[4]/255.0
            ))
            CImGui.AddText(
                draw_list,
                CImGui.ImVec2(screen_pos.x + 5, screen_pos.y + screen_size.y/2 - 8),
                text_color,
                ui_element.text
            )
        end
        
    elseif isa(ui_element, JulGame.UI.RectangleModule.Rectangle)
        if ui_element.fillMode
            # Draw filled rectangle
            CImGui.AddRectFilled(
                draw_list,
                CImGui.ImVec2(screen_pos.x, screen_pos.y),
                CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
                color,
                Float32(ui_element.borderRadius)
            )
        else
            # Draw outline rectangle
            CImGui.AddRect(
                draw_list,
                CImGui.ImVec2(screen_pos.x, screen_pos.y),
                CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
                color,
                Float32(ui_element.borderRadius),
                CImGui.ImDrawFlags_None,
                Float32(ui_element.borderWidth)
            )
        end
        
    elseif isa(ui_element, JulGame.UI.TextBoxModule.TextBox)
        # Draw text box as filled rectangle with border
        CImGui.AddRectFilled(
            draw_list,
            CImGui.ImVec2(screen_pos.x, screen_pos.y),
            CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
            color
        )
        
        # Draw border
        border_color = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(0.6, 0.6, 0.6, 1.0))
        CImGui.AddRect(
            draw_list,
            CImGui.ImVec2(screen_pos.x, screen_pos.y),
            CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
            border_color,
            0.0,
            CImGui.ImDrawFlags_None,
            1.0
        )
        
    else
        # Default rendering for other UI element types
        CImGui.AddRectFilled(
            draw_list,
            CImGui.ImVec2(screen_pos.x, screen_pos.y),
            CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
            color
        )
        
        # Draw border to distinguish it
        border_color = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(1.0, 1.0, 0.0, 0.8))
        CImGui.AddRect(
            draw_list,
            CImGui.ImVec2(screen_pos.x, screen_pos.y),
            CImGui.ImVec2(screen_pos.x + screen_size.x, screen_pos.y + screen_size.y),
            border_color,
            0.0,
            CImGui.ImDrawFlags_None,
            2.0
        )
    end
    
    # Add UI element label
    label_color = CImGui.ColorConvertFloat4ToU32(CImGui.ImVec4(1.0, 1.0, 1.0, 0.9))
    CImGui.AddText(
        draw_list,
        CImGui.ImVec2(screen_pos.x, screen_pos.y - 15),
        label_color,
        "UI: $(ui_element.name)"
    )
end

"""
    handle_ui_element_manipulation_in_scene(ui_element, canvas_p0, camPos, zoom_level, camera)

Handles manipulation arrows for a UI element in the scene viewer.
"""
function handle_ui_element_manipulation_in_scene(ui_element, canvas_p0, camPos, zoom_level, camera)
    scale_factor = 64.0 * zoom_level[]
    
    # Calculate camera viewport in world coordinates
    camera_world_pos = Math.Vector2f(camera.position.x, camera.position.y)
    
    # Same mapping as render: camera-relative pixels then zoom
    screen_pos = Math.Vector2(
        round(Int, canvas_p0.x + (ui_element.position.x * zoom_level[]) - ((camera.position.x + camera.offset.x) * 64.0 * zoom_level[])),
        round(Int, canvas_p0.y + (ui_element.position.y * zoom_level[]) - ((camera.position.y + camera.offset.y) * 64.0 * zoom_level[]))
    )
    
    # Convert screen position to window-relative coordinates for ImGui
    window_pos = CImGui.GetWindowPos()
    cursor_pos = CImGui.ImVec2(
        screen_pos.x - window_pos.x,
        screen_pos.y - window_pos.y
    )
    
    # Set cursor position relative to window
    CImGui.SetCursorPos(cursor_pos)
    
    # Create a dummy item to represent the UI element for manipulation
    ui_screen_size = Math.Vector2(ui_element.size.x * zoom_level[], ui_element.size.y * zoom_level[])
    CImGui.Dummy(CImGui.ImVec2(ui_screen_size.x, ui_screen_size.y))
    
    # Handle position manipulation
    if SCENE_MANIPULATION_STATE.manipulation_mode == Position || SCENE_MANIPULATION_STATE.manipulation_mode == Both
        # Use window-relative coordinates for manipulation arrows
        screen_pos_ref = Ref(Math.Vector2f(
            Float32(cursor_pos.x),
            Float32(cursor_pos.y)
        ))
        
        original_screen_pos = screen_pos_ref[]
        if draw_position_arrows(screen_pos_ref, Int(SCENE_MANIPULATION_STATE.grid_snap))
            # Calculate the screen space delta
            screen_delta = screen_pos_ref[] - original_screen_pos
            
            # Convert screen delta back to UI element screen coordinates
            ui_delta_x = screen_delta.x / zoom_level[]
            ui_delta_y = screen_delta.y / zoom_level[]
            
            # Apply the delta to the UI element position
            new_ui_pos = Math.Vector2(
                ui_element.position.x + ui_delta_x,
                ui_element.position.y + ui_delta_y
            )
            ui_element.position = new_ui_pos
            # Mark scene as modified
            JulGame.EditorState["scene_modified"] = true
        end
    end
    
    # Handle scale manipulation
    if SCENE_MANIPULATION_STATE.manipulation_mode == Scale || SCENE_MANIPULATION_STATE.manipulation_mode == Both
        # Convert UI element size to screen pixels for manipulation
        screen_scale = Math.Vector2f(
            ui_element.size.x * zoom_level[],
            ui_element.size.y * zoom_level[]
        )
        scale_ref = Ref(screen_scale)
        
        # Use the same window-relative coordinates as position arrows
        widget_pos = Math.Vector2f(cursor_pos.x, cursor_pos.y)
        draw_resize_handles(widget_pos, scale_ref, Int(SCENE_MANIPULATION_STATE.grid_snap), Default)
        
        # Convert screen scale back to UI element size
        new_ui_size = Math.Vector2(
            scale_ref[].x / zoom_level[],
            scale_ref[].y / zoom_level[]
        )
        
        if new_ui_size != Math.Vector2(ui_element.size.x, ui_element.size.y)
            ui_element.size = new_ui_size
            # Mark scene as modified
            JulGame.EditorState["scene_modified"] = true
        end
    end
end