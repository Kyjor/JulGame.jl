using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using JulGame
using JulGame.Math
using JulGame.UI

include("TextBoxFields.jl")
include("ScreenButtonFields.jl")


"""
show_field_editor(entity, field)
Creates inputs based on the component type and populates them.
"""
function show_field_editor(entity, fieldName, animation_window_dict)
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
        if delete_button(entity, fieldName)
            CImGui.TreePop()
            return
        end

        if isa(field, SpriteModule.InternalSprite)
            show_sprite_fields(entity.sprite, animation_window_dict)
        elseif isa(field, SoundSourceModule.InternalSoundSource)
            show_sound_source_fields(entity.soundSource)
        elseif isa(field, AnimatorModule.InternalAnimator)
            show_animator_properties(entity.animator, animation_window_dict)
        else
            for field in fieldnames(typeof(field))
                show_component_field_input(getfield(entity, Symbol(lowercase(fieldName))), field)
            end
        end

        CImGui.TreePop()
    end
end

"""
    delete_button(entity, fieldName)::Bool

Delete button for a component field.

Parameters:
- `entity`: The entity object.
- `fieldName`: The name of the field to delete.

Returns:
- `true` if the delete button is pressed and the field is deleted.
- `false` otherwise.
"""
function delete_button(entity, fieldName)::Bool
    if fieldName == "Transform"
        return false
    end

    if CImGui.Button("Delete")
        println("Deleting $(fieldName)")
        setfield!(entity, Symbol(lowercase(fieldName)), C_NULL)
        return true
    end

    return false
end

"""
    show_component_field_input(component, componentField)

This function displays the input fields for a given component field. It takes two arguments:
- `component`: The component object.
- `componentField`: The field of the component object.

The function checks the type of the field value and displays the corresponding input fields using CImGui library. It updates the field value based on the user input.

"""
function show_component_field_input(component, componentField)
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
        
            setfield!(component, componentField, (isFloat ? Vector3f(vec3[1], vec3[2], vec3[3]) : Vector3(vec3[1], vec3[2], vec3[3])))
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

            setfield!(component, componentField, (isFloat ? Vector4f(vec4[1], vec4[2], vec4[3], vec4[4]) : Vector4(vec4[1], vec4[2], vec4[3], vec4[4])))
            CImGui.TreePop()
        end

    elseif isa(fieldValue, Bool) 
        @c CImGui.Checkbox("$(componentField)", &fieldValue)
        setfield!(component, componentField, fieldValue)

    elseif isa(fieldValue, String) && String(componentField) != "id"
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
    elseif String(componentField) == "scripts"
        show_script_editor(component)
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

