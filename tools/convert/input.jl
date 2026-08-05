# Input.jl → Input.ts post-processing (included from tools/convert.jl).

"""True when `path_jl` is `src/engine/Input/Input.jl`."""
function is_input_source(path_jl::AbstractString)::Bool
    norm = replace(normpath(String(path_jl)), '\\' => '/')
    return endswith(norm, "src/engine/Input/Input.jl")
end

"""Functions stripped from transpiled Input.ts (clipboard/profiling helpers)."""
function input_functions_to_remove()::Vector{String}
    return String[
        "handle_x11_clipboard_image",
        "handle_macos_clipboard_image",
        "handle_windows_clipboard_image",
        "handle_clipboard_paste",
        "is_image_file_by_extension",
        "add_clipboard_file_to_import_queue",
        "handle_base64_image_data",
        "_input_poll_accumulate",
        "_input_ui_hit_span",
        "_input_ui_hit_stream_logs",
        "_input_ui_hit_iter_stream_logs",
    ]
end

"""Line-level rewrites applied only to Input.ts."""
function input_line_rewrite_rules()::Vector{Pair{Union{String, Regex}, String}}
    rules = Pair{Union{String, Regex}, String}[]
    push!(rules, "_input_ui_hit_span" => "")
    push!(rules, "_input_poll_accumulate" => "")
    push!(rules, "_input_ui_hit_step" => "")
    push!(rules, "_input_ui_hit_iter_stream_logs" => "")
    push!(rules, "_input_ui_hit_stream_logs" => "")
    push!(rules, "_handle_clipboard_paste" => "")
    push!(rules, "handle_dropped_files" => "")
    push!(rules, "is not set in the main scene" => "")
    push!(rules, "uiElementsOrderedByLayerDescending = sort(reverse" => "")
    push!(rules, "entitiesWithSpritesOrderedByLayerDescending =" => "")
    push!(
        rules,
        " elementsOrderedByLayerDescending = vcat" =>
            "let elementsOrderedByLayerDescending = (globalThis as any).JulGame.MAIN.scene.uiElements",
    )
    push!(rules, "                this.quit = true" => "                self.quit = true")
    push!(rules, "                this.debug = !this.debug" => "                self.debug = !self.debug")
    return rules
end

function apply_line_rewrite_rules(data::AbstractString, rules::Vector{Pair{Union{String, Regex}, String}})::String
    lines = split(String(data), '\n'; keepempty = true)
    out = map(lines) do line
        for (needle, replacement) in rules
            occursin(needle, line) && return String(replacement)
        end
        line
    end
    return join(out, '\n')
end

"""`button in self.arr` (Julia membership) → `self.arr.includes(button)` for JS arrays."""
function replace_julia_array_membership(data::AbstractString)::String
    s = String(data)
    s = replace(s, r"!\((\w+) in ([^)]+)\)" => s"!(\2.includes(\1))")
    s = replace(s, r"\b(\w+) in (self\.\w+)\b" => s"\2.includes(\1)")
    s = replace(s, r"\b(\w+) in (this\.\w+)\b" => s"\2.includes(\1)")
    return s
end

"""SDL out-params: `...x, ...y` spread breaks ref-cell arrays."""
function replace_sdl_out_param_spreads(data::AbstractString)::String
    s = String(data)
    s = replace(s, r"glue_SDL_GetMouseState\(\.\.\.(\w+),\s*\.\.\.(\w+)\)" => s"glue_SDL_GetMouseState(\1, \2)")
    s = replace(
        s,
        r"glue_SDL_GetWindowSize\(([^,]+),\s*\.\.\.(\w+),\s*\.\.\.(\w+)\)" =>
            s"glue_SDL_GetWindowSize(\1, \2, \3)",
    )
    return s
end

"""Julia `instances(SDL_Scancode)` loop → hardcoded `JulGameSdl.SDL_SCANCODE_ENTRIES`."""
function replace_scancode_init(data::AbstractString)::String
    pat = r"this\.scanCodes = \[\]\s*\n\s*this\.scanCodeStrings = \[\]\s*\n\s*for \(const m of Object\.values\(\(globalThis as any\)\.JulGameSdl\.glue_SDL_Scancode\)\) \{[\s\S]*?\};"
    replacement = """this.scanCodes = (globalThis as any).JulGameSdl.SDL_SCANCODE_ENTRIES.slice()
            this.scanCodeStrings = []
"""
    return replace(String(data), pat => replacement)
end

"""`export function poll_input(self: …)` bodies can keep Julia `this` after partial renames."""
function fix_poll_input_this_receiver(data::AbstractString)::String
    pat = r"(export function poll_input\(self: Input\) \{)([\s\S]*?)(\n    \}\n\n    function check_scan_code)"
    m = match(pat, String(data))
    m === nothing && return String(data)
    body = replace(m.captures[2], r"\bthis\." => "self.")
    body = replace(body, r"\bthis\b" => "self")
    replacement = string(m.captures[1], body, m.captures[3])
    lo = m.offset
    hi = lo + ncodeunits(m.match) - 1
    s = String(data)
    head = lo > 1 ? s[1:prevind(s, lo)] : ""
    tail_start = nextind(s, hi)
    tail = tail_start <= ncodeunits(s) ? s[tail_start:end] : ""
    return string(head, replacement, tail)
