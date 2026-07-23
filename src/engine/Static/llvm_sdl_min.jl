# Minimal SDL llvmcall wrappers for Phase 0 shell (grow as needed).
# Prefer these over ccall inside StaticCompiler-compiled code.

const SDL_INIT_VIDEO = UInt32(0x00000020)
const SDL_WINDOWPOS_UNDEFINED = Int32(0x1FFF0000)
const SDL_WINDOW_SHOWN = UInt32(0x00000004)
const SDL_RENDERER_ACCELERATED = UInt32(0x00000002)
const SDL_RENDERER_PRESENTVSYNC = UInt32(0x00000004)

function llvm_SDL_Init(flags::UInt32)::Int32
    return Base.llvmcall(("""
    declare i32 @SDL_Init(i32) nounwind

    define i32 @entry(i32 %flags) {
    entry:
        %result = call i32 @SDL_Init(i32 %flags)
        ret i32 %result
    }
    """, "entry"), Int32, Tuple{UInt32}, flags)
end

function llvm_SDL_Quit()
    Base.llvmcall(("""
    declare void @SDL_Quit() nounwind

    define void @entry() {
    entry:
        call void @SDL_Quit()
        ret void
    }
    """, "entry"), Cvoid, Tuple{},)
end

# Title baked into IR so we avoid String/WallocString for Phase 0.3.
function llvm_SDL_CreateWindow_julgame(x::Int32, y::Int32, w::Int32, h::Int32, flags::UInt32)::Ptr{Cvoid}
    return Base.llvmcall(("""
    @jg_title = private unnamed_addr constant [8 x i8] c"JulGame\\00"

    declare i8* @SDL_CreateWindow(i8*, i32, i32, i32, i32, i32) nounwind

    define i8* @entry(i32 %x, i32 %y, i32 %w, i32 %h, i32 %flags) {
    entry:
        %t = getelementptr inbounds [8 x i8], [8 x i8]* @jg_title, i64 0, i64 0
        %r = call i8* @SDL_CreateWindow(i8* %t, i32 %x, i32 %y, i32 %w, i32 %h, i32 %flags)
        ret i8* %r
    }
    """, "entry"), Ptr{Cvoid}, Tuple{Int32, Int32, Int32, Int32, UInt32}, x, y, w, h, flags)
end

function llvm_SDL_CreateRenderer(window::Ptr{Cvoid}, index::Int32, flags::UInt32)::Ptr{Cvoid}
    return Base.llvmcall(("""
    declare i8* @SDL_CreateRenderer(i8*, i32, i32) nounwind

    define i8* @entry(i8* %window, i32 %index, i32 %flags) {
    entry:
        %r = call i8* @SDL_CreateRenderer(i8* %window, i32 %index, i32 %flags)
        ret i8* %r
    }
    """, "entry"), Ptr{Cvoid}, Tuple{Ptr{Cvoid}, Int32, UInt32}, window, index, flags)
end

function llvm_SDL_DestroyWindow(window::Ptr{Cvoid})
    Base.llvmcall(("""
    declare void @SDL_DestroyWindow(i8*) nounwind

    define void @entry(i8* %window) {
    entry:
        call void @SDL_DestroyWindow(i8* %window)
        ret void
    }
    """, "entry"), Cvoid, Tuple{Ptr{Cvoid}}, window)
end

function llvm_SDL_DestroyRenderer(renderer::Ptr{Cvoid})
    Base.llvmcall(("""
    declare void @SDL_DestroyRenderer(i8*) nounwind

    define void @entry(i8* %renderer) {
    entry:
        call void @SDL_DestroyRenderer(i8* %renderer)
        ret void
    }
    """, "entry"), Cvoid, Tuple{Ptr{Cvoid}}, renderer)
end

# C globals in jg_sdl_globals.c
function llvm_jg_set_window(window::Ptr{Cvoid})
    handle::UInt64 = reinterpret(UInt64, window)
    Base.llvmcall(("""
    declare void @jg_set_window(i64) nounwind

    define void @entry(i64 %window) {
    entry:
        call void @jg_set_window(i64 %window)
        ret void
    }
    """, "entry"), Cvoid, Tuple{UInt64}, handle)
end

function llvm_jg_set_renderer(renderer::Ptr{Cvoid})
    handle::UInt64 = reinterpret(UInt64, renderer)
    Base.llvmcall(("""
    declare void @jg_set_renderer(i64) nounwind

    define void @entry(i64 %renderer) {
    entry:
        call void @jg_set_renderer(i64 %renderer)
        ret void
    }
    """, "entry"), Cvoid, Tuple{UInt64}, handle)
