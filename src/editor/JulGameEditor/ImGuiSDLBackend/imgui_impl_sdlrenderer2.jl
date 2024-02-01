# https://github.com/ocornut/imgui/blob/master/backends/imgui_impl_sdlrenderer2.cpp
# SDL2.SDL_Renderer data
Base.@kwdef mutable struct ImGui_ImplSDLRenderer2_Data
    SDLRenderer::Ptr{SDL2.SDL_Renderer}
    FontTexture::Ptr{SDL2.SDL_Texture}
end

# Backend data stored in io.BackendRendererUserData to allow support for multiple Dear ImGui contexts
# It is STRONGLY preferred that you use docking branch with multi-viewports (== single Dear ImGui context + multiple windows) instead of multiple Dear ImGui contexts.
function ImGui_ImplSDLRenderer2_GetBackendData()
    io::Ptr{ImGuiIO} = CImGui.GetIO()
    ber = unsafe_load(io.BackendRendererUserData)
    return CImGui.GetCurrentContext() != C_NULL ? ber : C_NULL
end

# Functions
function ImGui_ImplSDLRenderer2_Init(renderer::Ptr{SDL2.SDL_Renderer})
    io = CImGui.GetIO()
    @assert unsafe_load(io.BackendRendererUserData) == C_NULL#  "Already initialized a renderer backend!"
    @assert renderer !== C_NULL && renderer != C_NULL #&& "SDL2.SDL_Renderer not initialized!"

    # Setup backend capabilities flags
    println(unsafe_load(io.BackendRendererUserData))
    bd = ImGui_ImplSDLRenderer2_Data(renderer, C_NULL)
    #GC.@preserve io.BackendRendererUserData = pointer_from_objref(bd)
    io.BackendRendererName = pointer("imgui_impl_sdlrenderer2")
    io.BackendFlags = unsafe_load(io.BackendFlags) #| ImGuiBackendFlags_RendererHasVtxOffset  # We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.
    ImGui_ImplSDLRenderer2_CreateFontsTexture(bd)
    return true
end

function ImGui_ImplSDLRenderer2_Shutdown()
    bd = ImGui_ImplSDLRenderer2_GetBackendData()
#    @assert bd != C_NULL # "No renderer backend to shutdown, or already shutdown?"
    io = CImGui.GetIO()

    ImGui_ImplSDLRenderer2_DestroyDeviceObjects()

    io.BackendRendererName = C_NULL
    io.BackendRendererUserData = C_NULL
    io.BackendFlags &= ~ImGuiBackendFlags_RendererHasVtxOffset
end

function ImGui_ImplSDLRenderer2_SetupRenderState()
    bd = ImGui_ImplSDLRenderer2_GetBackendData()

    # Clear out any viewports and cliprect set by the user
    # FIXME: Technically speaking there are lots of other things we could backup/setup/restore during our render process.
    # SDL2.SDL_RenderSetViewport(bd.SDLRenderer, C_NULL)
    # SDL2.SDL_RenderSetClipRect(bd.SDLRenderer, C_NULL)
    SDL2.SDL_RenderSetViewport(sdlRenderer, C_NULL)
    SDL2.SDL_RenderSetClipRect(sdlRenderer, C_NULL)
end

function ImGui_ImplSDLRenderer2_NewFrame()
    #todo
    bd = ImGui_ImplSDLRenderer2_GetBackendData()
#    @assert bd != C_NULL # "Did you call ImGui_ImplSDLRenderer2_Init()?"
    # bd = unsafe_load(bd)

    # if bd.FontTexture == C_NULL
    # if bd == C_NULL
    #     println("ImGui_ImplSDLRenderer2_NewFrame")
    #     ImGui_ImplSDLRenderer2_CreateDeviceObjects()
    # end
    # end
end

# Backup SDL2.SDL_Renderer state that will be modified to restore it afterwards
Base.@kwdef mutable struct BackupSDLRendererState
    Viewport::SDL2.SDL_Rect
    ClipEnabled::Bool
    ClipRect::SDL2.SDL_Rect
end

