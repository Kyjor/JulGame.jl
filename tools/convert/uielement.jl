# Post-process transpiled `UIElement.ts` from `src/engine/UI/UIElement.jl`.

function is_uielement_source(path_jl::AbstractString)::Bool
    return endswith(replace(normpath(String(path_jl)), '\\' => '/'), "/src/engine/UI/UIElement.jl")
end

function _extract_ts_function(s::AbstractString, name::AbstractString)::Union{String, Nothing}
    m = match(Regex("(?:export )?function $name\\b[\\s\\S]*?\\n\\}"), s)
    m === nothing && return nothing
    body = String(m.match)
    return startswith(body, "export ") ? body : "export " * body
end

function postprocess_uielement_ts(data::AbstractString)::String
    s = String(data)
    s = replace(s, r"if \(self\.parent\.JulGame\.IUIElement\)\)" => "if ('size' in self.parent && 'position' in self.parent)")
    s = replace(s, r"\bisa\(([^,]+),\s*[^)]+\)" => s"\1")
    parts = String[]
    for fn in ("UI_set_color", "UI_align_to_anchor", "UI_add_hover_enter_event", "UI_add_hover_exit_event")
        chunk = _extract_ts_function(s, fn)
        chunk === nothing && continue
        chunk = replace(chunk, r"self: IUIElement" => "self: {
        name?: string
        parent: unknown
        anchor: { current_state: string }
        anchorOffset: { x: number; y: number }
        position: { x: number; y: number }
        size: { x: number; y: number }
        hoverEnterEvents: Array<() => void>
        hoverExitEvents: Array<() => void>
    }")
        push!(parts, chunk)
    end
    isempty(parts) && return s
    click_fn = """
export function UI_add_click_event(self: { clickEvents: Array<() => void> }, event: () => void) {
    self.clickEvents.push(event)
}
"""
    out = join(vcat([click_fn], parts), "\n\n") * "\n"
    parent_ui_check = "typeof self.parent === \"object\" && self.parent !== null && \"size\" in self.parent && \"position\" in self.parent"
    out = replace(out, r"if \('size' in self\.parent && 'position' in self\.parent\)" => "if ($parent_ui_check)")
    out = replace(out, r"if \(self\.parent\.JulGame\.IUIElement\)\)" => "if ($parent_ui_check)")
    parent_block = """
    let size = (globalThis as any).MAIN.scene.camera.size
    let parent_pos = {x: 0, y: 0}
    if (self.parent != null && typeof self.parent === "object") {
        if ("size" in self.parent && "position" in self.parent) {
            size = self.parent.size
            parent_pos = self.parent.position
        } else if (
            "lastRenderedScreenSize" in self.parent &&
            "lastRenderedScreenPosition" in self.parent &&
            self.parent.lastRenderedScreenSize != null &&
            self.parent.lastRenderedScreenPosition != null
        ) {
            size = self.parent.lastRenderedScreenSize
            parent_pos = self.parent.lastRenderedScreenPosition
        } else {
            console.debug(`No last rendered screen size or position found for parent of \${self.name}`)
            return
        }
    }
"""
    out = replace(
        out,
        r"let size = \(globalThis as any\)\.MAIN\.scene\.camera\.size[\s\S]*?if \(self\.anchor\.current_state == \"center\"\)" =>
            parent_block * "\n    if (self.anchor.current_state == \"center\")",
    )
    out = replace(out, r": number=255" => " = 255")
    out = replace(out, r"self: \{\n        name\?: string" => "self: {\n        color: [number, number, number, number]\n        name?: string")
    return out
end
