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