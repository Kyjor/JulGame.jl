
function text_input_single_line(name::String, currentText::String, filter = nothing) #Todo: add type to filter
    @cstatic bufpass="password123"*"\0"^53 begin
    println("Text input single line")
    println("bufpass: ", bufpass)
        CImGui.InputText("password", bufpass, 64, CImGui.ImGuiInputTextFlags_Password | CImGui.ImGuiInputTextFlags_CharsNoBlank)
        CImGui.SameLine()
        ShowHelpMarker("Display all characters as '*'.\nDisable clipboard cut and copy.\nDisable logging.\n")
        CImGui.InputText("password (clear)", bufpass, 64, CImGui.ImGuiInputTextFlags_CharsNoBlank)
    end
end