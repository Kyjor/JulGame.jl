using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer

import SimpleDirectMediaLayer.LoadBMP

SDL2.GL_SetAttribute(SDL2.GL_MULTISAMPLEBUFFERS, 16)
SDL2.GL_SetAttribute(SDL2.GL_MULTISAMPLESAMPLES, 16)

SDL2.init()

win = SDL2.CreateWindow("Hello World!", Int32(100), Int32(100), Int32(800), Int32(600),
    UInt32(SDL2.WINDOW_SHOWN))
SDL2.SetWindowResizable(win,true)

renderer = SDL2.CreateRenderer(win, Int32(-1),
    UInt32(SDL2.RENDERER_ACCELERATED | SDL2.RENDERER_PRESENTVSYNC))

import Base.unsafe_convert
unsafe_convert(::Type{Ptr{SDL2.RWops}}, s::String) = SDL2.RWFromFile(s, "rb")

LoadBMP(src::String) = SDL2.LoadBMP_RW(src,Int32(1))

bkg = SDL2.Color(200, 200, 200, 255)

# Create text
font = TTF_OpenFont(joinpath(@__DIR__,"../../assets/fonts/FiraCode/ttf/FiraCode-Regular.ttf"), 14)
#txt = "@BinDeps.install Dict([ (:glib, :libglib) ])"
txt = "Hello, World!"
text = TTF_RenderText_Blended(font, txt, SDL2.Color(20,20,20,255))
tex = SDL2.CreateTextureFromSurface(renderer,text)

fx,fy = Int[1], Int[1]
TTF_SizeText(font, txt, pointer(fx), pointer(fy))
fx,fy = fx[1],fy[1]

#img = SDL2.LoadBMP("LB2951.jpg")
#tex = SDL2.CreateTextureFromSurface(ren, img)
#SDL2.FreeSurface(img)

function pollEvent!()
    #SDL2.Event() = [SDL2.Event(NTuple{56, Uint8}(zeros(56,1)))]
    SDL_Event() = Array{UInt8}(zeros(56))
    e = SDL_Event()
    success = (SDL2.PollEvent(e) != 0)
    return e,success
end
function getEventType(e::Array{UInt8})
    # HAHA This is still pretty janky, but I guess that's all you can do w/ unions.
    bitcat(UInt32, e[4:-1:1])
end
function getEventType(e::SDL2.Event)
    e._Event[1]
end

function bitcat(outType::Type{T}, arr)::T where T<:Number
    out = zero(outType)
    for x in arr
        out = out << (sizeof(x)*8)
        out |= convert(T, x)  # the `convert` prevents signed T from promoting to Int64.
    end
    out
end


gameIsRunning = true

while gameIsRunning
    x,y = Int[1], Int[1]
    SDL2.PumpEvents()
    SDL2.GetMouseState(pointer(x), pointer(y))

    # Set render color to red ( background will be rendered in this color )
    SDL2.SetRenderDrawColor(renderer, 200, 200, 200, 255)
    SDL2.RenderClear(renderer)

    SDL2.SetRenderDrawColor(renderer, 20, 50, 105, 255)
    SDL2.RenderDrawLine(renderer,0,0,800,600)

    rect = SDL2.Rect(1,1,200,200)
    SDL2.RenderFillRect(renderer, pointer_from_objref(rect) )
    SDL2.RenderCopy(renderer, tex, C_NULL, pointer_from_objref(SDL2.Rect(x[1],y[1],fx,fy)))

    SDL2.RenderPresent(renderer)
    println("check")
    e,_ = pollEvent!()
           t = getEventType(e)
           if t == SDL2.QUIT
               println("quit")
               #throw(QuitException())
               gameIsRunning = false
           end
    sleep(0.01)

end
SDL2.Quit()
