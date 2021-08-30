using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer
using Test

SDL2_pkg_dir = joinpath(@__DIR__, "..","..")
audio_example_assets_dir = joinpath(SDL2_pkg_dir, "src/examples/audio_example")

# check that an audio device if available
SDL2.Init(UInt32(SDL2.INIT_VIDEO))
device = SDL2.Mix_OpenAudio(Int32(22050), UInt16(SDL2.MIX_DEFAULT_FORMAT), Int32(2), Int32(1024) )

if device == 0
SDL2.Mix_CloseAudio()
SDL2.Quit()

@testset "Init+Quit" begin
# Test that you can init and quit SDL_mixer multiple times correctly.
@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))
@test 0 == SDL2.Mix_OpenAudio(Int32(22050), UInt16(SDL2.MIX_DEFAULT_FORMAT), Int32(2), Int32(1024) )
SDL2.Mix_CloseAudio()
SDL2.Quit()

@test 0 == SDL2.Init(UInt32(SDL2.INIT_VIDEO))
@test 0 == SDL2.Mix_OpenAudio(Int32(22050), UInt16(SDL2.MIX_DEFAULT_FORMAT), Int32(2), Int32(1024) )
SDL2.Mix_CloseAudio()
SDL2.Quit()
end

@testset "Sounds" begin
SDL2.Init(UInt32(0))
SDL2.Mix_OpenAudio(Int32(22050), UInt16(SDL2.MIX_DEFAULT_FORMAT), Int32(2), Int32(1024) )

med = SDL2.Mix_LoadWAV( joinpath(audio_example_assets_dir,"medium.wav")  )
@test med != C_NULL
@test -1 != SDL2.Mix_PlayChannel( Int32(-1), med, Int32(0) )
# Test that can play multiple times successfully
# (Note that if a sound overlaps with a previous sound, it will play on a
# different channel. The return value is which channel it plays on.)
@test -1 != SDL2.Mix_PlayChannel( Int32(-1), med, Int32(0) )
@test -1 != SDL2.Mix_PlayChannel( Int32(-1), med, Int32(0) )

# Test different overlapping sounds
scratch = SDL2.Mix_LoadWAV( joinpath(audio_example_assets_dir,"scratch.wav")  )
@test scratch != C_NULL
@test -1 != SDL2.Mix_PlayChannel( Int32(-1), scratch, Int32(0) )
@test -1 != SDL2.Mix_PlayChannel( Int32(-1), med, Int32(0) )
@test -1 != SDL2.Mix_PlayChannel( Int32(-1), scratch, Int32(0) )

SDL2.Mix_CloseAudio()
SDL2.Quit()
end

@testset "Music" begin
SDL2.Init(UInt32(0))
SDL2.Mix_OpenAudio(Int32(22050), UInt16(SDL2.MIX_DEFAULT_FORMAT), Int32(2), Int32(1024) )

# Load the music
music = SDL2.Mix_LoadMUS( joinpath(audio_example_assets_dir,"beat.wav") );
@test music != C_NULL

# Test playing/pausing the music
@test 0 == SDL2.Mix_PlayMusic( music, Int32(-1) )
SDL2.Mix_PauseMusic()
SDL2.Mix_ResumeMusic()
@test 0 == SDL2.Mix_HaltMusic()


# Test noops if no music is playing.
@test 0 == SDL2.Mix_HaltMusic()
SDL2.Mix_PauseMusic()
SDL2.Mix_ResumeMusic()

# Test playing multiple times
@test 0 == SDL2.Mix_PlayMusic( music, Int32(-1) )
@test 0 == SDL2.Mix_PlayMusic( music, Int32(-1) )

SDL2.Mix_CloseAudio()
SDL2.Quit()
end

end
SDL2.Quit()
