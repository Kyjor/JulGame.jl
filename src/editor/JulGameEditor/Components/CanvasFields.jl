function show_canvas_fields(selectedCanvas, canvasField)
    fieldName = getFieldName1(canvasField)
    unusedFields = ["children", "clickEvents", "hoverEnterEvents", "hoverExitEvents", "forceClickCheck", "isHovered"]
    
    if fieldName in unusedFields
        return
    end
    
    Value = getproperty(selectedCanvas, canvasField)

    if fieldName == "name" 
        buf = "$(Value)"*"\0"^(64)
        CImGui.InputText("$(canvasField)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = eachindex(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setproperty!(selectedCanvas, canvasField, currentTextInTextBox)

    elseif fieldName == "color"
        color = Value
        colorFloat = (color[1]/255.0, color[2]/255.0, color[3]/255.0, color[4]/255.0)
        @c CImGui.ColorEdit4("$(canvasField)", colorFloat)
        newColor = (Int(round(colorFloat[1] * 255)), Int(round(colorFloat[2] * 255)), Int(round(colorFloat[3] * 255)), Int(round(colorFloat[4] * 255)))
        setproperty!(selectedCanvas, canvasField, newColor)

    elseif fieldName == "position"
        pos = Value
        posFloat = (Float32(pos.x), Float32(pos.y))
        @c CImGui.InputFloat2("$(canvasField)", posFloat)
        newPos = Math.Vector2(Int(round(posFloat[1])), Int(round(posFloat[2])))
        setproperty!(selectedCanvas, canvasField, newPos)

    elseif fieldName == "size"
        size = Value
        sizeFloat = (Float32(size.x), Float32(size.y))
        @c CImGui.InputFloat2("$(canvasField)", sizeFloat)
        newSize = Math.Vector2(Int(round(sizeFloat[1])), Int(round(sizeFloat[2])))
        setproperty!(selectedCanvas, canvasField, newSize)

    elseif fieldName == "anchorOffset"
        offset = Value
        offsetFloat = (Float32(offset.x), Float32(offset.y))
        @c CImGui.InputFloat2("$(canvasField)", offsetFloat)
        newOffset = Math.Vector2(Int(round(offsetFloat[1])), Int(round(offsetFloat[2])))
        setproperty!(selectedCanvas, canvasField, newOffset)

    elseif fieldName == "layer"
        x = Cint(Value)
        @c CImGui.SliderInt("$(canvasField)", &x, -100, 100)
        setproperty!(selectedCanvas, canvasField, convert(Int32, round(x)))

    elseif fieldName == "rotation"
        x = Cfloat(Value)
        @c CImGui.SliderFloat("$(canvasField)", &x, 0.0, 360.0)
        setproperty!(selectedCanvas, canvasField, convert(Float64, x))

    elseif fieldName == "isActive"
        x = Bool(Value)
        @c CImGui.Checkbox("$(canvasField)", &x)
        setproperty!(selectedCanvas, canvasField, x)

    elseif fieldName == "isVisible"
        x = Bool(Value)
        @c CImGui.Checkbox("$(canvasField)", &x)
        setproperty!(selectedCanvas, canvasField, x)

    elseif fieldName == "clipChildren"
        x = Bool(Value)
        @c CImGui.Checkbox("$(canvasField)", &x)
        setproperty!(selectedCanvas, canvasField, x)

    elseif fieldName == "isWorldEntity"
        x = Bool(Value)
        @c CImGui.Checkbox("$(canvasField)", &x)
        setproperty!(selectedCanvas, canvasField, x)

    elseif fieldName == "persistentBetweenScenes"
        x = Bool(Value)
        @c CImGui.Checkbox("$(canvasField)", &x)
        setproperty!(selectedCanvas, canvasField, x)

    elseif fieldName == "anchor"
        anchorStates = ["center", "top", "bottom", "left", "right", "topLeft", "topRight", "bottomLeft", "bottomRight", "centerLeft", "centerRight", "centerTop", "centerBottom", "none"]
        currentState = Value.current_state
        currentIndex = findfirst(x -> x == currentState, anchorStates)
        if currentIndex === nothing
            currentIndex = 1
        end
        
        @c CImGui.Combo("$(canvasField)", &currentIndex, anchorStates, length(anchorStates))
        newState = Symbol(anchorStates[currentIndex])
        setproperty!(selectedCanvas, canvasField, JulGame.Enum{Any}(
            :center, :top, :bottom, :left, :right, :topLeft, :topRight, :bottomLeft, :bottomRight, 
            :centerLeft, :centerRight, :centerTop, :centerBottom, :none
        ))
        selectedCanvas.anchor.current_state = newState

    else
        CImGui.Text("$(fieldName): $(Value)")
    end
end

function show_canvas_fields1(canvas)
    fields = []
    for field in fieldnames(typeof(canvas))
        push!(fields, field)
    end
    for field in fieldnames(UI.UIElementInstance)
        push!(fields, field)
    end
    
    for field in fields
        fieldString = "$(field)"

        if fieldString == "children"
            CImGui.Text("Children: $(length(canvas.children))")
            if CImGui.TreeNode("Children")
                for (i, child) in enumerate(canvas.children)
                    CImGui.Text("$(i): $(child.name) ($(typeof(child)))")
                end
                CImGui.TreePop()
            end
        else 
            show_canvas_fields(canvas, field)
        end  
    end
end
