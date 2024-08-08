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
function ShowExampleAppCustomRendering(p_open::Ref{Bool})
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

    p = CImGui.GetCursorScreenPos()
    col32 = CImGui.ColorConvertFloat4ToU32(ImVec4(col...))
    begin
        x::Cfloat = p.x + 4.0
        y::Cfloat = p.y + 4.0
        spacing = 8.0
        for n = 0:2-1
            th::Cfloat = (n == 0) ? 1.0 : thickness
            CImGui.AddCircle(draw_list, ImVec2(x+sz*0.5, y+sz*0.5), sz*0.5, col32, 6, th); x += sz + spacing; # hexagon
            CImGui.AddCircle(draw_list, ImVec2(x+sz*0.5, y+sz*0.5), sz*0.5, col32, 20, th); x += sz + spacing; # circle
            CImGui.AddRect(draw_list, ImVec2(x, y), ImVec2(x+sz, y+sz), col32, 0.0, CImGui.ImDrawFlags_RoundCornersAll, th); x += sz + spacing;
            CImGui.AddRect(draw_list, ImVec2(x, y), ImVec2(x+sz, y+sz), col32, 10.0, CImGui.ImDrawFlags_RoundCornersAll, th); x += sz + spacing;
            CImGui.AddRect(draw_list, ImVec2(x, y), ImVec2(x+sz, y+sz), col32, 10.0, CImGui.ImDrawFlags_RoundCornersTopLeft | CImGui.ImDrawFlags_RoundCornersBottomRight, th); x += sz + spacing;
            CImGui.AddTriangle(draw_list, ImVec2(x+sz*0.5, y), ImVec2(x+sz,y+sz-0.5), ImVec2(x,y+sz-0.5), col32, th); x += sz + spacing;
            CImGui.AddLine(draw_list, ImVec2(x, y), ImVec2(x+sz,    y), col32, th); x += sz + spacing;  # horizontal line (note: drawing a filled rectangle will be faster!)
            CImGui.AddLine(draw_list, ImVec2(x, y), ImVec2(x,    y+sz), col32, th); x += spacing;       # vertical line (note: drawing a filled rectangle will be faster!)
            CImGui.AddLine(draw_list, ImVec2(x, y), ImVec2(x+sz, y+sz), col32, th); x += sz +spacing;   # diagonal line
            CImGui.AddBezierCubic(draw_list, ImVec2(x, y), ImVec2(x+sz*1.3,y+sz*0.3), (x+sz-sz*1.3,y+sz-sz*0.3), ImVec2(x+sz, y+sz), col32, th);
            x = p.x + 4
            y += sz + spacing
        end
        CImGui.AddCircleFilled(draw_list, ImVec2(x+sz*0.5, y+sz*0.5), sz*0.5, col32, 6); x += sz+spacing; # hexagon
        CImGui.AddCircleFilled(draw_list, ImVec2(x+sz*0.5, y+sz*0.5), sz*0.5, col32, 32); x += sz+spacing; # circle
        CImGui.AddRectFilled(draw_list, ImVec2(x, y), ImVec2(x+sz, y+sz), col32); x += sz+spacing;
        CImGui.AddRectFilled(draw_list, ImVec2(x, y), ImVec2(x+sz, y+sz), col32, 10.0); x += sz+spacing;
        CImGui.AddRectFilled(draw_list, ImVec2(x, y), ImVec2(x+sz, y+sz), col32, 10.0, CImGui.ImDrawFlags_RoundCornersTopLeft | CImGui.ImDrawFlags_RoundCornersBottomRight); x += sz+spacing;
        CImGui.AddTriangleFilled(draw_list, ImVec2(x+sz*0.5, y), ImVec2(x+sz,y+sz-0.5), ImVec2(x,y+sz-0.5), col32); x += sz+spacing;
        CImGui.AddRectFilled(draw_list, ImVec2(x, y), ImVec2(x+sz, y+thickness), col32); x += sz+spacing;          # horizontal line (faster than AddLine, but only handle integer thickness)
        CImGui.AddRectFilled(draw_list, ImVec2(x, y), ImVec2(x+thickness, y+sz), col32); x += spacing+spacing;     # vertical line (faster than AddLine, but only handle integer thickness)
        CImGui.AddRectFilled(draw_list, ImVec2(x, y), ImVec2(x+1, y+1), col32);          x += sz;                  # pixel (faster than AddLine)
        CImGui.AddRectFilledMultiColor(draw_list, ImVec2(x, y), ImVec2(x+sz, y+sz), IM_COL32(0,0,0,255), IM_COL32(255,0,0,255), IM_COL32(255,255,0,255), IM_COL32(0,255,0,255))
        CImGui.Dummy(ImVec2((sz+spacing)*8, (sz+spacing)*3))
    end
    CImGui.Separator()
    @cstatic adding_line=false points=ImVec2[] begin
        CImGui.Text("Canvas example")
        CImGui.Button("Clear") && empty!(points)
        if length(points) ≥ 2
            CImGui.SameLine()
            CImGui.Button("Undo") && (pop!(points); pop!(points);)
        end
        CImGui.Text("Left-click and drag to add lines,\nRight-click to undo")

        # here we are using InvisibleButton() as a convenience to 1) advance the cursor and 2) allows us to use IsItemHovered()
        # but you can also draw directly and poll mouse/keyboard by yourself. You can manipulate the cursor using GetCursorPos() and SetCursorPos().
        # if you only use the ImDrawList API, you can notify the owner window of its extends by using SetCursorPos(max).
        canvas_pos = CImGui.GetCursorScreenPos()            # ImDrawList API uses screen coordinates!
        canvas_size = CImGui.GetContentRegionAvail()        # resize canvas to what's available

        cx, cy = canvas_size.x, canvas_size.y
        cx < 50.0 && (cx = 50.0)
        cy < 50.0 && (cy = 50.0)
        canvas_size = ImVec2(cx, cy)
        CImGui.AddRectFilledMultiColor(draw_list, canvas_pos, ImVec2(canvas_pos.x + canvas_size.x, canvas_pos.y + canvas_size.y), IM_COL32(50, 50, 50, 255), IM_COL32(50, 50, 60, 255), IM_COL32(60, 60, 70, 255), IM_COL32(50, 50, 60, 255))
        CImGui.AddRect(draw_list, canvas_pos, ImVec2(canvas_pos.x + canvas_size.x, canvas_pos.y + canvas_size.y), IM_COL32(255, 255, 255, 255))

        adding_preview = false
        CImGui.InvisibleButton("canvas", canvas_size)
        mouse_x = unsafe_load(CImGui.GetIO().MousePos.x)
        mouse_y = unsafe_load(CImGui.GetIO().MousePos.y)
        mouse_pos_in_canvas = ImVec2(mouse_x - canvas_pos.x, mouse_y - canvas_pos.y)
        if adding_line
            adding_preview = true
            push!(points, mouse_pos_in_canvas)
            !CImGui.IsMouseDown(0) && (adding_line = adding_preview = false;)
        end
        if CImGui.IsItemHovered()
            if !adding_line && CImGui.IsMouseClicked(0)
                push!(points, mouse_pos_in_canvas)
                adding_line = true
            end
            if CImGui.IsMouseClicked(1) && !isempty(points)
                adding_line = adding_preview = false
                pop!(points)
                pop!(points)
            end
        end
        CImGui.PushClipRect(draw_list, canvas_pos, ImVec2(canvas_pos.x + canvas_size.x, canvas_pos.y + canvas_size.y), true) # clip lines within the canvas (if we resize it, etc.)
        @cfor i=1 i<length(points) i+=2 begin
            CImGui.AddLine(draw_list, ImVec2(canvas_pos.x + points[i].x, canvas_pos.y + points[i].y), ImVec2(canvas_pos.x + points[i + 1].x, canvas_pos.y + points[i + 1].y), IM_COL32(255, 255, 0, 255), 2.0)
        end
        CImGui.PopClipRect(draw_list)
        adding_preview && pop!(points)
    end
    CImGui.End()
end
