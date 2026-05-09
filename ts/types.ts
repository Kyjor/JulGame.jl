export {};

declare global {
  type AnyValue = any;
  type JulGameAnimation = { animatedFPS: number; frames: Vector4[] };
  type Vector2 = { x: number; y: number };
  type Vector2f = { x: number; y: number };
  type Vector3f = { x: number; y: number; z: number };
  type Vector4 = { x: number; y: number; z: number; t: number };
  interface IEntity {}
  interface IUIElement {}
  interface ITransform {
    position: Vector3f;
    scale: Vector2f;
  }
  interface IShape {}
  interface ISoundSource {}
  interface ISprite {
    crop: any;
    [key: string]: any;
  }
  interface IAnimator {}
  interface ICollider {}
  interface ICircleCollider {}
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
  const JulGameSdl: {
    glue_SDL_SetRenderDrawBlendMode_BLEND(): void;
    glue_SDL_SetRenderDrawColor(r: number, g: number, b: number, a: number): void;
    glue_SDL_RenderFillRectF(x: number, y: number, w: number, h: number): void;
  };

  function empty(x: any): void;
  function setfield(target: any, key: any, value: any): void;
  function istaskdone(task: any): boolean;
  function schedule(task: any, ex?: any, opts?: any): void;
}