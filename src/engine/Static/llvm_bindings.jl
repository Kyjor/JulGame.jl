# llvmcall SDL (sc-game style).
# libsdl2 must be RTLD_GLOBAL so undeclared SDL_* symbols resolve at load.

const SDL_BLENDMODE_BLEND = UInt32(1)

struct SDL_FRect
    x::Float32
    y::Float32
    w::Float32
    h::Float32
end

function wasm_malloc(size::UInt32)::Ptr{Cvoid}
    Base.llvmcall(("""
        declare noalias i8* @malloc(i32) nounwind

        define i8* @my_malloc(i32 %size) {
        entry:
            %ptr = call noalias i8* @malloc(i32 %size)
            ret i8* %ptr
        }
    """, "my_malloc"), Ptr{Cvoid}, Tuple{UInt32}, size)
end

function wasm_free(ptr::Ptr{Cvoid})
    Base.llvmcall(("""
        declare void @free(i8*) nounwind

        define void @my_free(i8* %ptr) {
        entry:
            call void @free(i8* %ptr)
            ret void
        }
    """, "my_free"), Nothing, Tuple{Ptr{Cvoid}}, ptr)
    return
end

# Original C signature: int SDL_SetRenderDrawBlendMode(SDL_Renderer * renderer, SDL_BlendMode blendMode)
function llvm_SDL_SetRenderDrawBlendMode(renderer::Ptr{Cvoid}, blendMode::UInt32)::Int32
    Base.llvmcall(("""
    declare i32 @SDL_SetRenderDrawBlendMode(i8*, i32) nounwind

    define i32 @main(i8* %renderer, i32 %blendMode) {
    entry:
        %result = call i32 @SDL_SetRenderDrawBlendMode(i8* %renderer, i32 %blendMode)
        ret i32 %result
    }
    """, "main"), Int32, Tuple{Ptr{Cvoid}, UInt32}, renderer, blendMode)
end

# Original C signature: int SDL_GetRenderDrawColor(SDL_Renderer * renderer, Uint8 * r, Uint8 * g, Uint8 * b, Uint8 * a)
function llvm_SDL_GetRenderDrawColor(
    renderer::Ptr{Cvoid}, r::Ptr{UInt8}, g::Ptr{UInt8}, b::Ptr{UInt8}, a::Ptr{UInt8},
)::Int32
    Base.llvmcall(("""
    declare i32 @SDL_GetRenderDrawColor(i8*, i8*, i8*, i8*, i8*) nounwind

    define i32 @main(i8* %renderer, i8* %r, i8* %g, i8* %b, i8* %a) {
    entry:
        %result = call i32 @SDL_GetRenderDrawColor(i8* %renderer, i8* %r, i8* %g, i8* %b, i8* %a)
        ret i32 %result
    }
    """, "main"), Int32, Tuple{Ptr{Cvoid}, Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8}}, renderer, r, g, b, a)
end

# Original C signature: int SDL_SetRenderDrawColor(SDL_Renderer * renderer, Uint8 r, Uint8 g, Uint8 b, Uint8 a)
function llvm_SDL_SetRenderDrawColor(
    renderer::Ptr{Cvoid}, r::UInt8, g::UInt8, b::UInt8, a::UInt8,
)::Int32
    Base.llvmcall(("""
    declare i32 @SDL_SetRenderDrawColor(i8*, i8, i8, i8, i8) nounwind

    define i32 @main(i8* %renderer, i8 %r, i8 %g, i8 %b, i8 %a) {
    entry:
        %result = call i32 @SDL_SetRenderDrawColor(i8* %renderer, i8 %r, i8 %g, i8 %b, i8 %a)
        ret i32 %result
    }
    """, "main"), Int32, Tuple{Ptr{Cvoid}, UInt8, UInt8, UInt8, UInt8}, renderer, r, g, b, a)
end

# Original C signature: int SDL_RenderFillRectF(SDL_Renderer * renderer, const SDL_FRect * rect)
function llvm_SDL_RenderFillRectF(renderer::Ptr{Cvoid}, rect::Ptr{Cvoid})::Int32
    Base.llvmcall(("""
    declare i32 @SDL_RenderFillRectF(i8*, i8*) nounwind

    define i32 @main(i8* %renderer, i8* %rect) {
    entry:
        %result = call i32 @SDL_RenderFillRectF(i8* %renderer, i8* %rect)
        ret i32 %result
    }
    """, "main"), Int32, Tuple{Ptr{Cvoid}, Ptr{Cvoid}}, renderer, rect)
