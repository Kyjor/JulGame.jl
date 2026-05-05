const width = 800;
const height = 600;

document.title = "JulGame Web Test";

const canvas = document.createElement("canvas");
canvas.width = width;
canvas.height = height;
canvas.style.display = "block";
canvas.style.margin = "0 auto";
document.body.style.margin = "0";
document.body.style.background = "#0f172a";
document.body.appendChild(canvas);

function getContext2DOrThrow(target: HTMLCanvasElement): CanvasRenderingContext2D {
    const ctx = target.getContext("2d");
    if (!ctx) throw new Error("Failed to acquire 2D context");
    return ctx;
}

const context = getContext2DOrThrow(canvas);

let t = 0;
function frame() {
    t += 0.016;
    const r = Math.floor(40 + Math.sin(t) * 20);
    const g = Math.floor(80 + Math.sin(t * 1.7) * 30);
    const b = Math.floor(130 + Math.sin(t * 1.2) * 25);
    context.fillStyle = `rgb(${r}, ${g}, ${b})`;
    context.fillRect(0, 0, width, height);
    requestAnimationFrame(frame);
}

requestAnimationFrame(frame);

