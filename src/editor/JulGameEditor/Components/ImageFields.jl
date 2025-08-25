function show_image_fields(selectedImage, imageField)
    fieldName = getFieldName1(imageField)
    unusedFields = ["texture", "sprite", "isInitialized"]
    if fieldName in unusedFields
        return
    end
    Value = getfield(selectedImage, imageField)

    if fieldName == "imagePath" || fieldName == "name" 
        buf = "$(Value)"*"\\0"^(64)
        CImGui.InputText("$(imageField)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = eachindex(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setfield!(selectedImage, imageField, currentTextInTextBox)
        
        if currentTextInTextBox != Value && fieldName == "imagePath"
            # Update the image when path changes
            JulGame.ImageModule.update_image_path(selectedImage, currentTextInTextBox)
        end

    elseif fieldName == "color"
        x = Cfloat(Value[1]/255.0)
        y = Cfloat(Value[2]/255.0)
        z = Cfloat(Value[3]/255.0)
        w = Cfloat(Value[4]/255.0)
        @c CImGui.ColorEdit4("$(imageField)", &x, &y, &z, &w)
        
        new_color = (convert(Int32, round(x*255)), convert(Int32, round(y*255)), convert(Int32, round(z*255)), convert(Int32, round(w*255)))
        setfield!(selectedImage, imageField, new_color)

        if new_color != Value
            # Update color when changed
            JulGame.UI.set_color(selectedImage, r=new_color[1], g=new_color[2], b=new_color[3], a=new_color[4])
        end
    elseif fieldName == "position" || fieldName == "size" || fieldName == "anchorOffset"
        x = Cint(Value.x)
        y = Cint(Value.y)
        @c CImGui.InputInt("$(imageField) x", &x, 1)
        @c CImGui.InputInt("$(imageField) y", &y, 1)
        
        if x != Value.x || y != Value.y
            setfield!(selectedImage, imageField, Vector2(x, y))
        end
    elseif fieldName == "rotation"
        x = Cfloat(Value)
        @c CImGui.SliderFloat("$(imageField)", &x, 0.0, 360.0)
        setfield!(selectedImage, imageField, convert(Float64, x))
    elseif fieldName == "layer"
        x = Cint(Value)
        @c CImGui.InputInt("$(imageField)", &x, 1)
        setfield!(selectedImage, imageField, convert(Int32, x))
    elseif fieldName == "isActive" || fieldName == "isWorldEntity" || fieldName == "persistentBetweenScenes"
        x = Value
        @c CImGui.Checkbox("$(imageField)", &x)
        setfield!(selectedImage, imageField, x)
    elseif fieldName == "anchor"
        current_anchor = string(Value.current_state)
        anchor_options = ["center", "top", "bottom", "left", "right", "topLeft", "topRight", "bottomLeft", "bottomRight", "centerLeft", "centerRight", "centerTop", "centerBottom", "none"]
        current_index = findfirst(x -> x == current_anchor, anchor_options)
        if current_index === nothing
            current_index = 1
        end
        
        if CImGui.BeginCombo("$(imageField)", current_anchor)
            for (i, option) in enumerate(anchor_options)
                is_selected = (i == current_index)
                if CImGui.Selectable(option, is_selected)
                    Value.current_state = Symbol(option)
                end
                if is_selected
                    CImGui.SetItemDefaultFocus()
                end
            end
            CImGui.EndCombo()
        end
    else
        CImGui.Text("$(imageField): $(Value)")
    end
end

function show_image_fields1(selectedImage)
    for imageField in fieldnames(typeof(selectedImage))
        show_image_fields(selectedImage, imageField)
    end
end