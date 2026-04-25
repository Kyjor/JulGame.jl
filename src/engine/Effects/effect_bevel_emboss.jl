# Krita / GIMP-style bevel & emboss (height ramp, bumpmap, contour, gloss, texture, PSD-like blends).

function _disk_offsets(radius::Int)::Vector{Tuple{Int,Int}}
    r = max(0, radius)
    offsets = Tuple{Int,Int}[]
    r2 = r * r
    for dy in -r:r, dx in -r:r
        if dx * dx + dy * dy <= r2
            push!(offsets, (dy, dx))
        end
    end
    return offsets
end

function morph_uniform(mask::Matrix{UInt8}, grow::Int)::Matrix{UInt8}
    if grow == 0
        return copy(mask)
    end

    h, w = size(mask)
    out = zeros(UInt8, h, w)
    offsets = _disk_offsets(abs(grow))
    @inbounds for y in 1:h, x in 1:w
        v = grow > 0 ? 0 : 255
        for (dy, dx) in offsets
            ny = y + dy
            nx = x + dx
            sample = if 1 <= ny <= h && 1 <= nx <= w
                mask[ny, nx]
            else
                0x00
            end
            if grow > 0
                v = max(v, Int(sample))
                if v == 255
                    break
                end
            else
                v = min(v, Int(sample))
                if v == 0
                    break
                end
            end
        end
        out[y, x] = UInt8(v)
    end
    return out
end

function paint_bevel_selection!(bump::Matrix{UInt8}, src_alpha::Matrix{UInt8}, layer_size::Int, initialSize::Int, invert::Bool; clear_dst::Bool = true)
    h, w = size(src_alpha)
    if clear_dst
        fill!(bump, 0x00)
    end
    @inbounds for i in 0:(layer_size - 1)
        grow_sz = initialSize - i - 1
        sel = UInt8(clamp(round(Int, (invert ? (layer_size - i - 1) : (i + 1)) / layer_size * 255), 0, 255))
        region = morph_uniform(src_alpha, grow_sz)
        for y in 1:h, x in 1:w
            coverage = Int(region[y, x])
            if coverage > 0
                # Krita uses `COMPOSITE_COPY` with the grown selection — equivalent to
                # mixing the new selectedness into the existing bump weighted by selection coverage.
                # Pure overwrite collapses antialiased glyph edges and creates ridge artefacts.
                prev = Int(bump[y, x])
                new_v = (Int(sel) * coverage + prev * (255 - coverage)) ÷ 255
                bump[y, x] = UInt8(clamp(new_v, 0, 255))
            end
        end
    end
end

function paint_pillow!(bump::Matrix{UInt8}, src_alpha::Matrix{UInt8}, layer_size::Int)
    half_c = Int(ceil(layer_size / 2))
    half_f = Int(floor(layer_size / 2))
    paint_bevel_selection!(bump, src_alpha, half_c, half_c, false; clear_dst = true)
    paint_bevel_selection!(bump, src_alpha, half_f, 0, true; clear_dst = false)
end

"""Extra margin so bump / morphology matches Krita (`BevelEmbossRectCalculator`: grow layer bounds by size + soften bleed + bump edge)."""
function bevel_work_margin_px(size_px::Int, soften::Float32)::Int
    sz = max(1, size_px)
    soften_r = if soften > 0.0f0
        Int(ceil(Float64(soften) * 3)) + 1
    else
        0
    end
    return sz + soften_r + 2
end

function limiting_selection_u8(src_alpha::Matrix{UInt8}, limiting_grow::Int)::Matrix{UInt8}
    return morph_uniform(src_alpha, limiting_grow)
end

function adjust_range_psd!(m::Matrix{UInt8}, range_pct::Int)
    rp = clamp(range_pct, 1, 100)
    @inbounds for i in eachindex(m)
        v = Int(m[i])
        m[i] = UInt8(min(255, v * 100 ÷ rp))
    end
end

@inline function _krita_edge_hidden_contour(i::Int)::UInt8
    if i <= 20
        return UInt8(11 * i)
    elseif i == 21
        return 0xF2
    elseif i == 22
        return 0xFD
    else
        return 0xFF
    end
