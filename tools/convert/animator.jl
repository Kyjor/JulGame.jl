# Animator.jl → Animator.ts fixups (included from tools/convert.jl).

function is_animator_source(path_jl::AbstractString)::Bool
    norm = replace(normpath(String(path_jl)), '\\' => '/')
    return endswith(norm, "/Component/Animator.jl") || endswith(norm, "Animator.jl")
end

"""Julia 1-based animation frame indices → TS 0-based."""
function postprocess_animator_ts(data::AbstractString)::String
    s = String(data)
    s = replace(
        s,
        "self.sprite.crop = self.currentAnimation.frames[self.lastFrame]" =>
            "self.sprite.crop = self.currentAnimation.frames[self.lastFrame > 0 ? self.lastFrame - 1 : 0]",
    )
    s = replace(
        s,
        "self.sprite.crop = self.currentAnimation.frames[frameIndex]" =>
            "self.sprite.crop = self.currentAnimation.frames[frameIndex - 1]",
    )
    return s
end
