# Collider.jl → Collider.ts fixups (included from tools/convert.jl).

function is_collider_source(path_jl::AbstractString)::Bool
    norm = replace(normpath(String(path_jl)), '\\' => '/')
    return endswith(norm, "/Component/Collider.jl") || endswith(norm, "Collider.jl")
end

"""Tile colliders have no rigidbody; guard `.grounded` / `.velocity` access in TS."""
function postprocess_collider_ts(data::AbstractString)::String
    s = String(data)
    s = replace(
        s,
        "if (self.parent.rigidbody.velocity.y >= 0)" =>
            "if (self.parent.rigidbody != null && self.parent.rigidbody.velocity.y >= 0)",
    )
    s = replace(
        s,
        "if (collision[2] && self.parent.rigidbody.grounded)" =>
            "if (collision[2] && self.parent.rigidbody != null && self.parent.rigidbody.grounded)",
    )
    s = replace(
        s,
        r"(?m)^(\s*)self\.parent\.rigidbody\.grounded = onGround\s*$" =>
            s"\1if (self.parent.rigidbody != null) {\n\1    self.parent.rigidbody.grounded = onGround\n\1}",
    )
    # `globalConstants` assigns enums on `globalThis`, not as ESM bindings.
    for (name, val) in [("None", -1), ("Top", 1), ("Bottom", 2), ("Left", 3), ("Right", 4), ("Below", 2)]
        s = replace(s, Regex("\\b$name\\b") => string(val))
    end
    return s
end