end

function apply_contour_lut_simple!(data::Matrix{UInt8}, lut::Vector{UInt8}, antialiased::Bool)
    @assert length(lut) == 256
    @inbounds for i in eachindex(data)
        v = Int(data[i])
        idx = if antialiased
            v
        else
            q = Int(round(v / 2.55)) * 255 ÷ 100
            clamp(q, 0, 255)
        end
        data[i] = UInt8((Int(_krita_edge_hidden_contour(v)) * Int(lut[idx + 1])) >> 8)
    end
end

function contrast_op_texture!(tex::Matrix{UInt8}, tex_depth::Float64)
    contrastadj = 0
    td = tex_depth
    if td >= 0.0
        if td <= 100.0
            contrastadj = Int(round((1 - (td / 100.0)) * -127))
        else
            contrastadj = Int(round(((td - 100.0) / 900.0) * 127))
        end
    else
        @inbounds for i in eachindex(tex)
            tex[i] = 0xFF - tex[i]
        end
        atd = abs(td)
        if atd <= 100.0
            contrastadj = Int(round((1 - (atd / 100.0)) * -127))
        else
            contrastadj = Int(round(((atd - 100.0) / 900.0) * 127))
        end
    end
    c = clamp(contrastadj / 127.0, -1.0, 1.0)
    slant = tan((c + 1.0) * (π / 4))
    @inbounds for i in eachindex(tex)
        v = (Int(tex[i]) - 127) / 127.0
        v = (v - 0.5) * slant + 0.5
        tex[i] = UInt8(clamp(round(Int, v * 255), 0, 255))
    end
end

