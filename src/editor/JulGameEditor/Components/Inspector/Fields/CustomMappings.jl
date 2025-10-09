CustomMappings = Dict{String, Dict{Symbol, Symbol}}(
    "InternalAnimator" => Dict{Symbol, Symbol}(),
    "InternalCollider" => Dict{Symbol, Symbol}(),
    "InternalShape" => Dict{Symbol, Symbol}(),  
    "InternalRigidbody" => Dict{Symbol, Symbol}(),
    "InternalShape" => Dict{Symbol, Symbol}(),
    "InternalSoundSource" => Dict{Symbol, Symbol}(
        :path => :path,
    ),
    "InternalSprite" => Dict{Symbol, Symbol}(
        :imagePath => :path,
    ),
    "ScreenButton" => Dict{Symbol, Symbol}(
        :buttonUpSpritePath => :path,
        :buttonDownSpritePath => :path,
        :fontPath => :path,
    ),
    "TextBox" => Dict{Symbol, Symbol}(
        :fontPath => :path,
    ),
    "Transform" => Dict{Symbol, Symbol}(),
    "UIImage" => Dict{Symbol, Symbol}(
        :path => :path,
    ),
    "UIElement" => Dict{Symbol, Symbol}(),
)

function show_custom_field_mapping(structure::EditableStructure, field::Symbol, customDisplay::Symbol, value::Any)
    structureType = typeof(structure)
    if customDisplay == :path || field == :buttonUpSpritePath || field == :buttonDownSpritePath
        pathType = if isa(structure, JulGame.SpriteModule.InternalSprite) || isa(structure, JulGame.UI.ScreenButtonModule.ScreenButton) || isa(structure, JulGame.UI.UIImageModule.UIImage)
            "images"
        elseif isa(structure, JulGame.UI.TextBoxModule.TextBox) || field == :fontPath
            "fonts"
        elseif isa(structure, JulGame.SoundSourceModule.InternalSoundSource)
            "sounds"
        else
            "scripts"
        end

        CImGui.Text("Path: $(value)")
        if isa(structure, JulGame.UI.TextBoxModule.TextBox) || field == :fontPath
            if strip(String(structure.fontPath)) == "" || joinpath(strip(String(structure.fontPath))) == joinpath("FiraCode-Regular.ttf")
                filePath = joinpath("FiraCode-Regular.ttf")
            end
        end
        # Use the new file finder modal with unique ID
        button_id = "Browse_$(field)_$(pathType)"
        if CImGui.Button("Browse...##$(button_id)")
            @debug "Browse button clicked for field: $field, pathType: $pathType"
            structure_type = split(string(typeof(structure)), ".")[end]
            open_file_finder_modal(string(joinpath(JulGame.BasePath, "assets", pathType)), string(pathType), "Select $(pathType) File", field, string(structure_type))
        end
        
        # Check if a file was selected from the modal (only when modal is closed)
        if !is_file_finder_open() && get_file_finder_result() != ""
            selected_file = get_file_finder_result()
            target_field, target_structure_type = get_file_finder_target()
            structure_type = split(string(typeof(structure)), ".")[end]
            
            @debug "File selected from modal: $selected_file for field: $field, pathType: $pathType"
            @debug "Target field: $target_field, target structure: $target_structure_type, current field: $field, current structure: $structure_type"
            
            # Only apply the result if this is the correct field and structure
            if target_field != field || target_structure_type != structure_type
                @debug "Skipping result for field $field - not the target field $target_field or structure $target_structure_type"
                return
            end
            
            # Verify the file type matches what we expect
            state = JulGame.EditorState["file_finder"]
            if state.file_type != pathType
                @warn "File type mismatch: expected $pathType but got $(state.file_type), ignoring selection for field: $field"
                state.selected_file = ""
                return
            end
            
            # Extract relative path
            filePath = replace(selected_file, joinpath(JulGame.BasePath, "assets", pathType) => "")
            if filePath[1] == '/' || filePath[1] == '\\'
                filePath = filePath[2:end]
            end
            
            @debug "Setting field $field to: $filePath for structure: $(typeof(structure))"

            setproperty!(structure, field, filePath)
            if isa(structure, JulGame.SpriteModule.InternalSprite) || isa(structure, JulGame.UI.UIImageModule.UIImage)
                JulGame.load_image(structure, filePath)
            elseif isa(structure, JulGame.UI.ScreenButtonModule.ScreenButton)
                UI.load_button_sprite_editor(structure, filePath, customDisplay == :pathUp)
            elseif isa(structure, JulGame.SoundSourceModule.InternalSoundSource)
                Component.load_sound(structure, filePath, structure.isMusic)
            elseif isa(structure, JulGame.UI.TextBoxModule.TextBox) || field == :fontPath
                UI.load_font(structure, filePath)
            end
            
            # Clear the result to prevent re-processing
            state.selected_file = ""
        end
    end
end