function ImGui_ImplSDLRenderer2_RenderDrawData(draw_data, callback)
    bd = ImGui_ImplSDLRenderer2_GetBackendData()

    # If there's a scale factor set by the user, use that instead
    # If the user has specified a scale factor to SDL2.SDL_Renderer already via SDL2.SDL_RenderSetScale(), SDL will scale whatever we pass
    # to SDL2.SDL_RenderGeometryRaw() by that scale factor. In that case we don't want to be also scaling it ourselves here.
    rsx = Cdouble(1.0)
    rsy = Cdouble(1.0)
    #@c SDL2.SDL_RenderGetScale(bd.SDLRenderer, &rsx, &rsy)
    render_scale = ImVec2((rsx == 1.0) ? unsafe_load(draw_data.FramebufferScale.x) : 1.0,(rsy == 1.0) ? unsafe_load(draw_data.FramebufferScale.y) : 1.0)

    # Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    fb_width = Int(unsafe_load(draw_data.DisplaySize.x) * render_scale.x)
    fb_height = Int(unsafe_load(draw_data.DisplaySize.y) * render_scale.y)
    if fb_width == 0 || fb_height == 0
        return
    end

    # old = BackupSDLRendererState()
    # # old.ClipEnabled = SDL2.SDL_RenderIsClipEnabled(bd.SDLRenderer) == SDL2.SDL_TRUE
    # # @c SDL2.SDL_RenderGetViewport(bd.SDLRenderer, &old.Viewport)
    # # @c SDL2.SDL_RenderGetClipRect(bd.SDLRenderer, &old.ClipRect)
    # # old.ClipEnabled = SDL2.SDL_RenderIsClipEnabled(bd.SDLRenderer) == SDL2.SDL_TRUE
    # @c SDL2.SDL_RenderGetViewport(sdlRenderer, old.Viewport)
    # @c SDL2.SDL_RenderGetClipRect(sdlRenderer, old.ClipRect)

    # will project scissor/clipping rectangles into framebuffer space
    clip_off = unsafe_load(draw_data.DisplayPos)         # (0,0) unless using multi-viewports
    clip_scale = unsafe_load(draw_data.FramebufferScale) # (1,1) unless using retina display which are often (2,2)

    # Render command lists
    ImGui_ImplSDLRenderer2_SetupRenderState()
    callback(sdlRenderer)
    data = unsafe_load(draw_data)
    cmd_lists = unsafe_wrap(Vector{Ptr{ImDrawList}}, data.CmdLists, data.CmdListsCount)
    
    innercount = 0
    for cmd_list in cmd_lists
        # cmd_list is of type IMDrawList
        # struct ImDrawList
        #     CmdBuffer::ImVector_ImDrawCmd
        #     IdxBuffer::ImVector_ImDrawIdx
        #     VtxBuffer::ImVector_ImDrawVert
        #     Flags::ImDrawListFlags
        #     _VtxCurrentIdx::Cuint
        #     _Data::Ptr{ImDrawListSharedData}
        #     _OwnerName::Ptr{Cchar}
        #     _VtxWritePtr::Ptr{ImDrawVert}
        #     _IdxWritePtr::Ptr{ImDrawIdx}
        #     _ClipRectStack::ImVector_ImVec4
        #     _TextureIdStack::ImVector_ImTextureID
        #     _Path::ImVector_ImVec2
        #     _CmdHeader::ImDrawCmdHeader
        #     _Splitter::ImDrawListSplitter
        #     _FringeScale::Cfloat
        # end
        
        vtx_buffer = cmd_list.VtxBuffer |> unsafe_load
        idx_buffer = cmd_list.IdxBuffer |> unsafe_load
        #println("Window Name: ", unsafe_string(unsafe_load(cmd_list._OwnerName)))
        cmd_buffer = cmd_list.CmdBuffer |> unsafe_load
        
        for cmd_i = 0:cmd_buffer.Size-1
            pcmd = cmd_buffer.Data + cmd_i * sizeof(ImDrawCmd)
            elem_count = unsafe_load(pcmd.ElemCount)
            cb_funcptr = unsafe_load(pcmd.UserCallback)
            if cb_funcptr != C_NULL
                # User callback, registered via ImDrawList::AddCallback()
                # (ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.)
                if cb_funcptr == ctx.ImDrawCallback_ResetRenderState
                    ImGui_ImplSDLRenderer2_SetupRenderState()
                else
                    ccall(cb_funcptr, Cvoid, (Ptr{ImDrawList}, Ptr{ImDrawCmd}), cmd_list, pcmd)
                end
            else
                # Project scissor/clipping rectangles into framebuffer space
                clip_min =ImVec2((unsafe_load(pcmd.ClipRect.x) - clip_off.x) * clip_scale.x, (unsafe_load(pcmd.ClipRect.y) - clip_off.y) * clip_scale.y)
                clip_max = ImVec2((unsafe_load(pcmd.ClipRect.z) - clip_off.x) * clip_scale.x, (unsafe_load(pcmd.ClipRect.w) - clip_off.y) * clip_scale.y)
                if clip_min.x < 0.0
                    clip_min.x = 0.0 
                end
                if clip_min.y < 0.0  
                    clip_min.y = 0.0
                end
                if clip_max.x > fb_width 
                     clip_max.x = fb_width
                end
                if clip_max.y > fb_height 
                    clip_max.y = fb_height
                end
                if clip_max.x <= clip_min.x || clip_max.y <= clip_min.y
                    continue
                end

                #     r = SDL2.SDL_Rect(ix, iy, iz, iw)
                r = SDL2.SDL_Rect((Int)(round(clip_min.x)), (Int)(round(clip_min.y)), (Int)(round(clip_max.x - clip_min.x)), (Int)(round(clip_max.y - clip_min.y)))

                @c SDL2.SDL_RenderSetClipRect(sdlRenderer, &r) # This prevents rendering to outside of the current window. For example, if you have a window that is 800x600 and you try to render a 1000x1000 image, it will only render the part that is inside the window.
                
                    color = unsafe_load(vtx_buffer.Data).col
                    r = (color >> 16) & 0xFF
                    g = (color >> 8) & 0xFF
                    b = color & 0xFF

                    color = SDL2.SDL_Color(r, g, b, 250)

                    pos_offset = fieldoffset(ImDrawVert, 1)
                    uv_offset = fieldoffset(ImDrawVert, 2)
                    col_offset = fieldoffset(ImDrawVert, 3)
                    xy = Ptr{Cfloat}(Ptr{Cchar}(vtx_buffer.Data + unsafe_load(pcmd.VtxOffset)) + pos_offset)
                    uv = Ptr{Cfloat}(Ptr{Cchar}(vtx_buffer.Data + unsafe_load(pcmd.VtxOffset)) + uv_offset)
                    color = Ptr{Int}(Ptr{Cchar}(vtx_buffer.Data + unsafe_load(pcmd.VtxOffset)) + col_offset)
                    
                    tex = Ptr{SDL2.SDL_Texture}(ImDrawCmd_GetTexID(pcmd))
                    
                    res = SDL2.SDL_RenderGeometryRaw(sdlRenderer,
                        tex,
                        xy, Int(sizeof(ImDrawVert)),
                        color, Int(sizeof(ImDrawVert)),
                        uv, Int(sizeof(ImDrawVert)),
                        vtx_buffer.Size-unsafe_load(pcmd.VtxOffset),
                        Ptr{Cvoid}(unsafe_load(pcmd.IdxOffset) + idx_buffer.Data), unsafe_load(pcmd.ElemCount), sizeof(ImDrawIdx))

                        if res != 0
                            println("error: ", unsafe_string(SDL2.SDL_GetError()))
                        end
            end
        end
    end

    # Restore modified SDL2.SDL_Renderer state
    #@c SDL2.SDL_RenderSetViewport(bd.SDLRenderer, &old.Viewport)
    #@c SDL2.SDL_RenderSetClipRect(bd.SDLRenderer, old.ClipEnabled ? &old.ClipRect : nullptr)
