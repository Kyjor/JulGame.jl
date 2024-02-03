
function text_input_single_line(name::String, currentText::String, filters = CImGui.ImGuiInputTextFlags_None) #Todo: add type to filter
    @cstatic begin
        buf = "$(currentText)"*"\0"^(128)
        CImGui.InputText(name, buf, length(buf), filters)
        for characterIndex = 1:length(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentText = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end

        return currentText
    end
end