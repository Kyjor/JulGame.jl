import {
    Component_load_sound,
    Component_toggle_sound,
} from "../../../_generated/src/engine/Component/SoundSource";
import type { Scene } from "../../../_generated/src/engine/Scene";

/** SDL2 `AUDIO_S16LSB` / mixer default for `Mix_OpenAudio`. */
export const MIX_DEFAULT_FORMAT = 0x8010;

type AudioApi = {
    glue_Mix_OpenAudio: (frequency: number, format: number, channels: number, chunksize: number) => number;
    glue_Mix_MasterVolume?: (volume: number) => number;
    glue_SDL_GetError?: () => string;
};

let audioOpened = false;

export function tryOpenGameAudio(api: AudioApi): boolean {
    if (audioOpened) {
        return true;
    }
    const code = api.glue_Mix_OpenAudio(22050, MIX_DEFAULT_FORMAT, 2, 1024);
    if (code === 0) {
        audioOpened = true;
        api.glue_Mix_MasterVolume?.(128);
    } else if (api.glue_SDL_GetError) {
        console.warn(`Mix_OpenAudio failed: ${api.glue_SDL_GetError()}`);
    }
    return audioOpened;
}

export function reloadEntitySounds(scene: Scene): void {
    for (const entity of scene.entities) {
        const ss = entity.soundSource as { path?: string; isMusic?: boolean } | null;
        if (!ss?.path) {
            continue;
        }
        Component_load_sound(ss as never, ss.path, !!ss.isMusic);
    }
}

/** Julia `initialize_scripts_and_components` — start `playOnStart` music/SFX after audio is open. */
export function playSoundsOnStart(scene: Scene): void {
    for (const entity of scene.entities) {
        const ss = entity.soundSource as {
            playOnStart?: boolean;
            isPlaying?: boolean;
            path?: string;
        } | null;
        if (!ss?.playOnStart || ss.isPlaying) {
            continue;
        }
        Component_toggle_sound(ss as never);
    }
}
