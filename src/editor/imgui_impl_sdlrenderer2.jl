# SDL_Renderer data
struct ImGui_ImplSDLRenderer2_Data
    SDLRenderer::Ptr{SDL_Renderer}
    FontTexture::Ptr{SDL_Texture}
    function ImGui_ImplSDLRenderer2_Data()
        new(Ptr{SDL_Renderer}(), Ptr{SDL_Texture}())
    end
end

# Backend data stored in io.BackendRendererUserData to allow support for multiple Dear ImGui contexts
# It is STRONGLY preferred that you use docking branch with multi-viewports (== single Dear ImGui context + multiple windows) instead of multiple Dear ImGui contexts.
function ImGui_ImplSDLRenderer2_GetBackendData()
    return ImGui.GetCurrentContext() ? ImGui.GetIO().BackendRendererUserData : nothing
end

# Functions
function ImGui_ImplSDLRenderer2_Init(renderer::Ptr{SDL_Renderer})
    io = ImGui.GetIO()
    @assert io.BackendRendererUserData == nothing && "Already initialized a renderer backend!"
    @assert renderer != nothing && "SDL_Renderer not initialized!"

    # Setup backend capabilities flags
    bd = ImGui_ImplSDLRenderer2_Data()
    io.BackendRendererUserData = bd
    io.BackendRendererName = "imgui_impl_sdlrenderer2"
    io.BackendFlags |= ImGuiBackendFlags_RendererHasVtxOffset  # We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.

    bd.SDLRenderer = renderer

    true
end

function ImGui_ImplSDLRenderer2_Shutdown()
    bd = ImGui_ImplSDLRenderer2_GetBackendData()
    @assert bd != nothing && "No renderer backend to shutdown, or already shutdown?"
    io = ImGui.GetIO()

    ImGui_ImplSDLRenderer2_DestroyDeviceObjects()

    io.BackendRendererName = nothing
    io.BackendRendererUserData = nothing
    io.BackendFlags &= ~ImGuiBackendFlags_RendererHasVtxOffset
    nothing
end

function ImGui_ImplSDLRenderer2_SetupRenderState()
    bd = ImGui_ImplSDLRenderer2_GetBackendData()

    # Clear out any viewports and cliprect set by the user
    # FIXME: Technically speaking there are lots of other things we could backup/setup/restore during our render process.
    SDL_RenderSetViewport(bd.SDLRenderer, nothing)
    SDL_RenderSetClipRect(bd.SDLRenderer, nothing)
    nothing
end

function ImGui_ImplSDLRenderer2_NewFrame()
    bd = ImGui_ImplSDLRenderer2_GetBackendData()
    @assert bd != nothing && "Did you call ImGui_ImplSDLRenderer2_Init()?"

    if bd.FontTexture == nothing
        ImGui_ImplSDLRenderer2_CreateDeviceObjects()
    end
    nothing
end


