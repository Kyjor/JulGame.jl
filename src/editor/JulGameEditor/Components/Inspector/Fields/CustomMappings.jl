CustomMappings = Dict{String, Dict{Symbol, Symbol}}(
    "InternalAnimator" => Dict{Symbol, Symbol}(),
    "InternalCollider" => Dict{Symbol, Symbol}(),
    "InternalShape" => Dict{Symbol, Symbol}(),  
    "InternalRigidbody" => Dict{Symbol, Symbol}(),
    "InternalShape" => Dict{Symbol, Symbol}(),
    "InternalSoundSource" => Dict{Symbol, Symbol}(),
    "InternalSprite" => Dict{Symbol, Symbol}(),
    "ScreenButton" => Dict{Symbol, Symbol}(),
    "TextBox" => Dict{Symbol, Symbol}(),
    "Transform" => Dict{Symbol, Symbol}(),
    "UIImage" => Dict{Symbol, Symbol}(),
    "UIElement" => Dict{Symbol, Symbol}(),
)

function show_custom_field_mapping(structure::EditableStructure, field::Symbol, value::Any)
end