"""
    show_animator_properties(animator, animation_window_dict)

Display the properties of an animator object in the user interface.

# Arguments
- `animator`: The animator object to display properties for.

"""
function show_animator_properties(animator, animation_window_dict)
    try
        for field in fieldnames(typeof(animator))
            fieldString = "$(field)"
            
            if fieldString == "animations"
                animationFields=fieldnames(JulGame.AnimationModule.Animation);
                animations = animator.animations

                CImGui.Button("Add Animation") && Component.append_array(animator)
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
                                    CImGui.Button("Add Frame") && Component.append_array(animations[i])
                                    CImGui.Button("Delete") && (deleteat!(animations, i); break;)
                                    for k = eachindex(animations[i].frames)
                                        vec = animations[i].frames[k]
                                        anim_x, anim_y, anim_w, anim_h = vec.x, vec.y, vec.z, vec.t

                                        if animator.parent.sprite != C_NULL && animator.parent.sprite !== nothing
                                            sprite = animator.parent.sprite
                                            show_image_with_hover_preview(sprite.texture, sprite.size.x, sprite.size.y, animations[i].frames[k])
                                        end
                                        if CImGui.TreeNode("frame $(k)")
                                            if animator.parent.sprite != C_NULL && animator.parent.sprite !== nothing
                                                
                                                points = Ref(Vector{ImVec2}([ImVec2(anim_x, anim_y), ImVec2(anim_x + anim_w, anim_y + anim_h)]))
                                                scrolling = Ref(ImVec2(0.0, 0.0))
                                                adding_line = Ref(false)
                                                zoom_level = Ref(1.0)
                                                grid_step = Ref(Int32(64))

                                                # put these in a ref dictionary
                                                window_info = Ref(Dict("points" => points, "scrolling" => scrolling, "adding_line" => adding_line, "zoom_level" => zoom_level, "grid_step" => grid_step))
                                                # check if animation_window_dict has the key "frame $(k)"
                                                if haskey(animation_window_dict[], "frame $(k)")
                                                    # animation_window_dict[]["frame $(k)"][]["points"] = points
                                                    window_info[] = animation_window_dict[]["frame $(k)"][]
                                                else
                                                    animation_window_dict[]["frame $(k)"] = window_info
                                                end

                    
                                                sprite = animator.parent.sprite
                                                anim_x, anim_y, anim_w, anim_h = show_animation_window("frame $(k)", window_info, sprite.texture, sprite.size.x, sprite.size.y)
                                            end

                                            vec4i = Cint[anim_x, anim_y, anim_w, anim_h]
                                            @c CImGui.InputInt4("frame input $(k)", vec4i)
                                            Component.update_array_value(animations[i], JulGame.Math.Vector4(Int32(vec4i[1]), Int32(vec4i[2]), Int32(vec4i[3]), Int32(vec4i[4])), animationFields[j], Int32(k))
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

"""
    show_sprite_fields(sprite)

Iterates over the fields of the `sprite` object and displays input fields for each field.
If the field is `imagePath`, it displays an input text field for the image path, a button to load the image,
and updates the `sprite.imagePath` field with the current text in the text box.

# Arguments
- `sprite`: The sprite object to display the fields for.

"""
function show_sprite_fields(sprite, animation_window_dict)
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
            imageMenuValue = display_files(joinpath(JulGame.BasePath, "assets", "images"), "images")
            if imageMenuValue != ""
                println("imageMenuValue: $imageMenuValue")
                # remove joinpath("assets", "images") from imageMenuValue and set it to imagePath
                imagePath = replace(imageMenuValue, joinpath(JulGame.BasePath, "assets", "images") => "")
                # remove leading / or \\ from imagePath
                if imagePath[1] == '/' || imagePath[1] == '\\'
                    imagePath = imagePath[2:end]
                end

                sprite.imagePath = imagePath
            end 
            CImGui.Button("Load Image") && (Component.load_image(sprite, currentTextInTextBox))
        elseif fieldString == "crop"
            crop_x, crop_y, crop_w, crop_h = sprite.crop.x, sprite.crop.y, sprite.crop.z, sprite.crop.t

            points = Ref(Vector{ImVec2}([ImVec2(crop_x, crop_y), ImVec2(crop_x + crop_w, crop_y + crop_h)]))
            scrolling = Ref(ImVec2(0.0, 0.0))
            adding_line = Ref(false)
            zoom_level = Ref(1.0)
            grid_step = Ref(Int32(64))
            # put these in a ref dictionary
            window_info = Ref(Dict("points" => points, "scrolling" => scrolling, "adding_line" => adding_line, "zoom_level" => zoom_level, "grid_step" => grid_step))
            # check if animation_window_dict has the key "frame $(k)"
            key = "crop-$(sprite.parent.id)"
            if haskey(animation_window_dict[], key)
                # animation_window_dict[]["frame $(k)"][]["points"] = points
                window_info[] = animation_window_dict[][key][]
            else
                print("Adding crop window info for: $key")
                animation_window_dict[][key] = window_info
            end

            CImGui.PushID(sprite.parent.id)
                crop_x, crop_y, crop_w, crop_h = show_animation_window("crop", window_info, sprite.texture, sprite.size.x, sprite.size.y)
            CImGui.PopID()
            vec4i = Cint[crop_x, crop_y, crop_w, crop_h]
            @c CImGui.InputInt4("crop", vec4i)
            sprite.crop = JulGame.Math.Vector4(Int32(vec4i[1]), Int32(vec4i[2]), Int32(vec4i[3]), Int32(vec4i[4]))
        else
            show_component_field_input(sprite, field)
        end  
    end