end

"""Julia `keyboardState[scancode + 1]` → JS `keyboardState[scancode]` (0-based Uint8Array)."""
function fix_keyboard_state_indexing(data::AbstractString)::String
    s = String(data)
    s = replace(s, r"let check_code = Number\(scanCode\) \+ 1" => "let check_code = Number(scanCode)")
    s = replace(s, r"at index \$\{Number\(scanCode\) \+ 1\}" => "at index \${Number(scanCode)}")
    return s
end

"""Ensure keyboard state is read once per frame after the SDL event loop."""
function ensure_keyboard_poll(data::AbstractString)::String
    s = String(data)
    s = replace(
        s,
        r"//\s*let keyboardState = unsafe_wrap\(Array, \(globalThis as any\)\.JulGameSdl\.glue_SDL_GetKeyboardState\(null\), 300, false\)\s*\n\s*//\s*handle_key_event\(this, keyboardState\)" =>
            "let keyboardState = (globalThis as any).JulGameSdl.glue_SDL_GetKeyboardState(null)\n            handle_key_event(self, keyboardState)",
    )
    s = replace(
        s,
        r"let keyboardState = unsafe_wrap\(Array, \(globalThis as any\)\.JulGameSdl\.glue_SDL_GetKeyboardState\(null\), 300, false\)" =>
            "let keyboardState = (globalThis as any).JulGameSdl.glue_SDL_GetKeyboardState(null)",
    )
    # Transpiler keeps Julia's per-event keyboard poll inside the loop; wasm needs one sample per frame.
    s = replace(
        s,
        r"\n\s*let keyboardState = \(globalThis as any\)\.JulGameSdl\.glue_SDL_GetKeyboardState\(null\)\s*\n\s*handle_key_event\(self, keyboardState\)\s*\n\n\s*\}" =>
            "\n\n        }",
    )
    if !occursin(r"let keyboardState = \(globalThis as any\)\.JulGameSdl\.glue_SDL_GetKeyboardState\(null\)", s)
        s = replace(
            s,
            r"(\n\s*// if self\.isTestButtonClicked)" =>
                s"\n\n        let keyboardState = (globalThis as any).JulGameSdl.glue_SDL_GetKeyboardState(null)\n        handle_key_event(self, keyboardState)\1",
        )
    elseif !occursin(r"handle_key_event\(self, keyboardState\)", s)
        s = replace(
            s,
            r"(\n\s*// if self\.isTestButtonClicked)" =>
                s"\n\n        let keyboardState = (globalThis as any).JulGameSdl.glue_SDL_GetKeyboardState(null)\n        handle_key_event(self, keyboardState)\1",
        )
    end
    return s
end

"""Public exports expected by `ts/src/engine/runtime/transpiledInput.ts`."""
function finalize_input_exports(data::AbstractString)::String
    s = replace(String(data), r"^export \{\}\n?" => "")
    if !occursin(r"export function poll_input\b", s)
        s = replace(s, r"(\n\s*)function poll_input\b" => s"\1export function poll_input")
    end
    if !occursin("export function createInput", s)
        s *= """

    export function createInput(): Input {
        return new Input()
    }

    export type TranspiledInput = Input;
    export { Input }
"""
    end
    return s
end

"""`ui.jl` helpers referenced by `poll_input` but not emitted into `Input.ts`."""
function stub_ui_hit_test_helpers(data::AbstractString)::String
    s = String(data)
    occursin(r"function get_element_position\b", s) && return s
    stub = """
    function get_element_position(element: any): { x: number; y: number } {
        if (element?.position) {
            return { x: element.position.x, y: element.position.y }
        }
        const sprite = element?.sprite
        if (!sprite?.lastRenderedScreenPosition) {
            return { x: 0, y: 0 }
        }
        const basePosition = sprite.lastRenderedScreenPosition
        const baseSize = sprite.lastRenderedScreenSize ?? { x: 0, y: 0 }
        const interactionScale = sprite.interactionScale ?? 1
        if (interactionScale < 1) {
            const sizeDiff = {
                x: baseSize.x * (1 - interactionScale),
                y: baseSize.y * (1 - interactionScale),
            }
            return {
                x: basePosition.x + sizeDiff.x / 2,
                y: basePosition.y + sizeDiff.y / 2,
            }
        }
        return { x: basePosition.x, y: basePosition.y }
    }

    function get_element_size(element: any): { x: number; y: number } {
        if (element?.size) {
            return { x: element.size.x, y: element.size.y }
        }
        const sprite = element?.sprite
        if (!sprite?.lastRenderedScreenSize) {
            return { x: 0, y: 0 }
        }
        const baseSize = sprite.lastRenderedScreenSize
        const interactionScale = sprite.interactionScale ?? 1
        return { x: baseSize.x * interactionScale, y: baseSize.y * interactionScale }
    }

    function clicked_down_on_this_element(self: Input, element: unknown): boolean {
        return self.elementsBeingClickedDownOn.includes(element)
    }

"""
    return replace(s, r"\n    function handle_window_events" => "\n" * stub * "    function handle_window_events", count=1)
