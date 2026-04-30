function show_game_window(scene_tex_id)::Tuple{ImVec2, ImVec2}
    # Add a more noticeable title when in play mode
    if JulGame.IS_EDITOR_PLAY_MODE
        CImGui.PushStyleColor(CImGui.ImGuiCol_TitleBg, (0.8, 0.1, 0.1, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_TitleBgActive, (0.9, 0.2, 0.2, 1.0))
        CImGui.Begin("Game") || (CImGui.PopStyleColor(2); CImGui.End(); return ImVec2(0,0), ImVec2(0,0))
        CImGui.PopStyleColor(2)
    else
        CImGui.Begin("Game") || (CImGui.End(); return ImVec2(0,0), ImVec2(0,0))
    end
    
    draw_list = CImGui.GetWindowDrawList()
    
    # UI elements
    # Canvas setup
    canvas_p0 = CImGui.GetCursorScreenPos()  # ImDrawList API uses screen coordinates!
    canvas_sz = CImGui.GetContentRegionAvail()  # Resize canvas to what's available

    # Store the available size for potential use elsewhere if needed (though raw canvas size might be less useful than scaled size)
    JulGame.EditorGameWindowSize = JulGame.Math.Vector2(canvas_sz.x, canvas_sz.y)

    # Get the texture dimensions
    w, h = Ref{Int32}(0), Ref{Int32}(0)
    SDL2.SDL_QueryTexture(scene_tex_id, Ref{UInt32}(0), Ref{Int32}(0), w, h)
    
    scaled_width = 0.0
    scaled_height = 0.0
    image_p0 = ImVec2(0,0) # Initialize to prevent potential errors if texture query fails

    if w[] > 0 && h[] > 0 # Ensure valid texture dimensions
        # Calculate aspect ratios
        texture_aspect = Float64(w[]) / Float64(h[]) # Use Float64 for precision
        canvas_aspect = canvas_sz.x / canvas_sz.y

        # Calculate the scaled dimensions that maintain aspect ratio
        if texture_aspect > canvas_aspect
            # Fit to width
            scaled_width = canvas_sz.x
            scaled_height = canvas_sz.x / texture_aspect
        else
            # Fit to height
            scaled_height = canvas_sz.y
            scaled_width = canvas_sz.y * texture_aspect
        end
        
        # Center the image in the canvas
        image_p0 = ImVec2(
            canvas_p0.x + (canvas_sz.x - scaled_width) / 2,
            canvas_p0.y + (canvas_sz.y - scaled_height) / 2
        )
        image_p1 = ImVec2(
            image_p0.x + scaled_width,
            image_p0.y + scaled_height
        )

        # Update global variables with the actual rendered image position and size
        JulGame.EditorGameViewPosition = Vector2(image_p0.x, image_p0.y)
        JulGame.EditorGameViewSize = Vector2(scaled_width, scaled_height)

        # Draw border and background color
        draw_list = CImGui.GetWindowDrawList()
        
        CImGui.AddRectFilled(draw_list, canvas_p0, ImVec2(canvas_p0.x + canvas_sz.x, canvas_p0.y + canvas_sz.y), IM_COL32(50, 50, 50, 255))
        try
            # Set tint color based on play mode
            tint_color = JulGame.IS_EDITOR_PLAY_MODE ? IM_COL32(255, 255, 255, 255) : IM_COL32(255, 255, 255, 255)
            CImGui.AddImage(draw_list, scene_tex_id, image_p0, image_p1, ImVec2(0,0), ImVec2(1,1), tint_color)
        catch ex
             @error "Error rendering game view texture:" exception=(ex, catch_backtrace())
        end
        CImGui.AddRect(draw_list, canvas_p0, ImVec2(canvas_p0.x + canvas_sz.x, canvas_p0.y + canvas_sz.y), IM_COL32(255, 255, 255, 255))

        # Add a semi-transparent red overlay in play mode
        if JulGame.IS_EDITOR_PLAY_MODE
            # Add a red border to make it more obvious we're in play mode
            border_thickness = 4.0
            CImGui.AddRect(draw_list, 
                         ImVec2(canvas_p0.x - border_thickness, canvas_p0.y - border_thickness), 
                         ImVec2(canvas_p0.x + canvas_sz.x + border_thickness, canvas_p0.y + canvas_sz.y + border_thickness), 
                         IM_COL32(255, 50, 50, 255), 
                         0.0,  # rounding 
                         0,    # flags
                         border_thickness)
        end
    else
        # Handle case where texture might not be valid yet or has zero dimensions
         CImGui.Text("Waiting for game texture...")
         JulGame.EditorGameViewPosition = Vector2(canvas_p0.x, canvas_p0.y) # Still update position
         JulGame.EditorGameViewSize = Vector2(0,0) # No size
    end

    CImGui.End()

    # Return canvas size and image top-left position (though globals are now preferred)
    return canvas_sz, image_p0
end