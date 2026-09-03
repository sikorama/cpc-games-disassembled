import { createGLContext, resizeToDisplaySize } from "./gl/context";
import { SpriteRenderer } from "./gl/spriteBatch";
import { Camera } from "./render/camera";
import type { ViewAngle } from "./render/isoMath";
import { listRoomIds } from "./data/roomManifest";
import { loadRoom, type LoadedRoom, type RoomView } from "./scene/room";

const DEFAULT_ROOM_ID = 0x00;
const INITIAL_ZOOM = 1;

interface AppState {
  room: LoadedRoom;
  /** 0 = l'orientation du jeu original ; 1/2/3 = quarts de tour. */
  view: ViewAngle;
  /** Les salles n'ont de murs que sur 2 côtés : sous les vues tournées ils
   * passent devant la scène (voir LoadedRoom.build). */
  hideWalls: boolean;
  built: RoomView;
  camera: Camera;
}

async function main() {
  const canvas = document.getElementById("gl-canvas") as HTMLCanvasElement;
  const gl = createGLContext(canvas);
  const renderer = new SpriteRenderer(gl);
  const select = document.getElementById("room-select") as HTMLSelectElement;

  const roomIds = await listRoomIds();
  for (const id of roomIds) {
    const option = document.createElement("option");
    option.value = String(id);
    option.textContent = `0x${id.toString(16).padStart(2, "0")}`;
    select.appendChild(option);
  }
  select.value = String(DEFAULT_ROOM_ID);

  // `state` est un objet mutable (pas des `let` séparés) pour que
  // setupControls() et la boucle frame() gardent une référence stable même
  // quand on change de salle ou d'angle.
  const room = await loadRoom(gl, DEFAULT_ROOM_ID);
  const built = room.build(0, false);
  const state: AppState = {
    room,
    view: 0,
    hideWalls: false,
    built,
    camera: new Camera(built.bounds),
  };

  /** Recalcule la géométrie pour l'angle/les options courants. Aucune texture
   * n'est rechargée : changer d'angle est purement géométrique. Le zoom et le
   * pan sont conservés (on veut comparer les 4 angles au même cadrage), le
   * recadrage automatique se fait via les nouvelles `bounds`. */
  function rebuild() {
    state.built = state.room.build(state.view, state.hideWalls);
    state.camera.bounds = state.built.bounds;
  }

  async function changeRoom(roomId: number) {
    state.room = await loadRoom(gl, roomId);
    // Angle et options conservés d'une salle à l'autre (on inspecte souvent
    // plusieurs salles sous le même angle) ; seuls zoom/pan, propres au
    // cadrage précédent, repartent à zéro.
    state.camera.zoom = INITIAL_ZOOM;
    state.camera.pan = [0, 0];
    rebuild();
  }

  select.addEventListener("change", () => {
    void changeRoom(parseInt(select.value, 10));
  });

  setupControls(canvas, state, rebuild);

  function frame() {
    resizeToDisplaySize(canvas);
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clearColor(0.05, 0.05, 0.08, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    const aspect = canvas.width / canvas.height;
    renderer.draw(state.camera.getView(), state.camera.getProjection(aspect), state.built.drawCalls);
    updateHud(state);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

function updateHud(state: AppState): void {
  document.getElementById("hud-view")!.textContent = String(state.view);
  document.getElementById("hud-walls")!.textContent = state.hideWalls ? "masqués" : "visibles";
  document.getElementById("hud-zoom")!.textContent = state.camera.zoom.toFixed(2);
  document.getElementById("hud-panx")!.textContent = state.camera.pan[0].toFixed(1);
  document.getElementById("hud-pany")!.textContent = state.camera.pan[1].toFixed(1);
}

function setupControls(canvas: HTMLCanvasElement, state: AppState, rebuild: () => void) {
  let dragging = false;
  let lastX = 0;
  let lastY = 0;

  canvas.addEventListener("pointerdown", (e) => {
    dragging = true;
    lastX = e.clientX;
    lastY = e.clientY;
    canvas.style.cursor = "grabbing";
  });
  window.addEventListener("pointerup", () => {
    dragging = false;
    canvas.style.cursor = "grab";
  });
  window.addEventListener("pointermove", (e) => {
    if (!dragging) return;
    // Le glissé déplace la vue (pan) ; il faisait auparavant tourner une
    // caméra libre, ce qui changeait de projection au premier pixel et
    // cassait le tri peintre. Les 4 angles isométriques se prennent
    // maintenant à la touche R.
    const dx = e.clientX - lastX;
    const dy = e.clientY - lastY;
    lastX = e.clientX;
    lastY = e.clientY;
    // Signe : l'espace caméra a +Y vers le BAS comme l'écran, donc le pan
    // suit directement le mouvement de la souris sur les deux axes.
    state.camera.pan = [state.camera.pan[0] - dx * 0.5, state.camera.pan[1] - dy * 0.5];
  });
  canvas.addEventListener("wheel", (e) => {
    e.preventDefault();
    state.camera.zoom = clamp(state.camera.zoom * (e.deltaY > 0 ? 1.1 : 0.9), 0.1, 10);
  });
  window.addEventListener("keydown", (e) => {
    const camera = state.camera;
    const key = e.key.toLowerCase();

    if (key === "r") {
      // R / Maj+R : quart de tour dans un sens ou dans l'autre.
      state.view = (((state.view + (e.shiftKey ? 3 : 1)) % 4) as ViewAngle);
      rebuild();
      return;
    }
    if (key === "w") {
      state.hideWalls = !state.hideWalls;
      rebuild();
      return;
    }
    if (key === "c") {
      // Retour EXACT au cadrage de départ : angle, murs, zoom et pan.
      state.view = 0;
      state.hideWalls = false;
      camera.zoom = INITIAL_ZOOM;
      camera.pan = [0, 0];
      rebuild();
      return;
    }

    // Flèches : pan par petits pas lisibles (Maj = pas fin d'1 unité), pour
    // pouvoir régler précisément puis relire la valeur dans le HUD.
    const step = e.shiftKey ? 1 : 8;
    if (e.key === "ArrowLeft") camera.pan = [camera.pan[0] - step, camera.pan[1]];
    else if (e.key === "ArrowRight") camera.pan = [camera.pan[0] + step, camera.pan[1]];
    else if (e.key === "ArrowUp") camera.pan = [camera.pan[0], camera.pan[1] - step];
    else if (e.key === "ArrowDown") camera.pan = [camera.pan[0], camera.pan[1] + step];
  });
}

function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, v));
}

main().catch((err) => {
  console.error(err);
  document.body.innerHTML = `<pre style="color:#f66;padding:1em">${String(err.stack ?? err)}</pre>`;
});
