using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic

function show_help_marker(desc)
    CImGui.TextDisabled("(?)")
    hover_tooltip(desc)
end

function hover_tooltip(desc)
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowMinSize, CImGui.ImVec2(5, 5))
    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowPadding, CImGui.ImVec2(5, 5))
    if CImGui.IsItemHovered()
        CImGui.BeginTooltip()
        CImGui.PushTextWrapPos(CImGui.GetFontSize() * 35.0)
        CImGui.TextUnformatted(desc)
        CImGui.PopTextWrapPos()
        CImGui.EndTooltip()
    end
    CImGui.PopStyleVar(2)
end