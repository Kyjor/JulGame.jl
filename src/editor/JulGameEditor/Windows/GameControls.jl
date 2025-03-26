function show_game_controls()
    @cstatic begin
        CImGui.Begin("Controls")  
            # Add a flashing "PLAY MODE" indicator if in play mode
            if JulGame.IS_EDITOR_PLAY_MODE
                # Calculate pulsing alpha value (0.5 to 1.0) based on time
                pulsing_alpha = 0.5 + 0.5 * sin(Float64(SDL2.SDL_GetTicks()) / 300.0)
                
                # Push style colors for the indicator
                CImGui.PushStyleColor(CImGui.ImGuiCol_Text, (1.0, 0.1, 0.1, pulsing_alpha))
                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.3, 0.0, 0.0, 0.7))
                
                # Center text width
                text = "PLAYING MODE ACTIVE"
                text_width = CImGui.CalcTextSize(text).x
                window_width = CImGui.GetWindowWidth()
                
                CImGui.SetCursorPosX((window_width - text_width) * 0.5)
                
                if CImGui.Button(text)
                    # Do nothing, but make it a button for visual effect
                end
                
                CImGui.PopStyleColor(2)
                CImGui.Separator()
            end
            
            CImGui.Text("Pan scene: Hold right mouse button and move mouse")
            CImGui.NewLine()
            CImGui.Text("Select entity: Click on entity in scene window or in hierarchy window")
            CImGui.NewLine()
            CImGui.Text("Move entity: Hold left mouse button and drag entity")
            CImGui.NewLine()
            CImGui.Text("Duplicate entity: Select entity and click 'Duplicate' in hierarchy window or press 'LCTRL+D' keys")
            CImGui.NewLine()
            CImGui.Text("Duplicate entity brush: Select entity and press 'Shift+LCTRL+D' keys to activate and deactivate")
        CImGui.End()
    end
end
