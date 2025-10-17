module TextStyleModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    using ..UI.TextEffectsModule
    export TextStyle

    mutable struct TextStyle
        font::String
        size::Int
        baseColor::NTuple{4, Int}
        effects::Vector{TextEffect}
        isDynamic::Bool
        function TextStyle(; font::String="", size::Int=16, baseColor::NTuple{4, Int}=(255,255,255,255), effects::Vector{TextEffect}=TextEffect[], isDynamic::Bool=false)
            new(font, Math.TypeConversions.safe_int32_convert(size), baseColor, effects, isDynamic)
        end
    end
end


