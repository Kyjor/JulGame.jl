export {};

declare global {
  type AnyValue = any;
  type Vector2 = { x: number; y: number };
  type Vector2f = { x: number; y: number };
  type Vector3f = { x: number; y: number; z: number };
  type Vector4 = { x: number; y: number; z: number; t: number };
  interface IEntity {}
  interface IUIElement {}
  interface ITransform {}
  interface IShape {}
  interface ISoundSource {}
  interface ISprite {}
  interface IAnimator {}
  interface ICollider {}
  interface ICircleCollider {}
  interface IMesh3D {}
  interface ISoftwareRenderer3D {}
  interface IObserver {}
  interface IHistory {}
  interface ICanvas extends IUIElement {}
  const JulGame: any;
  const MAIN: any;
  const C_NULL: null;
  const Renderer: any;

  function empty(x: any): void;
  function istaskdone(task: any): boolean;
  function schedule(task: any, ex?: any, opts?: any): void;
}