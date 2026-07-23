# Freestanding shell SDL entrypoints (Phase 0).

const SDL_EVENT_BYTES = UInt64(64)
const SDL_EVENT_QUIT = UInt32(0x100)

# Returns 0 on success, -1 on failure. VIDEO only for Phase 0.2+.
function j_sdl_init()
    init_flags::UInt32 = SDL_INIT_VIDEO
    if llvm_SDL_Init(init_flags) != Int32(0)
        return Int32(-1)
    end
    return Int32(0)
end

function j_sdl_quit()
    llvm_SDL_Quit()
    return Int32(0)
end

# Phase 0.3: create window + renderer, store in C globals.
# Returns 0 on success, 1 on failure.
function jg_engine_init()
    if j_sdl_init() != Int32(0)
        return Int32(1)
    end

    window::Ptr{Cvoid} = llvm_SDL_CreateWindow_julgame(
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        Int32(800),
        Int32(600),
        SDL_WINDOW_SHOWN,
    )
    if window == C_NULL
        llvm_SDL_Quit()
        return Int32(1)
    end

    flags::UInt32 = SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
    renderer::Ptr{Cvoid} = llvm_SDL_CreateRenderer(window, Int32(-1), flags)
    if renderer == C_NULL
        llvm_SDL_DestroyWindow(window)
        llvm_SDL_Quit()
        return Int32(1)
    end

    llvm_jg_set_window(window)
    llvm_jg_set_renderer(renderer)
    return Int32(0)
end

# Returns 1 if quit requested.
function jg_poll_quit()
    event_ptr::Ptr{Cvoid} = jg_malloc(SDL_EVENT_BYTES)
    if event_ptr == C_NULL
        return Int32(0)
    end

    quit::Int32 = Int32(0)
    while llvm_SDL_PollEvent(event_ptr) != Int32(0)
        event_type::UInt32 = unsafe_load(Ptr{UInt32}(event_ptr))
        if event_type == SDL_EVENT_QUIT
            # Ignore spurious QUIT before first present (sc-game / some WMs).
            if llvm_jg_get_frames_rendered() != Int32(0)
                quit = Int32(1)
            end
        end
    end

    jg_free(event_ptr)
    return quit
end

# Phase 0.4: clear + present one frame. Returns 1 = continue, 0 = stop.
function jg_frame()
    if jg_poll_quit() != Int32(0)
        return Int32(0)
    end

    renderer::Ptr{Cvoid} = llvm_jg_get_renderer()
    if renderer == C_NULL
        return Int32(0)
    end

    llvm_SDL_SetRenderDrawColor(renderer, UInt8(40), UInt8(120), UInt8(200), UInt8(255))
    llvm_SDL_RenderClear(renderer)
    llvm_SDL_RenderPresent(renderer)
    llvm_jg_note_frame_rendered()
    return Int32(1)
end

# Phase 0.5: destroy renderer/window, clear globals, SDL_Quit.
function jg_engine_shutdown()
    renderer::Ptr{Cvoid} = llvm_jg_get_renderer()
    window::Ptr{Cvoid} = llvm_jg_get_window()

    if renderer != C_NULL
        llvm_SDL_DestroyRenderer(renderer)
    end
    if window != C_NULL
        llvm_SDL_DestroyWindow(window)
    end

    llvm_jg_set_renderer(C_NULL)
    llvm_jg_set_window(C_NULL)
    llvm_SDL_Quit()
    return Int32(0)
end
