
"""
    text_input_single_line(name::String, filters = CImGui.ImGuiInputTextFlags_None)

Create a single-line text input field.

# Arguments
- `name::String`: The name of the text input field.
- `filters`: Optional. The ImGui filters to apply to the text input field.

# Returns
- `currentText`: The current text entered in the text input field.

"""
function text_input_single_line(name::String, currentText; maxBuf=128, filters = CImGui.ImGuiInputTextFlags_None)
    buf="$(currentText[])"*"\0"^maxBuf 
    CImGui.PushID(name)
    CImGui.InputText(name, buf, length(buf), filters)
    for characterIndex = eachindex(buf)
        if Int32(buf[characterIndex]) == 0 # The end of the buffer will be recognized as a 0
            currentText[] = characterIndex == 1 ? "" : String(SubString(buf, 1, characterIndex - 1))
            break
        end
    end
    CImGui.PopID()
    return currentText[]
end