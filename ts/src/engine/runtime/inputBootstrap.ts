import { InputModule } from "./InputModuleGlue";
import { createInput, type TranspiledInput } from "./transpiledInput";

/** Wire transpiled `Input.ts` + `InputModuleGlue` onto JulGame/MAIN. */
export function installTranspiledInput(
    jg: Record<string, unknown>,
    main: Record<string, unknown>,
): TranspiledInput {
    const input = createInput();
    input.main = main;
    jg.InputModule = InputModule;
    main.input = input;
    return input;
}
