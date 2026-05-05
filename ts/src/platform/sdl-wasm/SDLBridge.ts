import { loadSDLModule } from "./sdlModule";

type Cwrap = (
    ident: string,
    returnType: string | null,
    argTypes: string[],
) => (...args: number[]) => unknown;

type EmscriptenModuleShape = Record<string, unknown> & {
    cwrap?: Cwrap;
};

export type JulGameSdlApi = {
    glue_init: (width: number, height: number) => number;
    glue_render_square_frame: () => void;
    glue_poll_quit: () => number;
};

export class SDLBridge {
    private module: EmscriptenModuleShape | null = null;
    private api: JulGameSdlApi | null = null;

    async init(
        canvas: HTMLCanvasElement,
        print: (text: string) => void,
        printErr: (text: string) => void,
    ): Promise<void> {
        this.module = (await loadSDLModule(canvas, print, printErr)) as EmscriptenModuleShape;
        const cwrap = this.module.cwrap;
        if (typeof cwrap !== "function") {
            throw new Error("Emscripten module missing cwrap (add EXPORTED_RUNTIME_METHODS)");
        }
        this.api = {
            glue_init: cwrap("glue_init", "number", ["number", "number"]) as JulGameSdlApi["glue_init"],
            glue_render_square_frame: cwrap("glue_render_square_frame", null, []) as JulGameSdlApi["glue_render_square_frame"],
            glue_poll_quit: cwrap("glue_poll_quit", "number", []) as JulGameSdlApi["glue_poll_quit"],
        };
    }

    getApi(): JulGameSdlApi {
        if (!this.api) {
            throw new Error("SDL bridge not initialized");
        }
        return this.api;
    }

    getModule(): EmscriptenModuleShape {
        if (!this.module) {
            throw new Error("SDL module is not initialized");
        }
        return this.module;
    }
}
