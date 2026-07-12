export {};

declare global {
  type AnyValue = any;
  type JulGameAnimation = { animatedFPS: number; frames: Vector4[]; framePaths?: string[] };
  type Vector2 = { x: number; y: number };
  type Vector2f = { x: number; y: number };
  type Vector3f = { x: number; y: number; z: number };
  type Vector4 = { x: number; y: number; z: number; t: number };
  interface IEntity {
    [key: string]: any
  }
  interface IUIElement {
    [key: string]: any
  }
  interface ITransform {
    [key: string]: any;
  }
  interface IShape {
    [key: string]: any
  }
  interface ISoundSource {
    [key: string]: any
  }
  interface ISprite {
    crop: any;
    [key: string]: any;
  }
  interface IAnimator {
    [key: string]: any
  }
  interface ICollider {
    [key: string]: any
  }
  interface ICircleCollider {
    [key: string]: any
  }
  type InternalSprite = any;
  type InternalAnimator = any;
  type InternalCollider = any;
  type InternalCircleCollider = any;
  type InternalRigidbody = any;
  type InternalShape = any;
  type InternalSoundSource = any;
  interface IMesh3D {}
  interface ISoftwareRenderer3D {}
  interface IObserver {}
  interface IHistory {}
  interface ICanvas extends IUIElement {}
  const MAIN: any;
  const C_NULL: null;
  const Renderer: any;
  /** Wasm SDL / SDL_mixer glue (`glue_SDL_*`, `glue_Mix_*`, …) — surface grows with `tools/convert.jl`. */
  const JulGameSdl: Record<string, any>;

  function empty(x: any): void;
  function setfield(target: any, key: any, value: any): void;
  function istaskdone(task: any): boolean;
  function schedule(task: any, ex?: any, opts?: any): void;

  /** @see src/utils/Enums.jl — assigned in globalConstants.ts */
  type CollisionDirection = -1 | 1 | 2 | 3 | 4;
  type ColliderLocation = 1 | 2 | 3 | 4;

  const None: CollisionDirection;
  const Top: CollisionDirection;
  const Bottom: CollisionDirection;
  const Left: CollisionDirection;
  const Right: CollisionDirection;
  const Above: ColliderLocation;
  const Below: ColliderLocation;
  const LeftSide: ColliderLocation;
  const RightSide: ColliderLocation;

  /**
   * Generated `function Component_*` live in `ts/_generated/.../Component/*.ts` as separate modules
   * (`export {}`); implementations load together at runtime. Declarations here satisfy cross-file refs.
   */
  function Component_check_collisions(self: InternalCollider): void;
  function Component_duplicate(self: any, parent: any): any;
  function Component_initialize(self: any, ...args: any[]): void;
  function Component_toggle_sound(self: any, loops?: number): void;
  function Component_destroy(self: any): void;
  function Component_unload_sound(self: any): void;
  function Component_render(self: any, ctx: any): void;
  function Component_draw(self: any, camera?: any): void;
}