function _load_pattern_grayscale(path::String, tile::Bool, scale_pct::Int, ph::Int, pv::Int, bw::Int, bh::Int)::Union{Nothing,Matrix{UInt8}}
    if isempty(path)
        return nothing
    end
    full_path = isfile(path) ? path : joinpath(JulGame.BasePath, "assets", "textures", path)
    if !isfile(full_path)
        return nothing
    end
    surf = SDL2.IMG_Load(full_path)
    if surf == C_NULL
        return nothing
    end
    conv = SDL2.SDL_ConvertSurfaceFormat(surf, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
    SDL2.SDL_FreeSurface(surf)
    if conv == C_NULL
        return nothing
    end
    arr = unsafe_wrap(Array, conv, 10; own=false)
    pw, phs = arr[1].w, arr[1].h
    if SDL2.SDL_LockSurface(conv) != 0
        SDL2.SDL_FreeSurface(conv)
        return nothing
    end
    pitch = arr[1].pitch ÷ 4
    pix = Ptr{UInt32}(arr[1].pixels)
    pat = Matrix{UInt8}(undef, phs, pw)
    @inbounds for y in 1:phs
        for x in 1:pw
            p = unsafe_load(pix, (y - 1) * pitch + x)
            r = Int(p & 0xFF)
            g = Int((p >> 8) & 0xFF)
            b = Int((p >> 16) & 0xFF)
            pat[y, x] = UInt8(clamp((77r + 150g + 29b) ÷ 256, 0, 255))
        end
    end
    SDL2.SDL_UnlockSurface(conv)
    SDL2.SDL_FreeSurface(conv)
    sc = max(1, scale_pct)
    tex = Matrix{UInt8}(undef, bh, bw)
    ox = (pw * ph) ÷ 100
    oy = (phs * pv) ÷ 100
    @inbounds for y in 1:bh
        for x in 1:bw
            if tile
                px = mod(x - 1 + ox, max(1, (pw * sc) ÷ 100)) + 1
                py = mod(y - 1 + oy, max(1, (phs * sc) ÷ 100)) + 1
                px = clamp((px - 1) * 100 ÷ sc + 1, 1, pw)
                py = clamp((py - 1) * 100 ÷ sc + 1, 1, phs)
            else
                px = clamp(Int(round((x - 0.5) / bw * pw)), 1, pw)
                py = clamp(Int(round((y - 0.5) / bh * phs)), 1, phs)
            end
            tex[y, x] = pat[py, px]
        end
    end
    return tex
end

function apply_texture_to_height!(bump::Matrix{UInt8}, tex_gray::Matrix{UInt8}, texture_depth::Float64)
    contrast_op_texture!(tex_gray, texture_depth)
    @inbounds for i in eachindex(bump)
        bump[i] = UInt8(clamp((Int(bump[i]) * Int(tex_gray[i])) ÷ 255, 0, 255))
    end
end

function bumpmap_linear!(dest::Matrix{UInt8}, height::Matrix{UInt8}, azimuth::Float64, elevation::Float64, depth::Int, direction_up::Bool)
    h, w = size(height)
    padded = Matrix{UInt8}(undef, h + 2, w + 2)
    @inbounds for y in 1:h, x in 1:w
        padded[y + 1, x + 1] = height[y, x]
    end
    padded[1, :] .= padded[2, :]
    padded[h + 2, :] .= padded[h + 1, :]
    padded[:, 1] .= padded[:, 2]
    padded[:, w + 2] .= padded[:, w + 1]
    invert_lut = !direction_up
    lut = Vector{UInt8}(undef, 256)
    @inbounds for i in 0:255
        v = UInt8(i)
        lut[i + 1] = invert_lut ? (0xFF - v) : v
    end
    @inbounds for j in 1:(h + 2), i in 1:(w + 2)
        v = padded[j, i]
        padded[j, i] = lut[Int(v) + 1]
    end
    az = π * azimuth / 180.0
    el = π * elevation / 180.0
    lx = Int(round(cos(az) * cos(el) * 255))
    ly = Int(round(sin(az) * cos(el) * 255))
    lz = Int(round(sin(el) * 255))
    nz = (6 * 255) ÷ max(depth, 1)
    nz2 = nz * nz
    nzlz = nz * lz
    background = lz
    comp = sin(el)
    amb = 0
    @inbounds for y in 1:h
        r1 = @view padded[y, :]
        r2 = @view padded[y + 1, :]
        r3 = @view padded[y + 2, :]
        for x in 1:w
            x1 = x
            x2 = x + 1
            x3 = x + 2
            nx = Int(r1[x1]) + Int(r2[x1]) + Int(r3[x1]) - Int(r1[x3]) - Int(r2[x3]) - Int(r3[x3])
            ny = Int(r3[x1]) + Int(r3[x2]) + Int(r3[x3]) - Int(r1[x1]) - Int(r1[x2]) - Int(r1[x3])
            shade = if nx == 0 && ny == 0
                background
            else
                ndotl = nx * lx + ny * ly + nzlz
                if ndotl < 0
                    Int(round(comp * amb))
                else
                    s = ndotl / sqrt(nx * nx + ny * ny + nz2)
                    s + max(0.0, (255 * comp - s)) * amb / 255
                end
            end
            if comp > 1e-6
                shade = round(Int, min(255, shade / comp))
            end
            dest[y, x] = UInt8(clamp(shade, 0, 255))
        end
    end
end

function gaussian_u8_separable!(m::Matrix{UInt8}, radius::Float32)
    if radius <= 0.0f0
        return
    end
    h, w = size(m)
    ks = max(3, 2 * Int(ceil(radius * 2)) + 1)
    half = ks ÷ 2
    weights = Float32[]
    tw = 0.0f0
    for i in 0:(ks - 1)
        x = Float32(i - half)
        ww = exp(-(x * x) / (2 * radius * radius))
        push!(weights, ww)
        tw += ww
    end
    weights ./= tw
    tmp = Matrix{Float32}(undef, h, w)
    buf = Matrix{Float32}(undef, h, w)
    @inbounds for y in 1:h, x in 1:w
        buf[y, x] = Float32(m[y, x])
    end
    @inbounds for y in 1:h
        for x in 1:w
            acc = 0.0f0
            for k in 1:ks
                xx = clamp(x + k - half - 1, 1, w)
                acc += weights[k] * buf[y, xx]
            end
            tmp[y, x] = acc
        end
    end
    @inbounds for y in 1:h
        for x in 1:w
            acc = 0.0f0
            for k in 1:ks
                yy = clamp(y + k - half - 1, 1, h)
                acc += weights[k] * tmp[yy, x]
            end
            m[y, x] = UInt8(clamp(round(Int, acc), 0, 255))
        end
    end
end

"""Widen deviation from mid-gray so shadow/highlight masks survive soften and read on light glyphs."""
function amplify_lit_deviation!(lit::Matrix{UInt8}, gain::Float32)
    if gain <= 1.0f0
        return
    end
    @inbounds for i in eachindex(lit)
        d = Float32(Int(lit[i]) - 127)
        lit[i] = UInt8(clamp(round(Int, 127.0f0 + d * gain), 0, 255))
    end
end

function shadows_fetch(lit::UInt8)::UInt8
    v = Int(lit)
    UInt8(clamp(255 - round(Int, min(v, 127) * (255.0 / 127.0)), 0, 255))
end

function highlights_fetch(lit::UInt8)::UInt8
    v = Int(lit)
    UInt8(clamp(round(Int, max(0, v - 127) * (255.0 / (255 - 127))), 0, 255))
end

@inline function _blend_chan(mode::EffectsModule.BevelEmbossBlendMode, base::Float64, blend::Float64, k::Float64)::Float64
    if k <= 0.0
        return base
    end
    out = if mode == EffectsModule.BB_NORMAL
        blend * k + base * (1.0 - k)
    elseif mode == EffectsModule.BB_MULTIPLY
        m = base * blend / 255.0
        m * k + base * (1.0 - k)
    elseif mode == EffectsModule.BB_SCREEN
        s = 255.0 - (255.0 - base) * (255.0 - blend) / 255.0
        s * k + base * (1.0 - k)
    else
        o = if base < 128
            2 * base * blend / 255.0
        else
            255.0 - 2 * (255.0 - base) * (255.0 - blend) / 255.0
        end
        o * k + base * (1.0 - k)
    end
    return clamp(out, 0.0, 255.0)
end

function composite_bevel_passes!(
    out_pixels::Ptr{UInt32}, out_pitch::Int,
    base_pixels::Ptr{UInt32}, base_pitch::Int,
    w::Int, h::Int,
    shadow_m::Matrix{UInt8}, hi_m::Matrix{UInt8},
    sr::Int, sg::Int, sb::Int,
    hr::Int, hg::Int, hb::Int,
    shadow_op::Int, hi_op::Int,
    shadow_blend::EffectsModule.BevelEmbossBlendMode,
    hi_blend::EffectsModule.BevelEmbossBlendMode,
    intensity::Float64,
)
    @inbounds for y in 1:h
        for x in 1:w
            bi = (y - 1) * base_pitch + x
            bo = (y - 1) * out_pitch + x
            bp = unsafe_load(base_pixels, bi)
            ba = Int((bp >> 24) & 0xFF)
            # Outer bevel (Krita `paintBevelSelection` + outer style): height ramp sits mostly in alpha==0
            # pixels outside the glyph. Skipping them erases the whole effect on tight TTF bounds.
            if ba == 0
                sm = Int(shadow_m[y, x])
                hm = Int(hi_m[y, x])
                if sm == 0 && hm == 0
                    unsafe_store!(out_pixels, 0x00000000, bo)
                    continue
                end
                ks = (sm / 255.0) * (shadow_op / 255.0) * intensity
                kh = (hm / 255.0) * (hi_op / 255.0) * intensity
                r, g, b = 0.0, 0.0, 0.0
                if kh > 0
                    r = _blend_chan(hi_blend, r, Float64(hr), kh)
                    g = _blend_chan(hi_blend, g, Float64(hg), kh)
                    b = _blend_chan(hi_blend, b, Float64(hb), kh)
                end
                if ks > 0
                    r = _blend_chan(shadow_blend, r, Float64(sr), ks)
                    g = _blend_chan(shadow_blend, g, Float64(sg), ks)
                    b = _blend_chan(shadow_blend, b, Float64(sb), ks)
                end
                ah = min(1.0, (hm / 255.0) * (hi_op / 255.0) * intensity)
                ash = min(1.0, (sm / 255.0) * (shadow_op / 255.0) * intensity)
                ba_out = Int(round(255.0 * (1.0 - (1.0 - ah) * (1.0 - ash))))
                ba_out = clamp(ba_out, 0, 255)
                unsafe_store!(
                    out_pixels,
                    (UInt32(ba_out) << 24) | (UInt32(round(Int, b)) << 16) | (UInt32(round(Int, g)) << 8) | UInt32(round(Int, r)),
                    bo,
                )
                continue
            end
            br = Float64(bp & 0xFF)
            bg = Float64((bp >> 8) & 0xFF)
            bb = Float64((bp >> 16) & 0xFF)
            sm = Int(shadow_m[y, x])
            hm = Int(hi_m[y, x])
            ks = (sm / 255.0) * (shadow_op / 255.0) * intensity
            kh = (hm / 255.0) * (hi_op / 255.0) * intensity
            r, g, b = br, bg, bb
            # Highlight before shadow: Screen/Linear Dodge with white would erase Multiply shadows if applied last.
            if kh > 0
                r = _blend_chan(hi_blend, r, Float64(hr), kh)
                g = _blend_chan(hi_blend, g, Float64(hg), kh)
                b = _blend_chan(hi_blend, b, Float64(hb), kh)
            end
            if ks > 0
                r = _blend_chan(shadow_blend, r, Float64(sr), ks)
                g = _blend_chan(shadow_blend, g, Float64(sg), ks)
                b = _blend_chan(shadow_blend, b, Float64(sb), ks)
            end
            unsafe_store!(
                out_pixels,
                (UInt32(ba) << 24) | (UInt32(round(Int, b)) << 16) | (UInt32(round(Int, g)) << 8) | UInt32(round(Int, r)),
                bo,
            )
        end
    end
end

function surface_read_write_rgba(base::Ptr{SDL2.SDL_Surface})::Union{Nothing,Matrix{UInt32}}
    if base == C_NULL
        return nothing
    end
    arr = unsafe_wrap(Array, base, 10; own=false)
    w, h = arr[1].w, arr[1].h
    if SDL2.SDL_LockSurface(base) != 0
        return nothing
    end
    pitch = arr[1].pitch ÷ 4
    pix = Ptr{UInt32}(arr[1].pixels)
    m = Matrix{UInt32}(undef, h, w)
    @inbounds for y in 1:h, x in 1:w
        m[y, x] = unsafe_load(pix, (y - 1) * pitch + x)
    end
    SDL2.SDL_UnlockSurface(base)
    return m
end

function extract_alpha_channel(base::Ptr{SDL2.SDL_Surface})::Union{Nothing,Matrix{UInt8}}
    px = surface_read_write_rgba(base)
    if px === nothing
        return nothing
    end
    h, w = size(px)
    a = Matrix{UInt8}(undef, h, w)
    @inbounds for i in eachindex(px)
        a[i] = UInt8((px[i] >> 24) & 0xFF)
    end
    return a
end

function bevel_emboss_from_legacy(eff::EffectsModule.BevelEffect)::EffectsModule.BevelEmbossEffect
    hi = eff.highlight_color
    sh = eff.shadow_color
    hia = Int(round(hi[4] * eff.intensity))
    sha = Int(round(sh[4] * eff.intensity))
    hia = clamp(hia, 0, 255)
    sha = clamp(sha, 0, 255)
    return EffectsModule.BevelEmbossEffect(;
        style = EffectsModule.LAYER_OUTER_BEVEL,
        size_px = max(1, eff.depth),
        soften = 0.0f0,
        depth = max(1, eff.depth * 2),
        angle = eff.angle,
        altitude = 30.0,
        direction_up = true,
        highlight_color = (hi[1], hi[2], hi[3], hia),
        shadow_color = (sh[1], sh[2], sh[3], sha),
        highlight_opacity = 255,
        shadow_opacity = 255,
        highlight_blend = EffectsModule.BB_NORMAL,
        shadow_blend = EffectsModule.BB_MULTIPLY,
        intensity = 1.0,
    )
end

function bevel_emboss_from_bevel1(eff::EffectsModule.BevelEffect1)::EffectsModule.BevelEmbossEffect
    lp = eff.light_position
    ang = atan(lp.y, lp.x) * 180.0 / π
    sty = if eff.bevel_type == EffectsModule.INNER_BEVEL
        EffectsModule.LAYER_INNER_BEVEL
    elseif eff.bevel_type == EffectsModule.OUTER_BEVEL
        EffectsModule.LAYER_OUTER_BEVEL
    elseif eff.bevel_type == EffectsModule.EMBOSS_BEVEL
        EffectsModule.LAYER_EMBOSS
    elseif eff.bevel_type == EffectsModule.PILLOW_EMBOSS
        EffectsModule.LAYER_PILLOW
    else
        EffectsModule.LAYER_EMBOSS
    end
    og = eff.outer_gradient
    sg = eff.shadow_gradient
    hc = isempty(og) ? (255, 255, 255, 255) : Tuple(Int.(og[1].color))
    sc = isempty(sg) ? (0, 0, 0, 255) : Tuple(Int.(sg[end].color))
    return EffectsModule.BevelEmbossEffect(;
        style = sty,
        size_px = max(1, Int(round(eff.bevel_width))),
        soften = eff.blur_radius,
        depth = max(1, Int(round(eff.bevel_depth * 2))),
        angle = ang,
        altitude = 35.0,
        direction_up = true,
        highlight_color = (hc[1], hc[2], hc[3], Int(round(Int(hc[4]) * eff.intensity))),
        shadow_color = (sc[1], sc[2], sc[3], Int(round(Int(sc[4]) * eff.intensity))),
        highlight_blend = EffectsModule.BB_SCREEN,
        shadow_blend = EffectsModule.BB_MULTIPLY,
        intensity = Float64(eff.intensity),
    )
end

function apply_bevel_emboss_psd(base::Ptr{SDL2.SDL_Surface}, eff::EffectsModule.BevelEmbossEffect)::Ptr{SDL2.SDL_Surface}
    if base == C_NULL
        return C_NULL
    end
    arr = unsafe_wrap(Array, base, 10; own=false)
    w = Int(arr[1].w)
    h = Int(arr[1].h)
    if w <= 0 || h <= 0
        return base
    end
    alpha = extract_alpha_channel(base)
    if alpha === nothing
        return base
    end
    # `paint_bevel_selection!` + disk morphology is roughly O(size³·(w+size)(h+size)); huge
    # `size_px` values (typos like 621) effectively hang. Clamp for interactive safety.
    sz_req = max(1, Int(eff.size_px))
    sz = min(sz_req, 64)
    if sz != sz_req
        @debug "BevelEmbossEffect size_px clamped for performance" requested = sz_req applied = sz
    end
    # Krita `BevelEmbossRectCalculator` / `calcBevelNeedRect`: work on bounds grown by size (+ soften bleed); tight TTF surfaces clip the outer ramp without this.
    pad = bevel_work_margin_px(sz, eff.soften)
    H = h + 2 * pad
    W = w + 2 * pad
    alpha_pad = zeros(UInt8, H, W)
    alpha_pad[(pad+1):(pad+h), (pad+1):(pad+w)] = alpha

    bump = Matrix{UInt8}(undef, H, W)
    lim_grow = 0
    if eff.style == EffectsModule.LAYER_OUTER_BEVEL
        paint_bevel_selection!(bump, alpha_pad, sz, sz, false)
        lim_grow = sz
    elseif eff.style == EffectsModule.LAYER_INNER_BEVEL
        paint_bevel_selection!(bump, alpha_pad, sz, 0, false)
        lim_grow = 0
    elseif eff.style == EffectsModule.LAYER_EMBOSS
        init_sz = Int(ceil(sz / 2))
        paint_bevel_selection!(bump, alpha_pad, sz, init_sz, false)
        lim_grow = init_sz
    else
        paint_pillow!(bump, alpha_pad, sz)
        lim_grow = Int(ceil(sz / 2))
    end
    lim = limiting_selection_u8(alpha_pad, lim_grow)
    if eff.texture_enabled && !isempty(eff.texture_path)
        tex = _load_pattern_grayscale(
            eff.texture_path,
            eff.texture_tile,
            eff.texture_scale,
            eff.texture_phase_h_pct,
            eff.texture_phase_v_pct,
            W,
            H,
        )
        if tex !== nothing
            apply_texture_to_height!(bump, tex, eff.texture_depth)
        end
    end
    if eff.contour_enabled
        if eff.range_pct != 100
            adjust_range_psd!(bump, eff.range_pct)
        end
        apply_contour_lut_simple!(bump, eff.contour_lut, eff.contour_antialiased)
    end
    lit = Matrix{UInt8}(undef, H, W)
    bumpmap_linear!(lit, bump, eff.angle, eff.altitude, eff.depth, eff.direction_up)
    if eff.gloss_enabled
        apply_contour_lut_simple!(lit, eff.gloss_lut, eff.gloss_antialiased)
    end
    if eff.soften > 0.0f0
        gaussian_u8_separable!(lit, eff.soften)
    end
    amplify_lit_deviation!(lit, 1.25f0)
    if eff.texture_enabled && eff.texture_invert
        @inbounds for i in eachindex(lit)
            lit[i] = 0xFF - lit[i]
        end
    end
    shadow_m = similar(lit)
    hi_m = similar(lit)
    @inbounds for i in eachindex(lit)
        shadow_m[i] = shadows_fetch(lit[i])
        hi_m[i] = highlights_fetch(lit[i])
    end
    @inbounds for i in eachindex(shadow_m)
        shadow_m[i] = UInt8((Int(shadow_m[i]) * Int(lim[i])) ÷ 255)
        hi_m[i] = UInt8((Int(hi_m[i]) * Int(lim[i])) ÷ 255)
    end

    base_pad = SDL2.SDL_CreateRGBSurfaceWithFormat(0, W, H, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
    if base_pad == C_NULL
        return base
    end
    SDL2.SDL_FillRect(base_pad, C_NULL, 0x00000000)
    SDL2.SDL_SetSurfaceBlendMode(base_pad, SDL2.SDL_BLENDMODE_BLEND)
    dst_r = SDL2.SDL_Rect(Int32(pad), Int32(pad), Int32(w), Int32(h))
    SDL2.SDL_BlitSurface(base, C_NULL, base_pad, Ref(dst_r))

    out = SDL2.SDL_CreateRGBSurfaceWithFormat(0, W, H, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
    if out == C_NULL
        SDL2.SDL_FreeSurface(base_pad)
        return base
    end
    if SDL2.SDL_LockSurface(out) != 0
        SDL2.SDL_FreeSurface(out)
        SDL2.SDL_FreeSurface(base_pad)
        return base
    end
    oa = unsafe_wrap(Array, out, 10; own=false)
    opix = Ptr{UInt32}(oa[1].pixels)
    opitch = Int(oa[1].pitch ÷ 4)
    if SDL2.SDL_LockSurface(base_pad) != 0
        SDL2.SDL_UnlockSurface(out)
        SDL2.SDL_FreeSurface(out)
        SDL2.SDL_FreeSurface(base_pad)
        return base
    end
    bpa = unsafe_wrap(Array, base_pad, 10; own=false)
    bpix = Ptr{UInt32}(bpa[1].pixels)
    bpitch = Int(bpa[1].pitch ÷ 4)
    sr, sg, sb = eff.shadow_color[1:3]
    hr, hg, hb = eff.highlight_color[1:3]
    composite_bevel_passes!(
        opix,
        opitch,
        bpix,
        bpitch,
        W,
        H,
        shadow_m,
        hi_m,
        sr,
        sg,
        sb,
        hr,
        hg,
        hb,
        eff.shadow_opacity,
        eff.highlight_opacity,
        eff.shadow_blend,
        eff.highlight_blend,
        eff.intensity,
    )
    SDL2.SDL_UnlockSurface(base_pad)
    SDL2.SDL_FreeSurface(base_pad)
    SDL2.SDL_UnlockSurface(out)
    return out
end
