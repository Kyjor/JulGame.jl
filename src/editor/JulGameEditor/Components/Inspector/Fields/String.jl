function show_field(structure::EditableStructure, field::Symbol, value::String)
    buf = "$(value)"*"\0"^(64)
    show_field_label(field)
    CImGui.PushItemWidth(-1)  # fill remaining width
    @c CImGui.InputText("##$(string(field))", buf, length(buf))
    CImGui.PopItemWidth()
    
    if buf != value
        # Extract the string up to the first null character
        currentTextInTextBox = ""
        for characterIndex = eachindex(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        
        setfield!(structure, field, currentTextInTextBox)
    end
    
    return buf != value
end