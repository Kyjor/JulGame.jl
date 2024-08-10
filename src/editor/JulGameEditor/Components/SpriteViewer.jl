using CImGui
using CImGui: ImVec2, ImVec4, IM_COL32, ImU32
using CImGui.CSyntax
using CImGui.CSyntax.CFor
using CImGui.CSyntax.CStatic

function show_sprite(image)
    if CImGui.Begin("imgui_id") 
        draw_list = CImGui.GetWindowDrawList()
        
        # Get the current ImGui cursor position
        canvas_p0 = CImGui.GetCursorScreenPos()    # ImDrawList API uses screen coordinates!
        canvas_size = CImGui.GetContentRegionAvail() # Resize canvas to what's available
        
        # guarantee a minimum canvas size
        canvas_size.x = max(canvas_size.x, 256.0)
        canvas_size.y = max(canvas_size.y, 250.0)
        
        canvas_p1 = ImVec2(canvas_p0.x + canvas_size.x, canvas_p0.y + canvas_size.y)
        
        CImGui.InvisibleButton("##canvas", canvas_size,
            CImGui.ImGuiButtonFlags_MouseButtonLeft | CImGui.ImGuiButtonFlags_MouseButtonRight |
            CImGui.ImGuiButtonFlags_MouseButtonMiddle)
        
        canvas_hovered = CImGui.IsItemHovered() # Hovered
        canvas_active = CImGui.IsItemActive()  # Held
        
        # Draw border and background color
        io = CImGui.GetIO()
        CImGui.AddRectFilled(draw_list, canvas_p0, canvas_p1, CImGui.IM_COL32(50, 50, 50, 255))
        CImGui.AddRect(draw_list, canvas_p0, canvas_p1, CImGui.IM_COL32(255, 255, 255, 255))
        
        # TODO: shift or ctrl to slow zoom movement
        zoom_rate = 0.1
        zoom_mouse = io.MouseWheel * zoom_rate # -0.1 0.0 0.1
        zoom_delta = zoom_mouse * image.transform.scale.x # each step grows or shrinks image by 10%
        
        old_scale = image.transform.scale
        # on screen (top left of image)
        old_origin = ImVec2(canvas_p0.x + image.transform.translate.x,
            canvas_p0.y + image.transform.translate.y)
        # on screen (bottom right of image)
        old_p1 = ImVec2(old_origin.x + (image.width * image.transform.scale.x),
            old_origin.y + (image.height * image.transform.scale.y))
        # on screen (center of what we get to see), when adjusting scale this doesn't change!
        old_and_new_canvas_center = ImVec2(canvas_p0.x + canvas_size.x * 0.5,
            canvas_p0.y + canvas_size.y * 0.5)
        # in image coordinate offset of the center
        image_center = ImVec2(old_and_new_canvas_center.x - old_origin.x,
            old_and_new_canvas_center.y - old_origin.y)
        
        old_uv_image_center = ImVec2(image_center.x / (image.width * image.transform.scale.x),
            image_center.y / (image.height * image.transform.scale.y))
        
        image.transform.scale.x += zoom_delta
        image.transform.scale.y += zoom_delta
        
        # 2.0 -> 2x zoom in
        # 1.0 -> normal
        # 0.5 -> 2x zoom out
        # TODO: clamp based on image size, do we go pixel level?
        image.transform.scale.x = clamp(image.transform.scale.x, 0.01, 100.0)
        image.transform.scale.y = clamp(image.transform.scale.y, 0.01, 100.0)
        
        # on screen new target center
        new_image_center = ImVec2(image.width * image.transform.scale.x * old_uv_image_center.x,
            image.height * image.transform.scale.y * old_uv_image_center.y)
        
        # readjust to center
        image.transform.translate.x -= new_image_center.x - image_center.x
        image.transform.translate.y -= new_image_center.y - image_center.y
        
        # 0 out second parameter if a context menu is open
        if canvas_active && CImGui.IsMouseDragging(CImGui.ImGuiMouseButton_Left, 1.0)
            image.transform.translate.x += io.MouseDelta.x
            image.transform.translate.y += io.MouseDelta.y
        end
        
        origin = ImVec2(canvas_p0.x + image.transform.translate.x,
            canvas_p0.y + image.transform.translate.y) # Lock scrolled origin
        
        # we need to control the rectangle we're going to draw and the uv coordinates
        image_p1 = ImVec2(origin.x + (image.transform.scale.x * image.width),
            origin.y + (image.transform.scale.y * image.height))
        
        mouse_pos_in_canvas = ImVec2(io.MousePos.x - origin.x, io.MousePos.y - origin.y)
        
        CImGui.PushClipRect(draw_list, ImVec2(canvas_p0.x + 2.0, canvas_p0.y + 2.0),
            ImVec2(canvas_p1.x - 2.0, canvas_p1.y - 2.0), true)
        # draw things
        CImGui.AddImage(draw_list, image.texture_id, origin, image_p1)
        # draw things
        CImGui.PopClipRect(draw_list)
    end
    CImGui.End()
