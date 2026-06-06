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
    if occursin(r"handle_key_event\(self, keyboardState\)", s)
        return s
    end
    s = replace(
        s,
        r"(\n\s*// if this\.isTestButtonClicked)" =>
            s"\n\n        let keyboardState = (globalThis as any).JulGameSdl.glue_SDL_GetKeyboardState(null)\n        handle_key_event(self, keyboardState)\1",
    )
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

"""Post-process transpiled `Input.ts` after the generic convert pipeline."""
function postprocess_input_ts(data::AbstractString, path_jl::AbstractString, path_ts::AbstractString)::String
    @assert is_input_source(path_jl)
    s = apply_line_rewrite_rules(data, input_line_rewrite_rules())
    s = replace_julia_array_membership(s)
    s = replace_sdl_out_param_spreads(s)
    s = replace_scancode_init(s)
    s = fix_poll_input_this_receiver(s)
    s = replace(s, r"handle_key_event\(this," => "handle_key_event(self,")
    s = ensure_keyboard_poll(s)
    s = finalize_input_exports(s)
    # Line rewrites above can run after the global ASI pass in `parse_file`.
    s = insert_semicolon_before_line_starting_with_open_paren(s)
    return s
end
