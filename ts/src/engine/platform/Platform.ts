import type { RenderCommand } from "../rendering/RenderCommands";

export interface Platform {
    init(): Promise<void>;
    beginFrame(): void;
    submit(commands: RenderCommand[]): void;
    endFrame(): void;
    setStatus(text: string): void;
}