end

function load_texture_from_file(filename::String, renderer::Ptr{SDL2.SDL_Renderer})
    width = Ref{Cint}()
    height = Ref{Cint}()
    channels = Ref{Cint}()
    
    surface = SDL2.IMG_Load(filename)
    if surface == C_NULL
        @error "Failed to load image: $(unsafe_string(SDL2.SDL_GetError()))"
        return false, C_NULL, 0, 0
    end
    
    surfaceInfo = unsafe_wrap(Array, surface, 10; own = false)
    width[] = surfaceInfo[1].w
    height[] = surfaceInfo[1].h

    if surface == C_NULL
        @error "Failed to create SDL surface: $(unsafe_string(SDL2.SDL_GetError()))"
        return false, C_NULL, 0, 0
    end
    
    texture_ptr = SDL2.SDL_CreateTextureFromSurface(renderer, surface)
    
    if texture_ptr == C_NULL
        @error "Failed to create SDL texture: $(unsafe_string(SDL2.SDL_GetError()))"
    end
    
    SDL2.SDL_FreeSurface(surface)
    
    return true, texture_ptr, width[], height[] #, data
end


function get_center(rc::CImGui.ImRect)
    return ImVec2((rc.Min.x + rc.Max.x) * 0.5, (rc.Min.y + rc.Max.y) * 0.5)
end

function get_width(rc::CImGui.ImRect)
    return rc.Max.x - rc.Min.x
end

function get_size(rc::CImGui.ImRect)
    return ImVec2(rc.Max.x - rc.Min.x, rc.Max.y - rc.Min.y)
end




