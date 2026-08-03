using Test

const STATIC_DIR = joinpath(@__DIR__, "..", "..", "src", "engine", "Static")
include(joinpath(STATIC_DIR, "JGStatic.jl"))
include(joinpath(STATIC_DIR, "UIHitTest.jl"))
using .JGStaticModule
using .UIHitTestModule

@testset "UI hit test reference (Julia)" begin
    @test is_mouse_inside_element_julia(5, 5, 0, 0, 10, 10)
    @test !is_mouse_inside_element_julia(11, 5, 0, 0, 10, 10)
    @test !is_mouse_inside_element_julia(5, 11, 0, 0, 10, 10)
    @test is_mouse_inside_element_julia(0, 0, 0, 0, 0, 0)
    @test is_mouse_inside_element_julia(10, 10, 0, 0, 10, 10)
    @test is_mouse_inside_element_julia(15, 245, 0.0, 1.0, 1920.0, 1081.0)
    @test !is_mouse_inside_element_julia(2000, 245, 0.0, 1.0, 1920.0, 1081.0)
end

@testset "HitTestBuffer gather + Julia first hit" begin
    buf = HitTestBuffer(4)
    clear!(buf)
    push_rect!(buf, :a, 0, 0, 10, 10)
    push_rect!(buf, :b, 20, 20, 30, 30)
    @test first_hit_index_julia(buf, 5, 5) == 1
    @test first_hit_index_julia(buf, 25, 25) == 2
    @test first_hit_index_julia(buf, 15, 15) == -1
end

if JGStaticModule.LIB_AVAILABLE
    @testset "native scalar vs Julia" begin
        cases = [
            (5, 5, 0, 0, 10, 10, true),
            (11, 5, 0, 0, 10, 10, false),
            (0, 0, 0, 0, 0, 0, true),
        ]
        for (mx, my, ex, ey, er, eb, expected) in cases
            j = is_mouse_inside_element_julia(mx, my, ex, ey, er, eb)
            s = is_mouse_inside_element_scalar_static(mx, my, ex, ey, er, eb)
            @test j == expected
            @test s == expected
        end
    end

    @testset "native batch vs Julia" begin
        for n in (1, 10, 50)
            buf = HitTestBuffer(n)
            clear!(buf)
            for i in 1:n
                off = (i - 1) * 15
                push_rect!(buf, i, off, off, off + 10, off + 10)
            end
            mx, my = 7, 7
            j_idx = first_hit_index_julia(buf, mx, my)
            s_idx = run_static_hit_test_batch!(buf, mx, my)
            @test j_idx == s_idx
        end
    end
else
    @testset "native JGStatic lib (skipped)" begin
        @test_broken JGStaticModule.LIB_AVAILABLE
    end
end
