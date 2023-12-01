@testset "Vector2 tests" begin
    # set up
    vec1 = Math.Vector2(2, 2)
    vec2 = Math.Vector2(2) # 2, 2

    @testset "Vector2 subtraction" begin
        res = vec1 - vec2
        @test res == Math.Vector2(0, 0)
    end

    @testset "Vector2 addition" begin
        res = vec1 + vec2
        @test res == Math.Vector2(4, 4)
    end

    @testset "Vector2 multiplication" begin
        res = vec1 * vec2
        @test res == Math.Vector2(4, 4)
    end

    @testset "Vector2 division" begin
        res = vec1 / vec2
        @test res == Math.Vector2(1, 1)
    end
end