function display_confirmation_dialog()
    if get(JulGame.EditorState, DELETE_CONFIRMATION, nothing) !== nothing
        CImGui.OpenPopup(CONFIRMATION_DIALOG)
    end

    if CImGui.BeginPopup(CONFIRMATION_DIALOG)
        CImGui.Text("Are you sure you want to delete this?")
        CImGui.SameLine()
        if CImGui.Button("Yes", (120, 0))
            if JulGame.EditorState[DELETE_CONFIRMATION] !== nothing
                JulGame.EditorState[DELETE_CONFIRMATION]()
            end
            JulGame.EditorState[DELETE_CONFIRMATION] = nothing
            CImGui.CloseCurrentPopup()
        end
        CImGui.SameLine()
        if CImGui.Button("No", (120, 0))
            JulGame.EditorState[DELETE_CONFIRMATION] = nothing
            CImGui.CloseCurrentPopup()
        end
        CImGui.EndPopup()
    end
end