end

# Original C signature: int SDL_RenderDrawRectF(SDL_Renderer * renderer, const SDL_FRect * rect)
function llvm_SDL_RenderDrawRectF(renderer::Ptr{Cvoid}, rect::Ptr{Cvoid})::Int32
    Base.llvmcall(("""
    declare i32 @SDL_RenderDrawRectF(i8*, i8*) nounwind

    define i32 @main(i8* %renderer, i8* %rect) {
    entry:
        %result = call i32 @SDL_RenderDrawRectF(i8* %renderer, i8* %rect)
        ret i32 %result
    }
    """, "main"), Int32, Tuple{Ptr{Cvoid}, Ptr{Cvoid}}, renderer, rect)
end

# Original C signature: const char *SDL_GetError(void)
function llvm_SDL_GetError()::Ptr{UInt8}
    Base.llvmcall(("""
    declare i8* @SDL_GetError() nounwind

    define i8* @main() {
    entry:
        %result = call i8* @SDL_GetError()
        ret i8* %result
    }
    """, "main"), Ptr{UInt8}, Tuple{})
end

# Original C signature: void SDL_ClearError(void)
function llvm_SDL_ClearError()
    Base.llvmcall(("""
    declare void @SDL_ClearError() nounwind

    define void @main() {
    entry:
        call void @SDL_ClearError()
        ret void
    }
    """, "main"), Nothing, Tuple{})
    return
end

# SDL_mixer (libsdl2_mixer must also be RTLD_GLOBAL; see JGStatic.ensure_sdl_global!)

# Original C signature: int Mix_PlayingMusic(void)
function llvm_Mix_PlayingMusic()::Int32
    Base.llvmcall(("""
    declare i32 @Mix_PlayingMusic() nounwind

    define i32 @main() {
    entry:
        %result = call i32 @Mix_PlayingMusic()
        ret i32 %result
    }
    """, "main"), Int32, Tuple{})
end

# Original C signature: int Mix_PausedMusic(void)
function llvm_Mix_PausedMusic()::Int32
    Base.llvmcall(("""
    declare i32 @Mix_PausedMusic() nounwind

    define i32 @main() {
    entry:
        %result = call i32 @Mix_PausedMusic()
        ret i32 %result
    }
    """, "main"), Int32, Tuple{})
end

# Original C signature: int Mix_PlayMusic(Mix_Music * music, int loops)
function llvm_Mix_PlayMusic(music::Ptr{Cvoid}, loops::Int32)::Int32
    Base.llvmcall(("""
    declare i32 @Mix_PlayMusic(i8*, i32) nounwind

    define i32 @main(i8* %music, i32 %loops) {
    entry:
        %result = call i32 @Mix_PlayMusic(i8* %music, i32 %loops)
        ret i32 %result
    }
    """, "main"), Int32, Tuple{Ptr{Cvoid}, Int32}, music, loops)
end

# Original C signature: void Mix_PauseMusic(void)
function llvm_Mix_PauseMusic()
    Base.llvmcall(("""
    declare void @Mix_PauseMusic() nounwind

    define void @main() {
    entry:
        call void @Mix_PauseMusic()
        ret void
    }
    """, "main"), Nothing, Tuple{})
    return
end

# Original C signature: void Mix_ResumeMusic(void)
function llvm_Mix_ResumeMusic()
    Base.llvmcall(("""
    declare void @Mix_ResumeMusic() nounwind

    define void @main() {
    entry:
        call void @Mix_ResumeMusic()
        ret void
    }
    """, "main"), Nothing, Tuple{})
    return
end

# Original C signature: int Mix_HaltMusic(void)
function llvm_Mix_HaltMusic()::Int32
    Base.llvmcall(("""
    declare i32 @Mix_HaltMusic() nounwind

    define i32 @main() {
    entry:
        %result = call i32 @Mix_HaltMusic()
        ret i32 %result
    }
    """, "main"), Int32, Tuple{})
