using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer
using Test

SDL2_pkg_dir = joinpath(@__DIR__, "..","..")

@testset "Image" begin
# Test that you can init
@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))

@test SDL2.IMG_Load(joinpath(SDL2_pkg_dir,"assets","cat.bmp")) != Ptr{Nothing}(C_NULL)
@test SDL2.IMG_Load(joinpath(SDL2_pkg_dir,"assets","cat.png")) != Ptr{Nothing}(C_NULL)
@test SDL2.IMG_Load(joinpath(SDL2_pkg_dir,"assets","cat.jpg")) != Ptr{Nothing}(C_NULL)


SDL2.Quit()
end
