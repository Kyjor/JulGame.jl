using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using julGame

function ShowTextBoxField(selectedTextBox, textBoxField)
    fieldName = getFieldName(textBoxField)
    Value = getfield(selectedTextBox, textBoxField)

    if fieldName == "text" || fieldName == "name" 
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
        if currentTextInTextBox != Value
            selectedTextBox.isTextUpdated = true
        end

    elseif fieldName == "alpha"
        x = Cint(Value)
        @c CImGui.SliderInt("$(textBoxField)", &x, 0, 255)
        setfield!(selectedTextBox, textBoxField, convert(Int64, round(x)))

        if x != Value
            selectedTextBox.isTextUpdated = true
        end

    elseif fieldName == "color"
        x = Cfloat(Value.r)
        y = Cfloat(Value.g)
        z = Cfloat(Value.b)
        w = Cfloat(Value.a)
        @c CImGui.ColorEdit4("$(textBoxField)", &x, &y, &z, &w)
        setfield!(selectedTextBox, textBoxField, Color(convert(Integer, round(x)), convert(Integer, round(y)), convert(Integer, round(z)), convert(Integer, round(w))))

        if x != Value.r || y != Value.g || z != Value.b || w != Value.a
            selectedTextBox.isTextUpdated = true
        end
    elseif fieldName == "position" || fieldName == "size"
        x = Cint(Value.x)
        y = Cint(Value.y)
        @c CImGui.InputInt("$(textBoxField) x", &x, 1)
        @c CImGui.InputInt("$(textBoxField) y", &y, 1)
        
        if x != Value.x || y != Value.y
            selectedTextBox.setVector2Value(textBoxField, convert(Float64, x), convert(Float64, y))
            selectedTextBox.isTextUpdated = true
        end
    elseif fieldName == "autoSizeText" || fieldName == "isCentered"
        @c CImGui.Checkbox("$(textBoxField)", &Value)

        if Value != getfield(selectedTextBox, textBoxField)
            selectedTextBox.isTextUpdated = true
            setfield!(selectedTextBox, textBoxField, Value)
        end
    end
end

function getFieldName(field)
    return "$(field)"
end