"""
    ShowExampleAppCustomRendering(p_open::Ref{Bool})
Demonstrate using the low-level ImDrawList to draw custom shapes.
"""
function ShowExampleAppCustomRendering(p_open::Ref{Bool}, points, scrolling, opt_enable_grid, opt_enable_context_menu, adding_line, my_tex_id, my_tex_w, my_tex_h, zoom_level, grid_step)
    CImGui.SetNextWindowSize((350, 560), CImGui.ImGuiCond_FirstUseEver)
    CImGui.Begin("Example: Custom rendering", p_open) || (CImGui.End(); return)

    draw_list = CImGui.GetWindowDrawList()

    # primitives
    CImGui.Text("Primitives")
    sz, thickness, col = @cstatic sz=Cfloat(36.0) thickness=Cfloat(4.0) col=Cfloat[1.0,1.0,0.4,1.0] begin
        @c CImGui.DragFloat("Size", &sz, 0.2, 2.0, 72.0, "%.0f")
        @c CImGui.DragFloat("Thickness", &thickness, 0.05, 1.0, 8.0, "%.02f")
        CImGui.ColorEdit4("Color", col)
    end


        io = CImGui.GetIO()

        CImGui.Text("$(my_tex_w)x$(my_tex_h)")
        pos = CImGui.GetCursorScreenPos()
        CImGui.Image(my_tex_id, ImVec2(my_tex_w, my_tex_h), (0,0), (1,1), (255,255,255,255), (255,255,255,128))
        if CImGui.IsItemHovered() && unsafe_load(io.KeyShift)
            CImGui.BeginTooltip()
            region_sz = min(32.0, min(my_tex_w, my_tex_h))
            region_x = unsafe_load(io.MousePos).x - pos.x - region_sz * 0.5
            if region_x < 0.0
                region_x = 0.0
            elseif region_x > my_tex_w - region_sz
                region_x = my_tex_w - region_sz
            end
            region_y = unsafe_load(io.MousePos).y - pos.y - region_sz * 0.5
            if region_y < 0.0
                region_y = 0.0
            elseif region_y > my_tex_h - region_sz
                region_y = my_tex_h - region_sz
            end
            zoom = 4.0
            CImGui.Text(string("Min: (%.2f, %.2f)", region_x, region_y))
            CImGui.Text(string("Max: (%.2f, %.2f)", region_x + region_sz, region_y + region_sz))
            uv0 = ImVec2((region_x) / my_tex_w, (region_y) / my_tex_h)
            uv1 = ImVec2((region_x + region_sz) / my_tex_w, (region_y + region_sz) / my_tex_h)
            CImGui.Image(my_tex_id, ImVec2(region_sz * zoom, region_sz * zoom), uv0, uv1, (255,255,255,255), (255,255,255,128))
            CImGui.EndTooltip()
        end
        
    # UI elements
    CImGui.Checkbox("Enable grid", opt_enable_grid)
    CImGui.Checkbox("Enable context menu", opt_enable_context_menu)
    # grid step int input as slider with range. Min = 1, Max = 64
    CImGui.SliderInt("Grid step", grid_step, 1, 64, "%d")
    CImGui.Text("Mouse Left: drag to add lines,\nMouse Right: drag to scroll, click for context menu.")

    # Canvas setup
    canvas_p0 = CImGui.GetCursorScreenPos()  # ImDrawList API uses screen coordinates!
    canvas_sz = CImGui.GetContentRegionAvail()  # Resize canvas to what's available
    canvas_sz = ImVec2(max(canvas_sz.x, 50.0), max(canvas_sz.y, 50.0))
    canvas_p1 = ImVec2(canvas_p0.x + canvas_sz.x, canvas_p0.y + canvas_sz.y)

    canvas_max = ImVec2(my_tex_w * 10, my_tex_h * 10)

    # Draw border and background color
    io = CImGui.GetIO()
    draw_list = CImGui.GetWindowDrawList()
    CImGui.AddRectFilled(draw_list, canvas_p0, canvas_p1, IM_COL32(50, 50, 50, 255))
    CImGui.AddRect(draw_list, canvas_p0, canvas_p1, IM_COL32(255, 255, 255, 255))

    # Invisible button for interactions
    CImGui.InvisibleButton("canvas", canvas_sz, CImGui.ImGuiButtonFlags_MouseButtonLeft | CImGui.ImGuiButtonFlags_MouseButtonRight)
    is_hovered = CImGui.IsItemHovered()  # Hovered
    is_active = CImGui.IsItemActive()  # Held
    # origin = ImVec2(canvas_p0.x + scrolling[].x, canvas_p0.y + scrolling[].y)  # Lock scrolled origin
    scrolling[] = ImVec2(min(scrolling[].x, 0.0), min(scrolling[].y, 0.0))
    scrolling[] = ImVec2(max(scrolling[].x, -canvas_max.x), max(scrolling[].y, -canvas_max.y))
    origin = ImVec2(min(0, 0 + scrolling[].x), min(0, 0 + scrolling[].y))  # Lock scrolled origin
    mouse_pos_in_canvas = ImVec2(unsafe_load(io.MousePos).x - origin.x, unsafe_load(io.MousePos).y - origin.y)

    # Add first and second point
    if is_hovered && !adding_line[] && CImGui.IsMouseClicked(CImGui.ImGuiMouseButton_Left)
        push!(points[], mouse_pos_in_canvas)
        push!(points[], mouse_pos_in_canvas)
        adding_line[] = true
    end
    if adding_line[]
        points[][end] = mouse_pos_in_canvas
        if !CImGui.IsMouseDown(CImGui.ImGuiMouseButton_Left)
            adding_line[] = false
        end
    end

    # Pan
    mouse_threshold_for_pan = opt_enable_context_menu[] ? -1.0 : 0.0
    if is_active && CImGui.IsMouseDragging(CImGui.ImGuiMouseButton_Right, mouse_threshold_for_pan)
        scrolling[] = ImVec2(scrolling[].x + unsafe_load(io.MouseDelta).x, scrolling[].y + unsafe_load(io.MouseDelta).y)
    end

    # Zoom
    if unsafe_load(io.KeyCtrl)
        zoom_level[] += unsafe_load(io.MouseWheel) # * 0.10
        zoom_level[] = clamp(zoom_level[], 1.0, 50.0)
    end

    # Context menu
    drag_delta = CImGui.GetMouseDragDelta(CImGui.ImGuiMouseButton_Right)
    if opt_enable_context_menu[] && CImGui.IsMouseReleased(CImGui.ImGuiMouseButton_Right) && drag_delta.x == 0.0 && drag_delta.y == 0.0
        CImGui.OpenPopupOnItemClick("context")
    end
    if CImGui.BeginPopup("context")
        if adding_line[]
            resize!(points[], length(points[]) - 2)
        end
        adding_line[] = false
        if CImGui.MenuItem("Remove one", "", false, length(points[]) > 0)
            resize!(points[], length(points[]) - 2)
        end
        if CImGui.MenuItem("Remove all", "", false, length(points[]) > 0)
            empty!(points[])
        end
        CImGui.EndPopup()
    end

    # Draw grid and lines
    CImGui.PushClipRect(draw_list, canvas_p0, canvas_p1, true)
    if opt_enable_grid[]
        GRID_STEP = grid_step[] * zoom_level[]

        for x in 0:GRID_STEP:canvas_sz.x*10
            CImGui.AddLine(draw_list, ImVec2(origin.x + canvas_p0.x + x, canvas_p0.y), ImVec2(origin.x + canvas_p0.x + x, canvas_p1.y), IM_COL32(200, 200, 200, 40))
        end
        for y in 0:GRID_STEP:canvas_sz.y*10
            CImGui.AddLine(draw_list, ImVec2(canvas_p0.x, origin.y + canvas_p0.y + y), ImVec2(canvas_p1.x, origin.y + canvas_p0.y + y), IM_COL32(200, 200, 200, 40))
        end
    end

    for n in 1:2:length(points[])-1
        p1 = ImVec2(origin.x + points[][n].x, origin.y + points[][n].y)
        p2 = ImVec2(origin.x + points[][n+1].x, origin.y + points[][n+1].y)
        CImGui.AddLine(draw_list, p1, p2, IM_COL32(255, 255, 0, 255), 2.0)
    end
    
    CImGui.AddImage(draw_list, my_tex_id, ImVec2(origin.x + canvas_p0.x, origin.y + canvas_p0.y), ImVec2(origin.x + (my_tex_w * zoom_level[]) + canvas_p0.x, origin.y + (my_tex_h * zoom_level[]) + canvas_p0.y), ImVec2(0,0), ImVec2(1,1), IM_COL32(255,255,255,255))
    CImGui.PopClipRect(draw_list)

    CImGui.End()
end

# function ImDrawList_AddImage(self, user_texture_id, p_min, p_max, uv_min, uv_max, col)
#     ccall((:ImDrawList_AddImage, libcimgui), Cvoid, (Ptr{ImDrawList}, ImTextureID, ImVec2, ImVec2, ImVec2, ImVec2, ImU32), self, user_texture_id, p_min, p_max, uv_min, uv_max, col)
# end

# function ImDrawList_AddLine(self, p1, p2, col, thickness)
#     ccall((:ImDrawList_AddLine, libcimgui), Cvoid, (Ptr{ImDrawList}, ImVec2, ImVec2, ImU32, Cfloat), self, p1, p2, col, thickness)
# end