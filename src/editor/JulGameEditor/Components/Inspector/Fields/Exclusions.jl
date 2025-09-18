FieldExclusions = Dict{String, Vector{Symbol}}(
    "InternalAnimator" => [:lastFrame, :lastUpdate, :parent],
    "InternalCollider" => [:currentCollisions, :currentRests, :parent],
    "InternalShape" => [:parent],
    "InternalRigidbody" => [:acceleration, :grounded, :offset, :parent, :velocity],
    "InternalShape" => [:parent],
    "InternalSoundSource" => [:isPlaying, :sound, :parent],
    "InternalSprite" => [:parent, :lastRenderedScreenPosition, :lastRenderedScreenSize, :texture],
    "Transform" => [:screenPosition, :screenRotation, :screenSize, :parent],
)