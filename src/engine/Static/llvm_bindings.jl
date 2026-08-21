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
