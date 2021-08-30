using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer
using Test

SDL2_pkg_dir = joinpath(@__DIR__, "..","..")

@testset "Init+Quit" begin
# Test that you can init and quit SDL_ttf multiple times correctly.
@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))
@test 0 == SDL2.TTF_Init()
SDL2.TTF_Quit()
SDL2.Quit()

@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))
@test 0 == SDL2.TTF_Init()
SDL2.TTF_Quit()
SDL2.Quit()
end

@testset "Text" begin
@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))
@test 0 == SDL2.TTF_Init()

@testset "Simple text" begin
font = TTF_OpenFont(joinpath(SDL2_pkg_dir,"assets/fonts/FiraCode/ttf/FiraCode-Regular.ttf"), 14)
@test font != C_NULL
txt = "Hello World!"
text = TTF_RenderText_Blended(font, txt, SDL2.Color(20,20,20,255))
@test text != C_NULL

fx,fy = Int[1], Int[1]
@test 0 == TTF_SizeText(font, txt, pointer(fx), pointer(fy))
fx,fy = fx[1],fy[1]
@test fx > 0
@test fy > 0
end

SDL2.TTF_Quit()
SDL2.Quit()
end

@testset "Rendering" begin
@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))
@test 0 == SDL2.TTF_Init()
win = SDL2.CreateWindow("Hello World!", Int32(100), Int32(100), Int32(300), Int32(400),
         UInt32(SDL2.WINDOW_SHOWN))
renderer = SDL2.CreateRenderer(win, Int32(-1),
             UInt32(SDL2.RENDERER_ACCELERATED | SDL2.RENDERER_PRESENTVSYNC))


# try rendering with complicated text
@testset "Special Characters text" begin
font = TTF_OpenFont(joinpath(SDL2_pkg_dir,"assets/fonts/FiraCode/ttf/FiraCode-Regular.ttf"), 14)
txt = "@BinDeps.install Dict([ (:glib, :libglib) ])"
text = TTF_RenderText_Blended(font, txt, SDL2.Color(20,20,20,255))
@test text != C_NULL
tex = SDL2.CreateTextureFromSurface(renderer,text)
if get(ENV, "HAS_JOSH_K_SEAL_OF_APPROVAL", "") == "true" && Sys.islinux()
    @test_broken tex != C_NULL
else
    @test tex != C_NULL
end

fx,fy = Int[1], Int[1]
@test 0 == TTF_SizeText(font, txt, pointer(fx), pointer(fy))
fx,fy = fx[1],fy[1]
@test fx > 0
@test fy > 0

if get(ENV, "HAS_JOSH_K_SEAL_OF_APPROVAL", "") == "true" && Sys.islinux()
    @test_broken 0 == SDL2.RenderCopy(renderer, tex, C_NULL, pointer_from_objref(SDL2.Rect(0,0,fx,fy)))
else
    @test 0 == SDL2.RenderCopy(renderer, tex, C_NULL, pointer_from_objref(SDL2.Rect(0,0,fx,fy)))
end
SDL2.RenderPresent(renderer)

end

SDL2.TTF_Quit()
SDL2.Quit()
end