end

# Original C signature: int Mix_PlayChannel(int channel, Mix_Chunk * chunk, int loops)
function llvm_Mix_PlayChannel(channel::Int32, chunk::Ptr{Cvoid}, loops::Int32)::Int32
    Base.llvmcall(("""
    declare i32 @Mix_PlayChannel(i32, i8*, i32) nounwind

    define i32 @main(i32 %channel, i8* %chunk, i32 %loops) {
    entry:
        %result = call i32 @Mix_PlayChannel(i32 %channel, i8* %chunk, i32 %loops)
        ret i32 %result
    }
    """, "main"), Int32, Tuple{Int32, Ptr{Cvoid}, Int32}, channel, chunk, loops)
end

# Original C signature: void Mix_FreeMusic(Mix_Music * music)
function llvm_Mix_FreeMusic(music::Ptr{Cvoid})
    Base.llvmcall(("""
    declare void @Mix_FreeMusic(i8*) nounwind

    define void @main(i8* %music) {
    entry:
        call void @Mix_FreeMusic(i8* %music)
        ret void
    }
    """, "main"), Nothing, Tuple{Ptr{Cvoid}}, music)
    return
end

# Original C signature: void Mix_FreeChunk(Mix_Chunk * chunk)
function llvm_Mix_FreeChunk(chunk::Ptr{Cvoid})
    Base.llvmcall(("""
    declare void @Mix_FreeChunk(i8*) nounwind

    define void @main(i8* %chunk) {
    entry:
        call void @Mix_FreeChunk(i8* %chunk)
        ret void
    }
    """, "main"), Nothing, Tuple{Ptr{Cvoid}}, chunk)
    return
end

# Original C signature: int Mix_VolumeMusic(int volume)
function llvm_Mix_VolumeMusic(volume::Int32)::Int32
    Base.llvmcall(("""
    declare i32 @Mix_VolumeMusic(i32) nounwind

    define i32 @main(i32 %volume) {
    entry:
        %result = call i32 @Mix_VolumeMusic(i32 %volume)
        ret i32 %result
    }
    """, "main"), Int32, Tuple{Int32}, volume)
end

# Original C signature: int Mix_Volume(int channel, int volume)
function llvm_Mix_Volume(channel::Int32, volume::Int32)::Int32
    Base.llvmcall(("""
    declare i32 @Mix_Volume(i32, i32) nounwind

    define i32 @main(i32 %channel, i32 %volume) {
    entry:
        %result = call i32 @Mix_Volume(i32 %channel, i32 %volume)
        ret i32 %result
    }
    """, "main"), Int32, Tuple{Int32, Int32}, channel, volume)
end

# Original C signature: int Mix_MasterVolume(int volume)
function llvm_Mix_MasterVolume(volume::Int32)::Int32
    Base.llvmcall(("""
    declare i32 @Mix_MasterVolume(i32) nounwind

    define i32 @main(i32 %volume) {
    entry:
        %result = call i32 @Mix_MasterVolume(i32 %volume)
        ret i32 %result
    }
    """, "main"), Int32, Tuple{Int32}, volume)
end

# Original C signature: Mix_Music * Mix_LoadMUS(const char * file)
function llvm_Mix_LoadMUS(file_path::Ptr{UInt8})::Ptr{Cvoid}
    Base.llvmcall(("""
    declare i8* @Mix_LoadMUS(i8*) nounwind

    define i8* @main(i8* %file_path) {
    entry:
        %result = call i8* @Mix_LoadMUS(i8* %file_path)
        ret i8* %result
    }
    """, "main"), Ptr{Cvoid}, Tuple{Ptr{UInt8}}, file_path)
end

# Original C signature: Mix_Chunk * Mix_LoadWAV(const char * file)
function llvm_Mix_LoadWAV(file_path::Ptr{UInt8})::Ptr{Cvoid}
    Base.llvmcall(("""
    declare i8* @Mix_LoadWAV(i8*) nounwind

    define i8* @main(i8* %file_path) {
    entry:
        %result = call i8* @Mix_LoadWAV(i8* %file_path)
        ret i8* %result
    }
    """, "main"), Ptr{Cvoid}, Tuple{Ptr{UInt8}}, file_path)
end
