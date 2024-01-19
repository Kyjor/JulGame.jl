############################################## Untested ##############################################

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
    #println(ber)
    # GC.@preserve ber = unsafe_pointer_to_objref(ber)
    # println(ber)
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
    io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_RendererHasVtxOffset  # We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.
    ImGui_ImplSDLRenderer2_CreateFontsTexture(bd)
    return true
end

function ImGui_ImplSDLRenderer2_Shutdown()
    bd = ImGui_ImplSDLRenderer2_GetBackendData()
    @assert bd != C_NULL # "No renderer backend to shutdown, or already shutdown?"
    io = ImGui.GetIO()

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
    # println(bd)
#    @assert bd != C_NULL # "Did you call ImGui_ImplSDLRenderer2_Init()?"
    # bd = unsafe_load(bd)
    # println(bd)

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

function ImGui_ImplSDLRenderer2_RenderDrawData(draw_data)
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
    data = unsafe_load(draw_data)
    cmd_lists = unsafe_wrap(Vector{Ptr{ImDrawList}}, data.CmdLists, data.CmdListsCount)
    println("length: ", length(cmd_lists))
    for cmd_list in cmd_lists
        vtx_buffer = cmd_list.VtxBuffer |> unsafe_load
        idx_buffer = cmd_list.IdxBuffer |> unsafe_load

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
                # project scissor/clipping rectangles into framebuffer space
                rect = unsafe_load(pcmd.ClipRect)
                clip_rect_x = (rect.x - clip_off.x) * clip_scale.x
                clip_rect_y = (rect.y - clip_off.y) * clip_scale.y
                clip_rect_z = (rect.z - clip_off.x) * clip_scale.x
                clip_rect_w = (rect.w - clip_off.y) * clip_scale.y
                if clip_rect_x < fb_width && clip_rect_y < fb_height && clip_rect_z ≥ 0 && clip_rect_w ≥ 0
                    # apply scissor/clipping rectangle
                    ix = trunc(Cint, clip_rect_x)
                    iy = trunc(Cint, fb_height - clip_rect_w)
                    iz = trunc(Cint, clip_rect_z - clip_rect_x)
                    iw = trunc(Cint, clip_rect_w - clip_rect_y)

                    println("clipppp")
                    r = SDL2.SDL_Rect(ix, iy, iz, iw)
                    @c SDL2.SDL_RenderSetClipRect(sdlRenderer, &r)
                end

                #println("offsetof(ImDrawVert, pos): ", offsetof(ImDrawVert, pos))
                # println("idx_buffer: ", idx_buffer)
                # println("vtx_buffer: ", vtx_buffer)
                data = unsafe_load(vtx_buffer.Data)
                # println("vtx_buffer.Data: ", data.uv)
                # println("vtx_buffer.Size: ", vtx_buffer.Size)
                # println("VtxOffset unload: ", unsafe_load(pcmd.VtxOffset))
                # println("VtxOffset: ", pcmd.VtxOffset)
                # vtx_buffer_data = unsafe_load(vtx_buffer.Data)
                # println("vtx_buffer data: ", unsafe_load(vtx_buffer.Data))
                # println("ImDrawVert: ", sizeof(ImDrawVert))
                xy = Cfloat[data.pos.x,data.pos.y]#reinterpret(Cdouble, reinterpret(Cchar, vtx_buffer.Size + unsafe_load(pcmd.VtxOffset)) + 0)#offsetof(ImDrawVert, pos))
                uv = Cfloat[data.uv.x, data.uv.y]#reinterpret(Cdouble, reinterpret(Cchar, vtx_buffer.Capacity + unsafe_load(pcmd.VtxOffset)) + 0)#offsetof(ImDrawVert, uv))
                #color = Cint(1) #reinterpret(Cint, reinterpret(Cchar, vtx_buffer_data.col + unsafe_load(pcmd.VtxOffset)) + 0)#offsetof(ImDrawVert, col))
                color = SDL2.SDL_Color(255, 0, 0, 250)
                # initialize a variable of this type Ptr{Float32}

                # println("sdlRenderer: " , sdlRenderer)
                SDL2.SDL_SetRenderDrawColor(sdlRenderer, 100, 100, 100, SDL2.SDL_ALPHA_OPAQUE );


                outlineRect = Ref(SDL2.SDL_Rect(convert(Int32,64),
                convert(Int32,64),
                convert(Int32,64),
                convert(Int32,64)))
                SDL2.SDL_RenderFillRect(sdlRenderer, outlineRect)

                # Bind texture, Draw
                tex = unsafe_load(pcmd.TextureId)#::Ptr{SDL2.SDL_Texture}()
                tex1 = Ptr{SDL2.SDL_Texture}(tex)

                w = Ref{Cint}()
                h = Ref{Cint}()
                SDL2.SDL_QueryTexture(tex1, C_NULL, C_NULL, w, h)
                println("w: ", w[])
                println("h: ", h[])
                println("sizeof(ImDrawVert): ", sizeof(ImDrawVert))




println("sizeof(ImDrawVert): ", sizeof(ImDrawVert))
                println("sizeof(ImDrawIdx): ", sizeof(ImDrawIdx))
                for i = 1:1000
                    if 3%i != 0
                        continue
                    end 
                    res = SDL2.SDL_RenderGeometryRaw(sdlRenderer,
                        C_NULL,
                        pointer(xy), Int(sizeof(ImDrawVert)),
                        pointer(SDL2.SDL_Color[color]), Int(sizeof(ImDrawVert)),
                        pointer(uv), Int(sizeof(ImDrawVert)),
                        i,
                        C_NULL, unsafe_load(pcmd.ElemCount), sizeof(ImDrawIdx))

                    if res == 0
                        println("vertices drawn: ", i)
                    else
                            println("error: ", unsafe_string(SDL2.SDL_GetError()))
                        
                    end
                end
                println("pcmd.ElemCount: ", unsafe_load(pcmd.ElemCount))
                # res = SDL2.SDL_RenderGeometryRaw(sdlRenderer,
                #     C_NULL,
                #     pointer(xy), Int(sizeof(ImDrawVert)),
                #     pointer(SDL2.SDL_Color[color]), Int(sizeof(ImDrawVert)),
                #     pointer(uv), Int(sizeof(ImDrawVert)),
                #     vtx_buffer.Size+1,
                #     C_NULL, unsafe_load(pcmd.ElemCount), sizeof(ImDrawIdx))

                #     if res != 0
                #         println("error: ", unsafe_string(SDL2.SDL_GetError()))
                #     end





                # res = SDL2.SDL_RenderGeometryRaw(sdlRenderer,
                #     C_NULL,
                #     pointer(Cfloat[xy]), Int(sizeof(ImDrawVert)),
                #     pointer(SDL2.SDL_Color[color]), Int(sizeof(ImDrawVert)),
                #     (Cfloat[uv]), Int(sizeof(ImDrawVert)),
                #     10,
                #     C_NULL, unsafe_load(pcmd.ElemCount), sizeof(ImDrawIdx))

                #     println("res: ", res)
                #     if res != 0
                #         println("error: ", unsafe_string(SDL2.SDL_GetError()))
                #     end
                    # (Cfloat[uv]), Int(sizeof(ImDrawVert)),
                    # vtx_buffer.Size - unsafe_load(pcmd.VtxOffset),
                    # idx_buffer.Size + unsafe_load(pcmd.IdxOffset), unsafe_load(pcmd.ElemCount), sizeof(ImDrawIdx))
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
    io = ImGui.GetIO()
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
