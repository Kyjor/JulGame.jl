using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using julGame

function ShowTextBoxField(selectedTextBox, textBoxField)
    fieldName = getFieldName(textBoxField)
    Value = getfield(selectedTextBox, textBoxField)

    if fieldName == "updatedText" || fieldName == "name" 
        buf = "$(Value)"*"\0"^(64)
        CImGui.InputText("$(textBoxField)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = 1:length(buf)
            if Int(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setfield!(selectedTextBox, textBoxField, currentTextInTextBox)
    end
end

function getFieldName(field)
    return "$(field)"
end