end

function ImGui_ImplSDLRenderer2_CreateFontsTexture()
    io = ImGui.GetIO()
    bd = ImGui_ImplSDLRenderer2_GetBackendData()

    # Build texture atlas
    pixels, width, height = io.Fonts.GetTexDataAsRGBA32()  # Load as RGBA 32-bit (75% of the memory is wasted, but default font is so small) because it is more likely to be compatible with user's existing shaders. If your ImTextureId represent a higher-level concept than just a GL texture id, consider calling GetTexDataAsAlpha8() instead to save on GPU memory.

    # Upload texture to graphics system
    # (Bilinear sampling is required by default. Set 'io.Fonts.Flags |= ImFontAtlasFlags_NoBakedLines' or 'style.AntiAliasedLinesUseTex = false' to allow point/nearest sampling)
    bd.FontTexture = SDL2.SDL_CreateTexture(bd.SDLRenderer, SDL2.SDL_PIXELFORMAT_ABGR8888, SDL2.SDL_TEXTUREACCESS_STATIC, width, height)
    if bd.FontTexture == C_NULL
        SDL2.SDL_Log("error creating texture")
        return false
    end
    SDL2.SDL_UpdateTexture(bd.FontTexture, C_NULL, pixels, 4 * width)
    SDL2.SDL_SetTextureBlendMode(bd.FontTexture, SDL2.SDL_BLENDMODE_BLEND)
    SDL2.SDL_SetTextureScaleMode(bd.FontTexture, SDL2.SDL_ScaleModeLinear)

    # Store our identifier
    io.Fonts.SetTexID(unsafe_convert(ImTextureID, pointer_from_objref(bd.FontTexture)))

    return true