function ImGui_ImplSDLRenderer2_RenderDrawData(draw_data)
    bd = ImGui_ImplSDLRenderer2_GetBackendData()

    # If there's a scale factor set by the user, use that instead
    # If the user has specified a scale factor to SDL_Renderer already via SDL_RenderSetScale(), SDL will scale whatever we pass
    # to SDL_RenderGeometryRaw() by that scale factor. In that case we don't want to be also scaling it ourselves here.
    rsx = Cdouble(1.0)
    rsy = Cdouble(1.0)
    SDL_RenderGetScale(bd.SDLRenderer, &rsx, &rsy)
    render_scale = ImVec2()
    render_scale.x = (rsx == 1.0) ? draw_data.FramebufferScale.x : 1.0
    render_scale.y = (rsy == 1.0) ? draw_data.FramebufferScale.y : 1.0

    # Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    fb_width = Int(draw_data.DisplaySize.x * render_scale.x)
    fb_height = Int(draw_data.DisplaySize.y * render_scale.y)
    if fb_width == 0 || fb_height == 0
        return
    end

    # Backup SDL_Renderer state that will be modified to restore it afterwards
    struct BackupSDLRendererState
        Viewport::SDL_Rect
        ClipEnabled::Bool
        ClipRect::SDL_Rect
    end
    old = BackupSDLRendererState()
    old.ClipEnabled = SDL_RenderIsClipEnabled(bd.SDLRenderer) == SDL_TRUE
    SDL_RenderGetViewport(bd.SDLRenderer, &old.Viewport)
    SDL_RenderGetClipRect(bd.SDLRenderer, &old.ClipRect)

    # Will project scissor/clipping rectangles into framebuffer space
    clip_off = draw_data.DisplayPos         # (0,0) unless using multi-viewports
    clip_scale = render_scale

    # Render command lists
    ImGui_ImplSDLRenderer2_SetupRenderState()
    for n = 1:draw_data.CmdListsCount
        cmd_list = draw_data.CmdLists[n]
        vtx_buffer = cmd_list.VtxBuffer.Data
        idx_buffer = cmd_list.IdxBuffer.Data

        for cmd_i = 1:cmd_list.CmdBuffer.Size
            pcmd = &cmd_list.CmdBuffer[cmd_i]
            if pcmd.UserCallback
                # User callback, registered via ImDrawList::AddCallback()
                # (ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.)
                if pcmd.UserCallback == ImDrawCallback_ResetRenderState
                    ImGui_ImplSDLRenderer2_SetupRenderState()
                else
                    pcmd.UserCallback(cmd_list, pcmd)
                end
            else
                # Project scissor/clipping rectangles into framebuffer space
                clip_min = ImVec2((pcmd.ClipRect.x - clip_off.x) * clip_scale.x, (pcmd.ClipRect.y - clip_off.y) * clip_scale.y)
                clip_max = ImVec2((pcmd.ClipRect.z - clip_off.x) * clip_scale.x, (pcmd.ClipRect.w - clip_off.y) * clip_scale.y)
                if clip_min.x < 0.0
                    clip_min.x = 0.0
                end
                if clip_min.y < 0.0
                    clip_min.y = 0.0
                end
                if clip_max.x > Float32(fb_width)
                    clip_max.x = Float32(fb_width)
                end
                if clip_max.y > Float32(fb_height)
                    clip_max.y = Float32(fb_height)
                end
                if clip_max.x <= clip_min.x || clip_max.y <= clip_min.y
                    continue
                end

                r = SDL_Rect(Int(clip_min.x), Int(clip_min.y), Int(clip_max.x - clip_min.x), Int(clip_max.y - clip_min.y))
                SDL_RenderSetClipRect(bd.SDLRenderer, &r)

                xy = reinterpret(Cdouble, reinterpret(Cchar, vtx_buffer + pcmd.VtxOffset) + offsetof(ImDrawVert, pos))
                uv = reinterpret(Cdouble, reinterpret(Cchar, vtx_buffer + pcmd.VtxOffset) + offsetof(ImDrawVert, uv))
                color = reinterpret(Cint, reinterpret(Cchar, vtx_buffer + pcmd.VtxOffset) + offsetof(ImDrawVert, col))

                # Bind texture, Draw
                tex = reinterpret(SDL_Texture, pcmd.GetTexID())
                SDL_RenderGeometryRaw(bd.SDLRenderer, tex,
                    xy, Int(sizeof(ImDrawVert)),
                    color, Int(sizeof(ImDrawVert)),
                    uv, Int(sizeof(ImDrawVert)),
                    cmd_list.VtxBuffer.Size - pcmd.VtxOffset,
                    idx_buffer + pcmd.IdxOffset, pcmd.ElemCount, sizeof(ImDrawIdx))
            end
        end
    end

    # Restore modified SDL_Renderer state
    SDL_RenderSetViewport(bd.SDLRenderer, &old.Viewport)
    SDL_RenderSetClipRect(bd.SDLRenderer, old.ClipEnabled ? &old.ClipRect : nullptr)
end

function ImGui_ImplSDLRenderer2_CreateFontsTexture()
    io = ImGui.GetIO()
    bd = ImGui_ImplSDLRenderer2_GetBackendData()

    # Build texture atlas
    pixels, width, height = io.Fonts.GetTexDataAsRGBA32()  # Load as RGBA 32-bit (75% of the memory is wasted, but default font is so small) because it is more likely to be compatible with user's existing shaders. If your ImTextureId represent a higher-level concept than just a GL texture id, consider calling GetTexDataAsAlpha8() instead to save on GPU memory.

    # Upload texture to graphics system
    # (Bilinear sampling is required by default. Set 'io.Fonts.Flags |= ImFontAtlasFlags_NoBakedLines' or 'style.AntiAliasedLinesUseTex = false' to allow point/nearest sampling)
    bd.FontTexture = SDL_CreateTexture(bd.SDLRenderer, SDL_PIXELFORMAT_ABGR8888, SDL_TEXTUREACCESS_STATIC, width, height)
    if bd.FontTexture == nothing
        SDL_Log("error creating texture")
        return false
    end
    SDL_UpdateTexture(bd.FontTexture, nothing, pixels, 4 * width)
    SDL_SetTextureBlendMode(bd.FontTexture, SDL_BLENDMODE_BLEND)
    SDL_SetTextureScaleMode(bd.FontTexture, SDL_ScaleModeLinear)

    # Store our identifier
    io.Fonts.SetTexID(unsafe_convert(ImTextureID, pointer_from_objref(bd.FontTexture)))

    return true
end

function ImGui_ImplSDLRenderer2_DestroyFontsTexture()
    io = ImGui.GetIO()
    bd = ImGui_ImplSDLRenderer2_GetBackendData()
    if bd.FontTexture != nothing
        io.Fonts.SetTexID(0)
        SDL_DestroyTexture(bd.FontTexture)
        bd.FontTexture = nothing
    end
end

function ImGui_ImplSDLRenderer2_CreateDeviceObjects()
    return ImGui_ImplSDLRenderer2_CreateFontsTexture()
end

function ImGui_ImplSDLRenderer2_DestroyDeviceObjects()
    ImGui_ImplSDLRenderer2_DestroyFontsTexture()
end