end

"""
    show_textbox_fields(textbox)

Iterates over the fields of the `textbox` object and displays input fields for each field.
If the field is `fontPath`, it displays an input text field for the font path, a button to load the font,
and updates the `sprite.fontPath` field with the current text in the text box.

# Arguments
- `textbox`: The textbox component to display the fields for.

"""
function show_textbox_fields(textbox)
    for field in fieldnames(typeof(textbox))
        fieldString = "$(field)"

        if fieldString == "fontPath"
            buf = "$(textbox.fontPath)"*"\0"^(64)
            CImGui.InputText("Font Path Input", buf, length(buf))
            currentTextInTextBox = ""
            for characterIndex = eachindex(buf)
                if Int32(buf[characterIndex]) == 0 
                    if characterIndex != 1
                        currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                    end
                    break
                end
            end
            textbox.fontPath = currentTextInTextBox

            basePath = joinpath(BasePath, "assets", "fonts")
            fontPath = joinpath(strip(String(textbox.fontPath)))
            if strip(String(currentTextInTextBox)) == "" || joinpath(strip(String(currentTextInTextBox))) == joinpath("Fonts", "FiraCode", "ttf", "FiraCode-Regular.ttf")
                basePath = joinpath(pwd(), "..")
                fontPath = joinpath("Fonts", "FiraCode", "ttf", "FiraCode-Regular.ttf")
            end
            fontMenuValue = display_files(joinpath(JulGame.BasePath, "assets", "fonts"), "fonts")
            if fontMenuValue != ""
                # remove joinpath("assets", "fonts") from fontMenuValue and set it to fontPath
                fontPath = replace(fontMenuValue, joinpath(JulGame.BasePath, "assets", "fonts") => "")
                # remove leading / or \\ from fontPath
                if fontPath[1] == '/' || fontPath[1] == '\\'
                    fontPath = fontPath[2:end]
                end

                textbox.fontPath = fontPath
            end 
            CImGui.Button("Load Font") && (UI.load_font(textbox, basePath, fontPath))
        else 
            show_textbox_fields(textbox, field)
        end  
    end
end

function show_screenbutton_fields(screenButton)
    for field in fieldnames(typeof(screenButton))
        fieldString = "$(field)"

        # TODO: if fieldString == "fontPath" || 
        if fieldString == "buttonUpSpritePath" || fieldString == "buttonDownSpritePath"
            buf = "$(getfield(screenButton, Symbol(fieldString)))"*"\0"^(64)
            CImGui.InputText("$(fieldString) Path Input", buf, length(buf))
            currentTextInScreenButton = ""
            for characterIndex = eachindex(buf)
                if Int32(buf[characterIndex]) == 0 
                    if characterIndex != 1
                        currentTextInScreenButton = String(SubString(buf, 1, characterIndex-1))
                    end
                    break
                end
            end
            setfield!(screenButton, Symbol(fieldString), currentTextInScreenButton)

            if fieldString == "fontPath"
                # TODO: CImGui.Button("Load Font") && (UI.load_font(screenButton, joinpath(pwd()), joinpath("Fonts", "FiraCode", "ttf", "FiraCode-Regular.ttf")))
            elseif fieldString == "buttonUpSpritePath"
                CImGui.Button("Load Button Up Sprite") && (UI.load_button_sprite_editor(screenButton, currentTextInScreenButton, true))
            elseif fieldString == "buttonDownSpritePath"
                CImGui.Button("Load Button Down Sprite") && (UI.load_button_sprite_editor(screenButton, currentTextInScreenButton, false))
            end
        else 
            show_screenbutton_fields(screenButton, field)
        end  
    end
