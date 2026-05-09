import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";

const chromePath = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
const videoPath = process.argv[2] ? path.resolve(process.argv[2]) : "";
const outputPath = process.argv[3] ? path.resolve(process.argv[3]) : path.resolve("tmp/video_preview.png");
const userDataDir = path.resolve("tmp/chrome_video_preview");
const port = 9231;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchJson(url, retries = 40) {
  let lastError;
  for (let attempt = 0; attempt < retries; attempt += 1) {
    try {
      const response = await fetch(url);
      if (response.ok) return await response.json();
      lastError = new Error(`HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await sleep(250);
  }
  throw lastError;
}

async function cdpCall(socket, method, params = {}) {
  const id = ++cdpCall.nextId;
  const pending = new Promise((resolve, reject) => {
    cdpCall.pending.set(id, { resolve, reject });
  });
  socket.send(JSON.stringify({ id, method, params }));
  return pending;
}
cdpCall.nextId = 0;
cdpCall.pending = new Map();

if (!videoPath || !fs.existsSync(videoPath)) {
  throw new Error(`Video not found: ${videoPath}`);
}

fs.mkdirSync(userDataDir, { recursive: true });
fs.mkdirSync(path.dirname(outputPath), { recursive: true });

const browser = spawn(chromePath, [
  "--headless=new",
  "--disable-crash-reporter",
  "--disable-crashpad",
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${userDataDir}`,
  "--autoplay-policy=no-user-gesture-required",
  "about:blank",
], { stdio: "ignore", windowsHide: true });

try {
  await fetchJson(`http://127.0.0.1:${port}/json/version`);
  const pages = await fetchJson(`http://127.0.0.1:${port}/json/list`);
  const page = pages.find((entry) => entry.type === "page" && entry.webSocketDebuggerUrl);
  if (!page) throw new Error("No debuggable page target found");

  const socket = new WebSocket(page.webSocketDebuggerUrl);
  socket.addEventListener("message", (event) => {
    const data = JSON.parse(event.data);
    if (data.id && cdpCall.pending.has(data.id)) {
      const pending = cdpCall.pending.get(data.id);
      cdpCall.pending.delete(data.id);
      data.error ? pending.reject(new Error(data.error.message)) : pending.resolve(data.result);
    }
  });

  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  await cdpCall(socket, "Runtime.enable");
  const videoUrl = "data:video/mp4;base64," + fs.readFileSync(videoPath).toString("base64");
  const expression = `
    (async () => {
      const video = document.createElement("video");
      video.src = ${JSON.stringify(videoUrl)};
      video.muted = true;
      video.preload = "auto";
      document.body.appendChild(video);
      await new Promise((resolve, reject) => {
        video.addEventListener("loadedmetadata", resolve, { once: true });
        video.addEventListener("error", () => reject(new Error("video load failed")), { once: true });
      });

      const frameW = 360;
      const frameH = 640;
      const frames = 4;
      const canvas = document.createElement("canvas");
      canvas.width = frameW * frames;
      canvas.height = frameH;
      const ctx = canvas.getContext("2d");
      ctx.fillStyle = "#111";
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      const scale = Math.max(frameW / video.videoWidth, frameH / video.videoHeight);
      const drawW = video.videoWidth * scale;
      const drawH = video.videoHeight * scale;
      const drawX = (frameW - drawW) * 0.5;
      const drawY = (frameH - drawH) * 0.5;
      const duration = Number.isFinite(video.duration) && video.duration > 0 ? video.duration : 2.4;
      const times = [0.08, 0.33, 0.58, 0.83].map((v) => Math.min(duration - 0.05, duration * v));

      for (let i = 0; i < frames; i += 1) {
        await new Promise((resolve, reject) => {
          video.addEventListener("seeked", resolve, { once: true });
          video.addEventListener("error", () => reject(new Error("seek failed")), { once: true });
          video.currentTime = Math.max(0, times[i]);
        });
        ctx.drawImage(video, i * frameW + drawX, drawY, drawW, drawH);
      }

      return {
        dataUrl: canvas.toDataURL("image/png"),
        videoWidth: video.videoWidth,
        videoHeight: video.videoHeight,
        duration
      };
    })()
  `;

  const result = await cdpCall(socket, "Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
  });
  if (result.exceptionDetails) {
    throw new Error(result.exceptionDetails.text || "Runtime exception");
  }
  const value = result.result.value;
  fs.writeFileSync(outputPath, Buffer.from(value.dataUrl.split(",")[1], "base64"));
  console.log(JSON.stringify({ outputPath, videoWidth: value.videoWidth, videoHeight: value.videoHeight, duration: value.duration }, null, 2));
  socket.close();
} finally {
  browser.kill();
}
