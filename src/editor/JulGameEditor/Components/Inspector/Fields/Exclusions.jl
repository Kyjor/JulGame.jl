FieldExclusions = Dict{String, Vector{Symbol}}(
    "InternalAnimator" => [:lastFrame, :lastUpdate, :sprite, :parent],
    "InternalCollider" => [:currentCollisions, :currentRests, :parent],
    "InternalShape" => [:parent],
    "InternalRigidbody" => [:acceleration, :grounded, :offset, :parent, :velocity],
    "InternalShape" => [:parent],
    "InternalSoundSource" => [:isPlaying, :sound, :parent],
    "InternalSprite" => [:parent, :lastRenderedScreenPosition, :lastRenderedScreenSize, :size, :texture],
    "TextBox" => [:font,:isConstructed, :renderText, :textTexture],
    "Transform" => [:screenPosition, :screenRotation, :screenSize, :parent],
)