end

"""
    show_sound_source_fields(soundSource)

Display the fields of a `soundSource` object and provide user input for each field.

# Arguments
- `soundSource`: The sound source object to display and edit.

"""
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
            soundMenuValue = display_files(joinpath(JulGame.BasePath, "assets", "sounds"), "sounds")
            if soundMenuValue != ""
                # remove joinpath("assets", "sounds") from soundMenuValue and set it to soundPath
                soundPath = replace(soundMenuValue, joinpath(JulGame.BasePath, "assets", "sounds") => "")
                # remove leading / or \\ from soundPath
                if soundPath[1] == '/' || soundPath[1] == '\\'
                    soundPath = soundPath[2:end]
                end

                soundSource.path = soundPath
            end
            CImGui.Button("Load Sound") && (Component.load_sound(soundSource, currentTextInTextBox, false))
            CImGui.Button("Load Music") && (Component.load_sound(soundSource, currentTextInTextBox, true))
        else
            show_component_field_input(soundSource, field)
        end  
    end
end

"""
    is_a_julgame_component(field)

Check if the given `field` is a component of the JulGame library.

# Arguments
- `field`: The field to check.

# Returns
- `true` if the `field` is a component of the JulGame library, `false` otherwise.
"""
function is_a_julgame_component(field)
    return isa(field, JulGame.TransformModule.Transform) || isa(field, JulGame.SpriteModule.InternalSprite) || isa(field, JulGame.ColliderModule.InternalCollider) || isa(field, JulGame.RigidbodyModule.InternalRigidbody) || isa(field, JulGame.SoundSourceModule.InternalSoundSource) || isa(field, JulGame.AnimatorModule.InternalAnimator) || isa(field, JulGame.ShapeModule.InternalShape) || isa(field, JulGame.CircleColliderModule.InternalCircleCollider) || isa(field, JulGame.AnimationModule.Animation)
end

function show_script_editor(entity)
    if CImGui.TreeNode("Scripts")
        show_help_marker("Add a script here to run it on the entity.")
        CImGui.Button("Add Script") && (push!(entity.scripts, scriptObj("",[])); return;)
        for i = eachindex(entity.scripts)
            if CImGui.TreeNode("Script $(i)")
                buf = "$(entity.scripts[i].name)"*"\0"^(64)
                CImGui.Button("Delete $(i)") && (deleteat!(entity.scripts, i); return;)
                CImGui.InputText("Script $(i)", buf, length(buf))
                currentTextInTextBox = ""
                for characterIndex = eachindex(buf)
                    if Int32(buf[characterIndex]) == 0 
                        if characterIndex != 1
                            currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                        end
                        break
                    end
                end
                
                entity.scripts[i] = scriptObj(currentTextInTextBox, entity.scripts[i].parameters)
                if CImGui.TreeNode("Script $(i) parameters")
                    params = entity.scripts[i].parameters
                    CImGui.Button("Add New Script Parameter") && (push!(params, ""); entity.scripts[i] = scriptObj(currentTextInTextBox, params); break;)

                    for j = eachindex(entity.scripts[i].parameters)
                        buf = "$(entity.scripts[i].parameters[j])"*"\0"^(64)
                        CImGui.Button("Delete $(j)") && (deleteat!(params, j); entity.scripts[i] = scriptObj(currentTextInTextBox, params); break;)
                        CImGui.InputText("Parameter $(j)", buf, length(buf))
                        currentTextInTextBox = ""
                        for characterIndex = eachindex(buf)
                            if Int32(buf[characterIndex]) == 0 
                                if characterIndex != 1
                                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                                end
                                break
                            end
                        end
                        params[j] = currentTextInTextBox
                        entity.scripts[i] = scriptObj(entity.scripts[i].name, params)

                    end
                    CImGui.TreePop()
                end
                CImGui.TreePop()
            end
        end
        CImGui.TreePop()
    end
end

function scriptObj(name::String, parameters::Array)
    () -> (name; parameters)
end