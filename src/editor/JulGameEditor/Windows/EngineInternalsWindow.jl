function _cache_buf256_from_str(s::String)
    buf = zeros(UInt8, 256)
    u = codeunits(s)
    n = min(length(u), 255)
    for i in 1:n
        buf[i] = u[i]
    end
    return buf
end

const ENGINE_INTERNALS_FILTER_BUF = _cache_buf256_from_str("")
const ENGINE_INTERNALS_SELECTED_CACHE = Ref("")
const ENGINE_INTERNALS_SELECTED_KEY = Ref("")
const ENGINE_INTERNALS_SELECTED_TEXTURE = Ref{Ptr{SDL2.SDL_Texture}}(C_NULL)

function _cache_str_from_buf256(buf::Vector{UInt8})::String
    i = findfirst(iszero, buf)
    lasti = i === nothing ? length(buf) : i - 1
    lasti < 1 && return ""
    return String(buf[1:lasti])
end

function _query_texture_size(texture)
    if texture == C_NULL
        return 0, 0, false
    end
    w = Ref{Cint}(0)
    h = Ref{Cint}(0)
    fmt = Ref{UInt32}(0)
    access = Ref{Cint}(0)
    ok = SDL2.SDL_QueryTexture(texture, fmt, access, w, h) == 0
    return Int(w[]), Int(h[]), ok
end

function _cache_key_matches_filter(key_text::String, filter::String)
    isempty(filter) && return true
    return occursin(lowercase(filter), lowercase(key_text))
end

function _draw_cache_entry_row(cache_name::String, key_text::String, entry, row_idx::Int, filter::String, selected)
    _cache_key_matches_filter(key_text, filter) || return false

    label = "$(key_text)##$(cache_name)_$(row_idx)"
    clicked = CImGui.Selectable(label, selected[])
    CImGui.SameLine()

    texture = get(entry, :texture, C_NULL)
    width = get(entry, :width, 0)
    height = get(entry, :height, 0)
    approx_bytes = get(entry, :approxBytes, get(entry, :bytes, width * height * 4))

    CImGui.TextDisabled("($(width)x$(height), $(approx_bytes) B)")

    if clicked
        selected[] = true
        return true
    end
    return false
end

function _draw_cache_section(cache_name::String, entries, filter::String, selected_cache::Base.RefValue{String}, selected_key::Base.RefValue{String}, selected_texture::Base.RefValue{Ptr{SDL2.SDL_Texture}})
    header = "$(cache_name) ($(length(entries)))"
    if !CImGui.CollapsingHeader(header)
        return
    end
    if isempty(entries)
        CImGui.TextDisabled("No entries")
        return
    end

    for (i, entry) in enumerate(entries)
        key_text = string(get(entry, :key, ""))
        is_selected = Ref(selected_cache[] == cache_name && selected_key[] == key_text)
        if _draw_cache_entry_row(cache_name, key_text, entry, i, filter, is_selected)
            selected_cache[] = cache_name
            selected_key[] = key_text
            selected_texture[] = get(entry, :texture, C_NULL)
        end
    end
end

function _draw_effect_cache_stats()
    snapshot = JulGame.EffectCacheModule.get_global_cache_snapshot()
    stats = snapshot.stats
    CImGui.Text("Entries: $(stats.entries)")
    CImGui.SameLine()
    CImGui.Text("| Used: $(stats.usedBytes) / $(stats.maxBytes) bytes ($(round(stats.usagePercent; digits=1))%)")
end

function _draw_selected_texture_preview(selected_texture::Base.RefValue{Ptr{SDL2.SDL_Texture}}, selected_cache::Base.RefValue{String}, selected_key::Base.RefValue{String})
    CImGui.Separator()
    CImGui.Text("Selected Preview")
    CImGui.TextDisabled("Cache: $(selected_cache[])")
    CImGui.TextWrapped("Key: $(selected_key[])")

    tex = selected_texture[]
    if tex == C_NULL
        CImGui.TextDisabled("No texture selected.")
        return
    end

    tw, th, ok = _query_texture_size(tex)
    if !ok || tw <= 0 || th <= 0
        CImGui.TextColored((1.0f0, 0.7f0, 0.2f0, 1.0f0), "Texture preview unavailable (stale or invalid pointer).")
        return
    end

    max_dim = 256.0f0
    sx = max_dim / max(1.0f0, Float32(tw))
    sy = max_dim / max(1.0f0, Float32(th))
    scale = min(1.0f0, min(sx, sy))
    preview_size = ImVec2(Float32(tw) * scale, Float32(th) * scale)
    CImGui.Text("Texture: $(tw)x$(th)")
    CImGui.Image(tex, preview_size)
end

function show_engine_internals_window()
    SHOW_ENGINE_INTERNALS_WINDOW[] || return

    is_open = Ref(SHOW_ENGINE_INTERNALS_WINDOW[])
    CImGui.Begin("Engine Internals", is_open)
    SHOW_ENGINE_INTERNALS_WINDOW[] = is_open[]
    if !is_open[]
        CImGui.End()
        return
    end

    CImGui.Text("Effect Cache Inspector")
    CImGui.Separator()
    CImGui.SetNextItemWidth(280)
    CImGui.InputText("Filter key", ENGINE_INTERNALS_FILTER_BUF, length(ENGINE_INTERNALS_FILTER_BUF))
    filter_text = _cache_str_from_buf256(ENGINE_INTERNALS_FILTER_BUF)

    _draw_effect_cache_stats()
    CImGui.Separator()

    tb_entries = JulGame.UI.TextBoxModule.get_effect_cache_snapshot()
    img_entries = JulGame.UI.UIImageModule.get_effect_cache_snapshot()
    rect_entries = JulGame.UI.RectangleModule.get_effect_cache_snapshot()
    sprite_entries = JulGame.Component.SpriteModule.get_effect_cache_snapshot()
    global_entries = JulGame.EffectCacheModule.get_global_cache_snapshot().entries

    _draw_cache_section("TextBox", tb_entries, filter_text, ENGINE_INTERNALS_SELECTED_CACHE, ENGINE_INTERNALS_SELECTED_KEY, ENGINE_INTERNALS_SELECTED_TEXTURE)
    _draw_cache_section("UIImage", img_entries, filter_text, ENGINE_INTERNALS_SELECTED_CACHE, ENGINE_INTERNALS_SELECTED_KEY, ENGINE_INTERNALS_SELECTED_TEXTURE)
    _draw_cache_section("Rectangle", rect_entries, filter_text, ENGINE_INTERNALS_SELECTED_CACHE, ENGINE_INTERNALS_SELECTED_KEY, ENGINE_INTERNALS_SELECTED_TEXTURE)
    _draw_cache_section("SpriteEffectCache", sprite_entries, filter_text, ENGINE_INTERNALS_SELECTED_CACHE, ENGINE_INTERNALS_SELECTED_KEY, ENGINE_INTERNALS_SELECTED_TEXTURE)
    _draw_cache_section("EffectCacheModule", global_entries, filter_text, ENGINE_INTERNALS_SELECTED_CACHE, ENGINE_INTERNALS_SELECTED_KEY, ENGINE_INTERNALS_SELECTED_TEXTURE)

    _draw_selected_texture_preview(ENGINE_INTERNALS_SELECTED_TEXTURE, ENGINE_INTERNALS_SELECTED_CACHE, ENGINE_INTERNALS_SELECTED_KEY)

    CImGui.End()
end
