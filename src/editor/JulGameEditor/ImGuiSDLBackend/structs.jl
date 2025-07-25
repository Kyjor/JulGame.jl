@generated function offsetof(::Type{X}, ::Val{field}) where {X,field}
    idx = findfirst(f->f==field, fieldnames(X))
    return fieldoffset(X, idx)
end

struct ImGui_ImplSDL2_Data
    Window::Ptr{SDL2.SDL_Window}
    WindowID::UInt32
    Renderer::Ptr{SDL2.SDL_Renderer}
    Time::UInt64
    ClipboardTextData::Ptr{Cchar}
    BackendPlatformName::String

    #  Mouse handling
    MouseWindowID::UInt32
    MouseButtonsDown::Int32
    MouseCursors::NTuple{9, Ptr{SDL2.SDL_Cursor}}  # Fixed-size array like C++ version
    MouseLastCursor::Ptr{SDL2.SDL_Cursor}
    MouseLastLeaveFrame::Int32
    MouseCanUseGlobalState::Bool
    MouseCanUseCapture::Bool

    #  Gamepad handling
    Gamepads::Vector{SDL2.SDL_GameController}
    GamepadMode::Int32
    WantUpdateGamepadsList::Bool
end

function Base.getproperty(x::Ptr{ImGui_ImplSDL2_Data}, f::Symbol)
    f === :Window && return unsafe_load(Ptr{Ptr{SDL2.SDL_Window}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:Window))))
    f === :WindowID && return unsafe_load(Ptr{UInt32}(x + offsetof(ImGui_ImplSDL2_Data, Val(:WindowID))))
    f === :Renderer && return unsafe_load(Ptr{Ptr{SDL2.SDL_Renderer}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:Renderer))))
    f === :Time && return unsafe_load(Ptr{UInt64}(x + offsetof(ImGui_ImplSDL2_Data, Val(:Time))))
    f === :ClipboardTextData && return unsafe_load(Ptr{Ptr{Cchar}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:ClipboardTextData))))
    f === :BackendPlatformName && return unsafe_load(Ptr{Ptr{Cchar}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:BackendPlatformName))))
    f === :MouseWindowID && return unsafe_load(Ptr{UInt32}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseWindowID))))
    f === :MouseButtonsDown && return unsafe_load(Ptr{Int32}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseButtonsDown))))
    f === :MouseCursors && return unsafe_load(Ptr{NTuple{9, Ptr{SDL2.SDL_Cursor}}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseCursors))))
    f === :MouseLastCursor && return unsafe_load(Ptr{Ptr{SDL2.SDL_Cursor}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseLastCursor))))
    f === :MouseLastLeaveFrame && return unsafe_load(Ptr{Int32}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseLastLeaveFrame))))
    f === :MouseCanUseGlobalState && return unsafe_load(Ptr{Bool}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseCanUseGlobalState))))
    f === :MouseCanUseCapture && return unsafe_load(Ptr{Bool}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseCanUseCapture))))
    f === :Gamepads && return unsafe_load(Ptr{Vector{SDL2.SDL_GameController}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:Gamepads))))
    f === :GamepadMode && return unsafe_load(Ptr{Int32}(x + offsetof(ImGui_ImplSDL2_Data, Val(:GamepadMode))))
    f === :WantUpdateGamepadsList && return unsafe_load(Ptr{Bool}(x + offsetof(ImGui_ImplSDL2_Data, Val(:WantUpdateGamepadsList))))
end

function Base.setproperty!(x::Ptr{ImGui_ImplSDL2_Data}, f::Symbol, v::Any)
    f === :Window && return unsafe_store!(Ptr{Ptr{SDL2.SDL_Window}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:Window))), v)
    f === :WindowID && return unsafe_store!(Ptr{UInt32}(x + offsetof(ImGui_ImplSDL2_Data, Val(:WindowID))), v)
    f === :Renderer && return unsafe_store!(Ptr{Ptr{SDL2.SDL_Renderer}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:Renderer))), v)
    f === :Time && return unsafe_store!(Ptr{UInt64}(x + offsetof(ImGui_ImplSDL2_Data, Val(:Time))), v)
    f === :ClipboardTextData && return unsafe_store!(Ptr{Ptr{Cchar}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:ClipboardTextData))), v)
    f === :BackendPlatformName && return unsafe_store!(Ptr{Ptr{Cchar}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:BackendPlatformName))), v)
    f === :MouseWindowID && return unsafe_store!(Ptr{UInt32}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseWindowID))), v)
    f === :MouseButtonsDown && return unsafe_store!(Ptr{Int32}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseButtonsDown))), v)
    f === :MouseCursors && return unsafe_store!(Ptr{NTuple{9, Ptr{SDL2.SDL_Cursor}}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseCursors))), v)
    f === :MouseLastCursor && return unsafe_store!(Ptr{Ptr{SDL2.SDL_Cursor}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseLastCursor))), v)
    f === :MouseLastLeaveFrame && return unsafe_store!(Ptr{Int32}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseLastLeaveFrame))), v)
    f === :MouseCanUseGlobalState && return unsafe_store!(Ptr{Bool}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseCanUseGlobalState))), v)
    f === :MouseCanUseCapture && return unsafe_store!(Ptr{Bool}(x + offsetof(ImGui_ImplSDL2_Data, Val(:MouseCanUseCapture))), v)
    f === :Gamepads && return unsafe_store!(Ptr{Vector{SDL2.SDL_GameController}}(x + offsetof(ImGui_ImplSDL2_Data, Val(:Gamepads))), v)
    f === :GamepadMode && return unsafe_store!(Ptr{Int32}(x + offsetof(ImGui_ImplSDL2_Data, Val(:GamepadMode))), v)
    f === :WantUpdateGamepadsList && return unsafe_store!(Ptr{Bool}(x + offsetof(ImGui_ImplSDL2_Data, Val(:WantUpdateGamepadsList))), v)
end


function SDL_VERSION_ATLEAST(major::Int32, minor::Int32, patch::Int32)::Bool
    sdl_version_ptr::Ptr{SDL2.SDL_version} = Libc.malloc(sizeof(SDL2.SDL_version))
    SDL2.SDL_GetVersion(sdl_version_ptr)
    sdl_version = unsafe_load(sdl_version_ptr)
    Libc.free(sdl_version_ptr)
    if sdl_version.major > major
        return true
    elseif sdl_version.major == major
        if sdl_version.minor > minor
            return true
        elseif sdl_version.minor == minor
            return sdl_version.patch >= patch
        end
    end

    return false
end