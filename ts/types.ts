export {};

declare global {
  type AnyValue = any;
  type Vector2 = { x: number; y: number };
  type Vector2f = { x: number; y: number };
  type Vector3f = { x: number; y: number; z: number };
  type Vector4 = { x: number; y: number; z: number; t: number };
  const JulGame: any;
  const MAIN: any;
  const C_NULL: null;
  const SDL2: any;
  const Renderer: any;

  function Vector2(x: number, y: number): Vector2;
  function Vector2f(x: number, y: number): Vector2f;
  function Vector3f(x: number, y: number, z: number): Vector3f;
  function Vector4(x: number, y: number, z: number, t: number): Vector4;

  function empty(x: any): void;
  function istaskdone(task: any): boolean;
  function schedule(task: any, ex?: any, opts?: any): void;
}