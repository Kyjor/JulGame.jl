# Camera.jl → Camera.ts fixups (included from tools/convert.jl).

function postprocess_camera_ts(data::AbstractString)::String
    s = String(data)
    # Julia: `!IS_EDITOR && x != size.x || y != size.y` parses as `(!IS_EDITOR && x) || y`.
    # Intended: only resize when not editor and logical size differs.
    s = replace(
        s,
        r"if \(!\(globalThis as any\)\.JulGame\.IS_EDITOR && \(globalThis as any\)\.JulGame\.WindowManagerModule\.get_logical_size\(\)\.x != self\.size\.x \|\| \(globalThis as any\)\.JulGame\.WindowManagerModule\.get_logical_size\(\)\.y != self\.size\.y\)" =>
            "if (!(globalThis as any).JulGame.IS_EDITOR && !(globalThis as any).JulGame.IS_WEB && ((globalThis as any).JulGame.WindowManagerModule.get_logical_size().x != self.size.x || (globalThis as any).JulGame.WindowManagerModule.get_logical_size().y != self.size.y))",
    )
    s = replace(
        s,
        r"console\.debug\(`Logical size changed to \$\{self\.size\}`\)" =>
            raw"console.debug(`Logical size changed to ${self.size.x}x${self.size.y}`)",
    )
    return s
end
