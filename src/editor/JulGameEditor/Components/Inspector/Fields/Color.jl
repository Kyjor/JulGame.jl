function edit_color(label::String, color::NTuple{4, Int})
    colorCfloat = Cfloat[color[1]/255, color[2]/255, color[3]/255, color[4]/255]

    # Configure color editor options
    alpha_preview = true
    alpha_half_preview = true
    drag_and_drop = true
    options_menu = true
    hdr = false
    
    show_help_marker("Right-click on the individual color widget to show options.")
    CImGui.SameLine()

    misc_flags = (hdr ? CImGui.ImGuiColorEditFlags_HDR : 0) |
                 (drag_and_drop ? 0 : CImGui.ImGuiColorEditFlags_NoDragDrop) |
                 (alpha_half_preview ? CImGui.ImGuiColorEditFlags_AlphaPreviewHalf : 
                 (alpha_preview ? CImGui.ImGuiColorEditFlags_AlphaPreview : 0)) |
                 (options_menu ? 0 : CImGui.ImGuiColorEditFlags_NoOptions) |
                 CImGui.ImGuiColorEditFlags_AlphaBar

    CImGui.ColorEdit4(label, colorCfloat, CImGui.ImGuiColorEditFlags_DisplayRGB | misc_flags)

    if CImGui.IsItemEdited()
        return (Int(abs(round(colorCfloat[1] * 255))), 
                Int(abs(round(colorCfloat[2] * 255))), 
                Int(abs(round(colorCfloat[3] * 255))), 
                Int(abs(round(colorCfloat[4] * 255))))
    end

    return color  # Return original color if not edited
end