end
function ImGui_ImplSDLRenderer2_CreateFontsTexture(bd)
    # Build texture atlas
    fonts = unsafe_load(igGetIO().Fonts)
    pixels = Ptr{Cuchar}(C_NULL)
    width, height = Cint(0), Cint(0)
    @c ImFontAtlas_GetTexDataAsRGBA32(fonts, &pixels, &width, &height, C_NULL)

    # Upload texture to graphics system
    # (Bilinear sampling is required by default. Set 'io.Fonts.Flags |= ImFontAtlasFlags_NoBakedLines' or 'style.AntiAliasedLinesUseTex = false' to allow point/nearest sampling)
    bd.FontTexture = SDL2.SDL_CreateTexture(bd.SDLRenderer, SDL2.SDL_PIXELFORMAT_ABGR8888, SDL2.SDL_TEXTUREACCESS_STATIC, width, height)
    if bd.FontTexture == C_NULL
        println("error creating texture")
        return false
    end
    println("font texture: ", bd.FontTexture)
    SDL2.SDL_UpdateTexture(bd.FontTexture, C_NULL, pixels, 4 * width)
    SDL2.SDL_SetTextureBlendMode(bd.FontTexture, SDL2.SDL_BLENDMODE_BLEND)
    SDL2.SDL_SetTextureScaleMode(bd.FontTexture, SDL2.SDL_ScaleModeLinear)

    # store our identifier
    ImFontAtlas_SetTexID(fonts, ImTextureID(Int(bd.FontTexture)))

    return true
end

function ImGui_ImplSDLRenderer2_DestroyFontsTexture()
    io = CImGui.GetIO()
    bd = ImGui_ImplSDLRenderer2_GetBackendData()
    if bd.FontTexture != C_NULL
        io.Fonts.SetTexID(0)
        SDL2.SDL_DestroyTexture(bd.FontTexture)
        bd.FontTexture = C_NULL
    end
end

function ImGui_ImplSDLRenderer2_CreateDeviceObjects()
    return ImGui_ImplSDLRenderer2_CreateFontsTexture()
end

function ImGui_ImplSDLRenderer2_DestroyDeviceObjects()
    ImGui_ImplSDLRenderer2_DestroyFontsTexture()
end

## reference
# struct ImDrawListSharedData
        #     TexUvWhitePixel::ImVec2
        #     Font::Ptr{ImFont}
        #     FontSize::Cfloat
        #     CurveTessellationTol::Cfloat
        #     CircleSegmentMaxError::Cfloat
        #     ClipRectFullscreen::ImVec4
        #     InitialFlags::ImDrawListFlags
        #     TempBuffer::ImVector_ImVec2
        #     ArcFastVtx::NTuple{48, ImVec2}
        #     ArcFastRadiusCutoff::Cfloat
        #     CircleSegmentCounts::NTuple{64, ImU8}
        #     TexUvLines::Ptr{ImVec4}
        # end


        # struct ImVector_ImDrawCmd
        #     Size::Cint
        #     Capacity::Cint
        #     Data::Ptr{ImDrawCmd}
        # end
        # struct ImDrawCmd
        #     ClipRect::ImVec4
        #     TextureId::ImTextureID
        #     VtxOffset::Cuint
        #     IdxOffset::Cuint
        #     ElemCount::Cuint
        #     UserCallback::ImDrawCallback
        #     UserCallbackData::Ptr{Cvoid}
        # end

        # const ImDrawIdx = Cushort
        # struct ImVector_ImDrawIdx
        #     Size::Cint
        #     Capacity::Cint
        #     Data::Ptr{ImDrawIdx}
        # end

        # struct ImDrawVert
        #     pos::ImVec2
        #     uv::ImVec2
        #     col::ImU32
        # end
        
        # struct ImVector_ImDrawVert
        #     Size::Cint
        #     Capacity::Cint
        #     Data::Ptr{ImDrawVert}
        # end