include(joinpath(SMOKETESTDIR, "src", "SmokeTest.jl"))
@testset "Open and close" begin
    @test SmokeTest.run(SMOKETESTDIR) == 0
end