end

"""`cursor.jl` is not in `files-needed.txt`; stub bank init for wasm."""
function stub_cursor_bank(data::AbstractString)::String
    s = String(data)
    occursin(r"function create_cursor_bank\b", s) && return s
    stub = """
    function create_cursor_bank(self: Input): void {
        self.defaultCursor = null
    }

"""
    s = replace(s, r"\n    function check_scan_code" => "\n" * stub * "    function check_scan_code", count=1)
    s = replace(s, r"\n\s*this\.defaultCursor = this\.cursorBank\[\"arrow\"\]" => "")
    return s
end

"""Post-process transpiled `Input.ts` after the generic convert pipeline."""
function postprocess_input_ts(data::AbstractString, path_jl::AbstractString, path_ts::AbstractString)::String
    @assert is_input_source(path_jl)
    s = apply_line_rewrite_rules(data, input_line_rewrite_rules())
    s = replace_julia_array_membership(s)
    s = replace_sdl_out_param_spreads(s)
    s = replace_scancode_init(s)
    s = fix_poll_input_this_receiver(s)
    s = replace(s, r"handle_key_event\(this," => "handle_key_event(self,")
    s = fix_keyboard_state_indexing(s)
    s = ensure_keyboard_poll(s)
    s = stub_cursor_bank(s)
    s = stub_ui_hit_test_helpers(s)
    s = finalize_input_exports(s)
    # Recent Input.jl hit-test buffers still emit Julia Set / range syntax.
    s = replace(s, r"Set\{Any\}\(\)" => "new Set()")
    s = replace(s, r"\bempty\(_inactiveCanvasChildren\)" => "_inactiveCanvasChildren.clear()")
    s = replace(s, r"\bempty\((_hitTestCandidates|candidates)\)" => s"\1.length = 0")
    s = replace(s, r"for \(const i of (\w+)\.length:-1:1\)" => s"for (let i = \1.length - 1; i >= 0; i--)")
    s = replace(s, r"\bisa\((\w+),\s*\(globalThis as any\)\.JulGame\.ICanvas\)" => s"(\1?.children != null)")
    s = replace(s, r"_inactiveCanvasChildren\.push\(" => "_inactiveCanvasChildren.add(")
    s = replace(s, r"!\(_inactiveCanvasChildren\.includes\((\w+)\)\)" => s"!_inactiveCanvasChildren.has(\1)")
    s = replace(
        s,
        r"sort\(view\(candidates, 1:nUI\), by = uiElement => uiElement\.layer, rev = true\)" =>
            "candidates.sort((a, b) => (b.layer ?? 0) - (a.layer ?? 0))",
    )
    s = replace(
        s,
        r"sort\(view\(candidates, nUI\+1:candidates\.length\), by = entity => entity\.sprite\.layer, rev = true\)" =>
            "candidates.slice(nUI).sort((a, b) => (b.sprite?.layer ?? 0) - (a.sprite?.layer ?? 0)); candidates.splice(nUI, candidates.length - nUI, ...candidates.slice(nUI))",
    )
    # Broken transpile of `entity.sprite !== null && …` after `&&)`.
    s = replace(
        s,
        r"if \(entity\.isActive && !entity\.ignoreInputEvents &&\) \{\n\s*entity\.sprite !== null && entity\.sprite !== null &&\n\s*!(_inactiveCanvasChildren\.has\(entity\))\n\s*candidates\.push\(entity\)\n\s*\}" =>
            "if (entity.isActive && !entity.ignoreInputEvents && entity.sprite != null && !_inactiveCanvasChildren.has(entity)) {\n                candidates.push(entity)\n            }",
    )
    s = replace(s, r"return candidates, nUI" => "return [candidates, nUI] as const")
    s = replace(s, r"for \(const i of 1:(\w+)\)" => s"for (let i = 1; i <= \1; i++)")
    s = replace(s, r"for \(const i of 1:(\w+\.\w+)\)" => s"for (let i = 1; i <= \1; i++)")
    s = replace(s, r"\blib_available\(\)" => "false")
    s = replace(s, r":\s*Int\b" => ": number")
    s = replace(s, r"\blet (\w+) = \1\s*\n" => "")
    s = replace(
        s,
        r"if \(self\.joystick == null\) \{ return if \(self\.numAxes > 0\) \{ \}" =>
            "if (self.joystick == null) { return }\n        if (self.numAxes > 0) {",
    )
    # Julia 1-tuples in call args: `(scanCode[0],)` → `scanCode[0]`
    s = replace(s, r"\((\w+(?:\[[^\]]+\])?),\)" => s"\1")
    # Line rewrites above can run after the global ASI pass in `parse_file`.
    s = insert_semicolon_before_line_starting_with_open_paren(s)
    return s
end
