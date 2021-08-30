using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer
using Test

SDL2_pkg_dir = joinpath(@__DIR__, "..","..")

@testset "Init+Quit" begin
# Test that you can init and quit SDL multiple times correctly.
@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))
SDL2.Quit()

@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))
SDL2.Quit()
end


@testset "Window open+close" begin
@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))
# Create window
win = SDL2.CreateWindow("Hello World!", Int32(100), Int32(100), Int32(300), Int32(400),
         UInt32(SDL2.WINDOW_SHOWN))
@test win != C_NULL

renderer = SDL2.CreateRenderer(win, Int32(-1),
             UInt32(SDL2.RENDERER_ACCELERATED | SDL2.RENDERER_PRESENTVSYNC))
if get(ENV, "HAS_JOSH_K_SEAL_OF_APPROVAL", "") == "true" && Sys.islinux()
    @test_broken renderer != C_NULL
else
    @test renderer != C_NULL
end

# Close window
SDL2.DestroyWindow(win)

# Create window again
win = SDL2.CreateWindow("Hello World!", Int32(100), Int32(100), Int32(300), Int32(400),
         UInt32(SDL2.WINDOW_SHOWN))
@test win != C_NULL
renderer = SDL2.CreateRenderer(win, Int32(-1),
             UInt32(SDL2.RENDERER_ACCELERATED | SDL2.RENDERER_PRESENTVSYNC))
if get(ENV, "HAS_JOSH_K_SEAL_OF_APPROVAL", "") == "true" && Sys.islinux()
    @test_broken renderer != C_NULL
else
    @test renderer != C_NULL
end

SDL2.Quit()
end

@testset "Window" begin
@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))

win = SDL2.CreateWindow("Hello World!", Int32(100), Int32(100), Int32(300), Int32(400),
         UInt32(SDL2.WINDOW_SHOWN))

# Test get size
w,h = Int32[-1],Int32[-1]
SDL2.GetWindowSize(win, w,h)
@test 300 == w[]
@test 400 == h[]

e = SDL2.event()
@test typeof(e) <: SDL2.WindowEvent

# Test drawing
renderer = SDL2.CreateRenderer(win, Int32(-1),
             UInt32(SDL2.RENDERER_ACCELERATED | SDL2.RENDERER_PRESENTVSYNC))

rect = SDL2.Rect(1,1,50,50)
if get(ENV, "HAS_JOSH_K_SEAL_OF_APPROVAL", "") == "true" && Sys.islinux()
    @test_broken 0 == SDL2.RenderFillRect(renderer, pointer_from_objref(rect) )
else
    @test 0 == SDL2.RenderFillRect(renderer, pointer_from_objref(rect) )
end


@testset "Load/Save BMP" begin

img = SDL2.LoadBMP(joinpath(SDL2_pkg_dir, "assets/cat.bmp"))
@test img != C_NULL

img_tex = SDL2.CreateTextureFromSurface(renderer, img);
if get(ENV, "HAS_JOSH_K_SEAL_OF_APPROVAL", "") == "true" && Sys.islinux()
    @test_broken img_tex != C_NULL
else
    @test img_tex != C_NULL
end


src = SDL2.Rect(0,0,0,0)
if get(ENV, "HAS_JOSH_K_SEAL_OF_APPROVAL", "") == "true" && Sys.islinux()
    @test_broken 0 == SDL2.RenderCopy(renderer, img_tex, C_NULL, C_NULL) # Fill the renderer with img
else
    @test 0 == SDL2.RenderCopy(renderer, img_tex, C_NULL, C_NULL) # Fill the renderer with img
end
SDL2.RenderPresent(renderer)

# Save bmp
tmpFile = tempname()*".bmp"
@test 0 == SDL2.SaveBMP(img, tmpFile)

img2 = SDL2.LoadBMP(tmpFile)
@test img2 != C_NULL

# Compare the two images
if SDL2.MUSTLOCK(img)
    # Some surfaces must be locked before accessing pixels.
    @test 0 == SDL2.LockSurface(img)
    @test 0 == SDL2.LockSurface(img2)
end

img_surface1 = unsafe_load(img)
img_surface2 = unsafe_load(img2)

@test (img_surface1.w, img_surface1.h) == (img_surface2.w, img_surface2.h)

@test img_surface1.format != C_NULL
@test img_surface2.format != C_NULL

# Test pixels are equal
pxl_format1 = unsafe_load(img_surface1.format)
numPixelBytes = img_surface1.w * img_surface1.h * pxl_format1.BytesPerPixel
pixels1 = [unsafe_load(Ptr{UInt8}(img_surface1.pixels), i) for i in 1:numPixelBytes]
pixels2 = [unsafe_load(Ptr{UInt8}(img_surface2.pixels), i) for i in 1:numPixelBytes]

@test pixels1 == pixels2

if SDL2.MUSTLOCK(img)
    # Some surfaces must be locked/unlocked while accessing pixels.
    SDL2.UnlockSurface(img)
    SDL2.UnlockSurface(img2)
end

end  # @testset "BMP"

# Close window
SDL2.DestroyWindow(win)

SDL2.Quit()
end