end

function llvm_jg_get_window()::Ptr{Cvoid}
    handle::UInt64 = Base.llvmcall(("""
    declare i64 @jg_get_window() nounwind

    define i64 @entry() {
    entry:
        %r = call i64 @jg_get_window()
        ret i64 %r
    }
    """, "entry"), UInt64, Tuple{},)
    return reinterpret(Ptr{Cvoid}, handle)
end

function llvm_jg_get_renderer()::Ptr{Cvoid}
    handle::UInt64 = Base.llvmcall(("""
    declare i64 @jg_get_renderer() nounwind

    define i64 @entry() {
    entry:
        %r = call i64 @jg_get_renderer()
        ret i64 %r
    }
    """, "entry"), UInt64, Tuple{},)
    return reinterpret(Ptr{Cvoid}, handle)
end

function llvm_jg_note_frame_rendered()
    Base.llvmcall(("""
    declare void @jg_note_frame_rendered() nounwind

    define void @entry() {
    entry:
        call void @jg_note_frame_rendered()
        ret void
    }
    """, "entry"), Cvoid, Tuple{},)
end

function llvm_SDL_SetRenderDrawColor(renderer::Ptr{Cvoid}, r::UInt8, g::UInt8, b::UInt8, a::UInt8)::Int32
    return Base.llvmcall(("""
    declare i32 @SDL_SetRenderDrawColor(i8*, i8, i8, i8, i8) nounwind

    define i32 @entry(i8* %renderer, i8 %r, i8 %g, i8 %b, i8 %a) {
    entry:
        %result = call i32 @SDL_SetRenderDrawColor(i8* %renderer, i8 %r, i8 %g, i8 %b, i8 %a)
        ret i32 %result
    }
    """, "entry"), Int32, Tuple{Ptr{Cvoid}, UInt8, UInt8, UInt8, UInt8}, renderer, r, g, b, a)
end

function llvm_SDL_RenderClear(renderer::Ptr{Cvoid})::Int32
    return Base.llvmcall(("""
    declare i32 @SDL_RenderClear(i8*) nounwind

    define i32 @entry(i8* %renderer) {
    entry:
        %result = call i32 @SDL_RenderClear(i8* %renderer)
        ret i32 %result
    }
    """, "entry"), Int32, Tuple{Ptr{Cvoid}}, renderer)
end

function llvm_SDL_RenderPresent(renderer::Ptr{Cvoid})
    Base.llvmcall(("""
    declare void @SDL_RenderPresent(i8*) nounwind

    define void @entry(i8* %renderer) {
    entry:
        call void @SDL_RenderPresent(i8* %renderer)
        ret void
    }
    """, "entry"), Cvoid, Tuple{Ptr{Cvoid}}, renderer)
end

function llvm_SDL_GetTicks()::UInt32
    return Base.llvmcall(("""
    declare i32 @SDL_GetTicks() nounwind

    define i32 @entry() {
    entry:
        %result = call i32 @SDL_GetTicks()
        ret i32 %result
    }
    """, "entry"), UInt32, Tuple{},)
end

function llvm_SDL_PollEvent(event::Ptr{Cvoid})::Int32
    return Base.llvmcall(("""
    declare i32 @SDL_PollEvent(i8*) nounwind

    define i32 @entry(i8* %event) {
    entry:
        %result = call i32 @SDL_PollEvent(i8* %event)
        ret i32 %result
    }
    """, "entry"), Int32, Tuple{Ptr{Cvoid}}, event)
end

function llvm_jg_get_frames_rendered()::Int32
    return Base.llvmcall(("""
    declare i32 @jg_get_frames_rendered() nounwind

    define i32 @entry() {
    entry:
        %r = call i32 @jg_get_frames_rendered()
        ret i32 %r
    }
    """, "entry"), Int32, Tuple{},)
end

# libc malloc/free (desktop size_t = i64)
function jg_malloc(size::UInt64)::Ptr{Cvoid}
    return Base.llvmcall(("""
    declare noalias i8* @malloc(i64) nounwind

    define i8* @entry(i64 %size) {
    entry:
        %ptr = call noalias i8* @malloc(i64 %size)
        ret i8* %ptr
    }
    """, "entry"), Ptr{Cvoid}, Tuple{UInt64}, size)
end

function jg_free(ptr::Ptr{Cvoid})
    Base.llvmcall(("""
    declare void @free(i8*) nounwind

    define void @entry(i8* %ptr) {
    entry:
        call void @free(i8* %ptr)
        ret void
    }
    """, "entry"), Cvoid, Tuple{Ptr{Cvoid}}, ptr)
end
