# Julia 1.11 Array{T} header
const JL_ARRAY_DATA_OFF = 0
const JL_ARRAY_LENGTH_OFF = 16

# InternalSprite.crop::Union{Ptr{Nothing}, Vector4} layout
const SPRITE_CROP_OFF = 88
const SPRITE_CROP_TAG_OFF = 104
const UNION_TAG_VECTOR4 = UInt8(1)
