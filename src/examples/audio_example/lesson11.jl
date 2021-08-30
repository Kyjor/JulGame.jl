# This file transformed from Lazy Foo' Productions "Playing Sounds" tutorial:
# http://lazyfoo.net/SDL_tutorials/lesson11/index.php

using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer

SDL2.init()

#Load the music
aud_files = dirname(@__FILE__)
music = SDL2.Mix_LoadMUS( "$aud_files/beat.wav" );

if (music == C_NULL)
    error("$aud_files/beat.wav not found.")
end

scratch = SDL2.Mix_LoadWAV( "$aud_files/scratch.wav" );
high = SDL2.Mix_LoadWAV( "$aud_files/high.wav" );
med = SDL2.Mix_LoadWAV( "$aud_files/medium.wav" );
low = SDL2.Mix_LoadWAV( "$aud_files/low.wav" );

SDL2.Mix_PlayChannel( Int32(-1), med, Int32(0) )
SDL2.Mix_PlayMusic( music, Int32(-1) )
sleep(1)
SDL2.Mix_PauseMusic()
sleep(1)
SDL2.Mix_ResumeMusic()

sleep(1)
SDL2.Mix_HaltMusic()
