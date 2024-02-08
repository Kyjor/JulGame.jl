using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using JulGame
using JulGame.Math

"""
show_field_editor(entity, field)
Creates inputs based on the component type and populates them.
"""
function show_field_editor(entity, fieldName)
    field = getfield(entity, fieldName)
    if field == C_NULL || field === nothing
        return
    end

    if !is_a_julgame_component(field)
        show_component_field_input(entity, fieldName)
        return
    end

    fieldName::String = replace(split("$(typeof(field))", ".")[end], "Internal" => "") # Example: JulGame.ColliderModule.InternalCollider => InternalCollider => Collider
    if CImGui.TreeNode("$(fieldName)") 
        if isa(field, SpriteModule.InternalSprite)
            show_sprite_fields(entity.sprite)
        elseif isa(field, SoundSourceModule.InternalSoundSource)
            show_sound_source_fields(entity.soundSource)
        elseif isa(field, AnimatorModule.InternalAnimator)
            show_animator_properties(entity.animator)
        else
            for field in fieldnames(typeof(field))
                show_component_field_input(getfield(entity, Symbol(lowercase(fieldName))), field)
            end
        end

        CImGui.TreePop()
    end
end

function show_component_field_input(component, componentField)
    componentFieldType = ""
    fieldValue = getfield(component, componentField)
    if isa(fieldValue, Math._Vector2{Float64}) || isa(fieldValue, Math._Vector2{Int32})
        isFloat::Bool = isa(fieldValue, Math._Vector2{Float64}) ? true : false

        x = isFloat ? Cfloat(fieldValue.x) : Cint(fieldValue.x)
        y = isFloat ? Cfloat(fieldValue.y) : Cint(fieldValue.y)
        if CImGui.TreeNode("$(componentField)")
            if isFloat 
                @c CImGui.InputFloat("$(componentField) x", &x, 1)
                @c CImGui.InputFloat("$(componentField) y", &y, 1)
            else
                @c CImGui.InputInt("$(componentField) x", &x, 1)
                @c CImGui.InputInt("$(componentField) y", &y, 1)
            end
            setfield!(component, componentField, (isFloat ? Vector2f(x, y) : Vector2(x, y)))
            CImGui.TreePop()
        end

    elseif isa(fieldValue, Math._Vector3{Float64}) || isa(fieldValue, Math._Vector3{Int32})
        isFloat = isa(fieldValue, Math._Vector3{Float64}) ? true : false

        vec3 = isFloat ? Cfloat[fieldValue.x, fieldValue.y, fieldValue.z] : Cint[fieldValue.x, fieldValue.y, fieldValue.z]

        if CImGui.TreeNode("$(componentField)")   
            if isFloat 
                @c CImGui.InputFloat3("input float3", vec3)
            else
                @c CImGui.InputInt3("input int3", vec3)
            end
        
            CImGui.TreePop()
        end
            
    elseif isa(fieldValue, Math._Vector4{Float64}) || isa(fieldValue, Math._Vector4{Int32})
        isFloat = isa(fieldValue, Math._Vector4{Float64}) ? true : false

        vec4 = isFloat ? Cfloat[fieldValue.x, fieldValue.y, fieldValue.z, fieldValue.t] : Cint[fieldValue.x, fieldValue.y, fieldValue.z, fieldValue.t]

        if CImGui.TreeNode("$(componentField)")
            if isFloat 
                @c CImGui.InputFloat4("input float4", vec4)
            else
                @c CImGui.InputInt4("input int4", vec4)
            end
            CImGui.TreePop()
        end

    elseif isa(fieldValue, Bool) 
        @c CImGui.Checkbox("$(componentField)", &fieldValue)
        setfield!(component, componentField, fieldValue)

    elseif isa(fieldValue, String)
        buf = "$(fieldValue)"*"\0"^(64)
        CImGui.InputText("$(componentField)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = eachindex(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setfield!(component, componentField, currentTextInTextBox)

    elseif isa(fieldValue, Int32) || isa(fieldValue, Float64)
        isFloat = isa(fieldValue, Float64) ? true : false
        x = isFloat ? Cfloat(fieldValue) : Cint(fieldValue)
        if isFloat 
            @c CImGui.InputFloat("$(componentField)", &x, 1)
            x = Float64(x)
        else
            @c CImGui.InputInt("$(componentField)", &x, 1)
        end
        setfield!(component, componentField, x)
    elseif isa(fieldValue, Vector) # Then we need to unpack the nested items
        for i = eachindex(fieldValue)
            continue # TODO: Implement this
            if is_a_julgame_component(fieldValue[i])
                if CImGui.TreeNode("$(nestedFieldType) $(i)")
                for field in fieldnames(typeof(fieldValue[i]))
                    show_field_editor(fieldValue[i], field)
                end
                CImGui.TreePop()
            end
            else
                #show_component_field_input(fieldValue, i)
            end
        end
    end
end

function show_animator_properties(animator)
    try
        for field in fieldnames(typeof(animator))
            fieldString = "$(field)"
            
            if fieldString == "animations"
                animationFields=fieldnames(JulGame.AnimationModule.Animation);
                animations = animator.animations

                CImGui.Button("Add Animation") && animator.appendArray()
                for i = eachindex(animations) 
                    if CImGui.TreeNode("animation $(i)")
                        for j = eachindex(animationFields)
                            animationFieldString = "$(animationFields[j])"
                            if animationFieldString == "animatedFPS"
                                x = Cint(animations[i].animatedFPS)
                                @c CImGui.InputInt("$(animationFieldString) $(j)", &x, 1)
                                animator.animations[i].animatedFPS = x
                            elseif animationFieldString == "frames"
                                try
                                    CImGui.Button("Add Frame") && animations[i].appendArray()
                                    CImGui.Button("Delete") && (deleteat!(animations, i); break;)
                                    for k = eachindex(animations[i].frames)
                                        if CImGui.TreeNode("frame $(k)")
                                            vec = animations[i].frames[k]
                                            vec4i = Cint[vec.x, vec.y, vec.z, vec.t]
                                            @c CImGui.InputInt4("frame input $(k)", vec4i)
                                            animator.animations[i].updateArrayValue(JulGame.Math.Vector4(Int32(vec4i[1]), Int32(vec4i[2]), Int32(vec4i[3]), Int32(vec4i[4])), animationFields[j], Int32(k))
                                            CImGui.TreePop()
                                        end
                                    end
                                catch e
                                    rethrow(e)
                                end
                            end
                        end
                        CImGui.TreePop()
                    end
                end
            else
                show_component_field_input(animator, field)
            end  
        end
    catch e
        rethrow(e)
    end
end

function show_sprite_fields(sprite)
    for field in fieldnames(typeof(sprite))
        fieldString = "$(field)"

        if fieldString == "imagePath"
            buf = "$(sprite.imagePath)"*"\0"^(64)
            CImGui.InputText("Image Path Input", buf, length(buf))
            currentTextInTextBox = ""
            for characterIndex = eachindex(buf)
                if Int32(buf[characterIndex]) == 0 
                    if characterIndex != 1
                        currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                    end
                    break
                end
            end
            sprite.imagePath = currentTextInTextBox
            CImGui.Button("Load Image") && (sprite.loadImage(currentTextInTextBox))
        else 
            show_component_field_input(sprite, field)
        end  
    end
end

function show_sound_source_fields(soundSource)
    for field in fieldnames(typeof(soundSource))
        fieldString = "$(field)"

        if fieldString == "path"
            CImGui.Text("Sound Path")
            buf = "$(soundSource.path)"*"\0"^(64)
            CImGui.InputText("Sound Path Input", buf, length(buf))
            currentTextInTextBox = ""
            for characterIndex = eachindex(buf)
                if Int32(buf[characterIndex]) == 0 
                    if characterIndex != 1
                        currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                    end
                    break
                end
            end
            soundSource.path = currentTextInTextBox
            CImGui.Button("Load Sound") && (soundSource.loadSound(currentTextInTextBox, false))
            CImGui.Button("Load Music") && (soundSource.loadSound(currentTextInTextBox, true))
        else
            show_component_field_input(soundSource, field)
        end  
    end
end

function is_a_julgame_component(field)
    return isa(field, JulGame.TransformModule.Transform) || isa(field, JulGame.SpriteModule.InternalSprite) || isa(field, JulGame.ColliderModule.InternalCollider) || isa(field, JulGame.RigidbodyModule.InternalRigidbody) || isa(field, JulGame.SoundSourceModule.InternalSoundSource) || isa(field, JulGame.AnimatorModule.InternalAnimator) || isa(field, JulGame.ShapeModule.InternalShape) || isa(field, JulGame.CircleColliderModule.InternalCircleCollider) || isa(field, JulGame.AnimationModule.Animation)
end