CustomMappings = Dict{String, Dict{Symbol, Symbol}}(
    "InternalAnimator" => Dict{Symbol, Symbol}(),
    "InternalCollider" => Dict{Symbol, Symbol}(),
    "InternalShape" => Dict{Symbol, Symbol}(),  
    "InternalRigidbody" => Dict{Symbol, Symbol}(),
    "InternalShape" => Dict{Symbol, Symbol}(),
    "InternalSoundSource" => Dict{Symbol, Symbol}(),
    "InternalSprite" => Dict{Symbol, Symbol}(
        :imagePath => :path,
    ),
    "ScreenButton" => Dict{Symbol, Symbol}(),
    "TextBox" => Dict{Symbol, Symbol}(),
    "Transform" => Dict{Symbol, Symbol}(),
    "UIImage" => Dict{Symbol, Symbol}(),
    "UIElement" => Dict{Symbol, Symbol}(),
)

function show_custom_field_mapping(structure::EditableStructure, field::Symbol, customDisplay::Symbol, value::Any)
    structureType = typeof(structure)
    if customDisplay == :path
        CImGui.Text("Path: $(value)")
        imageMenuValue = display_files(joinpath(JulGame.BasePath, "assets", "images"), "images")
        if imageMenuValue != ""
            imagePath = replace(imageMenuValue, joinpath(JulGame.BasePath, "assets", "images") => "")
            if imagePath[1] == '/' || imagePath[1] == '\\'
                imagePath = imagePath[2:end]
            end

            setproperty!(structure, field, imagePath)
            if isa(structure, JulGame.SpriteModule.InternalSprite)
                Component.load_image(structure, imagePath)
            end
        end
    end
end