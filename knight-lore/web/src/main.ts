import { createGLContext, resizeToDisplaySize } from "./gl/context";
import { SpriteRenderer, type SpriteDrawCall } from "./gl/spriteBatch";
import { Camera } from "./render/camera";
import { rotateGrid, type ViewAngle } from "./render/isoMath";
import { listRoomIds } from "./data/roomManifest";
import { loadRoom, type LoadedRoom, type RoomView } from "./scene/room";
import { createKeyboardState, type KeyboardState } from "./input/keyboard";
import { buildObstacles, type Obstacle } from "./physics/obstacles";
import { createPlayerState, loadPlayerTexture, updatePlayer, PLAYER_PROJ_OFFSET, type PlayerState } from "./scene/player";
import { drawTopView } from "./debug/topView";
import { detectEdgeCrossing, neighborRoomId, repositionForEntry, clampToEdge, type EdgeCrossing } from "./scene/roomTransition";

const DEFAULT_ROOM_ID = 0x00;
const INITIAL_ZOOM = 1;
// Centre de la salle -- même valeur que GRID_CENTER (render/isoMath.ts),
// dupliquée ici volontairement plutôt qu'importée : pas d'entité ROM
// "joueur" réutilisable pour ce spawn (voir scene/player.ts), c'est un
// choix natif du portage.
const PLAYER_SPAWN = { gridX: 0x80, gridY: 0x80, gridZ: 0x80 };
// Frame trop longue (ex. onglet en arrière-plan) : on clamp dt plutôt que
// de laisser la physique faire un bond.
const MAX_DT = 0.05;

interface AppState {
  room: LoadedRoom;
  /** LoadedRoom ne connaît pas son propre id -- suivi ici pour calculer la
   * salle voisine lors d'un franchissement (scene/roomTransition.ts). */
  roomId: number;
  /** 0 = l'orientation du jeu original ; 1/2/3 = quarts de tour. */
  view: ViewAngle;
  /** Les salles n'ont de murs que sur 2 côtés : sous les vues tournées ils
   * passent devant la scène (voir LoadedRoom.build). */
  hideWalls: boolean;
  built: RoomView;
  camera: Camera;
  player: PlayerState;
  obstacles: Obstacle[];
  input: KeyboardState;
  /** Chargement de salle en cours (franchissement ou sélecteur) : le
   * joueur est figé, pas de nouvelle détection de franchissement tant que
   * ce n'est pas retombé à false. */
  transitioning: boolean;
}

async function main() {
  const canvas = document.getElementById("gl-canvas") as HTMLCanvasElement;
  const gl = createGLContext(canvas);
  const renderer = new SpriteRenderer(gl);
  const select = document.getElementById("room-select") as HTMLSelectElement;
  const topViewCanvas = document.getElementById("top-view") as HTMLCanvasElement;
  const topViewCtx = topViewCanvas.getContext("2d")!;

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
  const playerTexture = await loadPlayerTexture(gl);
  const state: AppState = {
    room,
    roomId: DEFAULT_ROOM_ID,
    view: 0,
    hideWalls: false,
    built,
    camera: new Camera(built.bounds),
    player: createPlayerState(playerTexture.texture, playerTexture.width, playerTexture.height, PLAYER_SPAWN),
    obstacles: buildObstacles(room.getEntities()),
    input: createKeyboardState(window),
    transitioning: false,
  };
  // Salles valides du manifest, pour ne pas tenter de charger une salle
  // voisine calculée par neighborRoomId() qui n'existe pas (bord du monde
  // 16x16, ou case inutilisée) -- voir scene/roomTransition.ts.
  const validRoomIds = new Set(roomIds);

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
    state.roomId = roomId;
    // Angle et options conservés d'une salle à l'autre (on inspecte souvent
    // plusieurs salles sous le même angle) ; seuls zoom/pan, propres au
    // cadrage précédent, repartent à zéro.
    state.camera.zoom = INITIAL_ZOOM;
    state.camera.pan = [0, 0];
    // Les obstacles sont propres à la salle ; le joueur repart au spawn --
    // téléportation via le sélecteur, pas un franchissement en marchant
    // (voir transitionRoom() pour ce cas).
    state.obstacles = buildObstacles(state.room.getEntities());
    state.player.gridX = PLAYER_SPAWN.gridX;
    state.player.gridY = PLAYER_SPAWN.gridY;
    state.player.gridZ = PLAYER_SPAWN.gridZ;
    state.player.velX = 0;
    state.player.velY = 0;
    state.player.velZ = 0;
    state.player.airborne = true;
    rebuild();
  }

  /** Franchissement d'un bord de salle en marchant (scene/roomTransition.ts) --
   * distinct de changeRoom() : le joueur n'est PAS téléporté au centre, il
   * apparaît côté opposé de la salle voisine en conservant sa coordonnée
   * perpendiculaire. `state.transitioning` fige la physique et bloque une
   * nouvelle détection tant que le chargement (async, textures) n'est pas
   * terminé. */
  async function transitionRoom(targetRoomId: number, crossing: EdgeCrossing) {
    state.transitioning = true;
    try {
      state.room = await loadRoom(gl, targetRoomId);
      state.roomId = targetRoomId;
      state.obstacles = buildObstacles(state.room.getEntities());
      repositionForEntry(state.player, crossing);
      // Cadrage repris à zéro, comme changeRoom() -- "coupure franche"
      // entre salles, cohérent avec le jeu d'origine (un écran par salle).
      state.camera.zoom = INITIAL_ZOOM;
      state.camera.pan = [0, 0];
      select.value = String(targetRoomId); // pas de dispatch "change" -> pas de rappel à changeRoom()
      rebuild();
    } finally {
      state.transitioning = false;
    }
  }

  select.addEventListener("change", () => {
    void changeRoom(parseInt(select.value, 10));
  });

  setupControls(canvas, state, rebuild);

  let lastTime = 0;
  function frame(now: number) {
    const dt = lastTime ? Math.min((now - lastTime) / 1000, MAX_DT) : 0;
    lastTime = now;

    if (!state.transitioning) {
      updatePlayer(state.player, state.input, state.obstacles, dt);

      const crossing = detectEdgeCrossing(state.player);
      if (crossing) {
        const targetRoomId = neighborRoomId(state.roomId, crossing);
        if (validRoomIds.has(targetRoomId)) {
          void transitionRoom(targetRoomId, crossing);
        } else {
          // Pas de salle voisine à cette coordonnée de la grille monde
          // 16x16 (bord du monde, ou case inutilisée) -- bloqué comme un
          // mur plutôt que de tenter de charger une salle inexistante.
          clampToEdge(state.player, crossing);
        }
      }
    }

    resizeToDisplaySize(canvas);
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clearColor(0.05, 0.05, 0.08, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    const aspect = canvas.width / canvas.height;
    const drawCalls = [...state.built.drawCalls, playerDrawCall(state)];
    renderer.draw(state.camera.getView(), state.camera.getProjection(aspect), drawCalls);
    drawTopView(topViewCtx, topViewCanvas.width, state.obstacles, state.player);
    updateHud(state);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

/** Draw call du joueur, recalculé chaque frame (position mobile) --
 * séparé de LoadedRoom.build() (statique, reconstruite seulement au
 * changement de salle/angle/murs) pour ne pas payer le recalcul complet
 * de la géométrie de salle à chaque frame. `projOffset: [0,0]` : le
 * joueur n'est pas une entité ROM, render/isoOffsets.ts (calibration par
 * type réel) ne s'applique pas ici -- PLAYER_PROJ_OFFSET (scene/player.ts)
 * ne fait que centrer le sprite sur sa case, une règle géométrique
 * générale de l'ancrage, pas une calibration ROM. */
function playerDrawCall(state: AppState): SpriteDrawCall {
  const player = state.player;
  const [rx, ry] = rotateGrid(player.gridX, player.gridY, state.view);
  return {
    texture: player.texture,
    worldPos: [rx, player.gridZ, ry],
    size: [player.width, player.height],
    projOffset: PLAYER_PROJ_OFFSET,
    flipX: false,
    // Même formule que scene/room.ts -- limite connue : un empilement de
    // blocs peut s'afficher devant le joueur dans certaines positions
    // (clé scalaire unique insuffisante quand la silhouette écran d'un
    // sprite "haut" déborde sur la case voisine). Différé, voir
    // docs/SESSION_SUMMARY.md §12bis.
    sortKey: -rx + ry - player.gridZ,
  };
}

function updateHud(state: AppState): void {
  document.getElementById("hud-view")!.textContent = String(state.view);
  document.getElementById("hud-walls")!.textContent = state.hideWalls ? "masqués" : "visibles";
  document.getElementById("hud-zoom")!.textContent = state.camera.zoom.toFixed(2);
  document.getElementById("hud-panx")!.textContent = state.camera.pan[0].toFixed(1);
  document.getElementById("hud-pany")!.textContent = state.camera.pan[1].toFixed(1);
  const player = state.player;
  document.getElementById("hud-player-pos")!.textContent =
    `${player.gridX.toFixed(1)},${player.gridY.toFixed(1)},${player.gridZ.toFixed(1)}`;
  document.getElementById("hud-player-vel")!.textContent =
    `${player.velX.toFixed(0)},${player.velY.toFixed(0)},${player.velZ.toFixed(0)}`;
  document.getElementById("hud-player-air")!.textContent = player.airborne ? "en l'air" : "au sol";
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
    if (key === "t") {
      // Anciennement "W" : libéré pour le déplacement du joueur (WASD),
      // voir input/keyboard.ts.
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
    // Les flèches ne pilotent plus la caméra (le glissé souris suffit) :
    // elles sont réaffectées au déplacement du joueur, voir
    // input/keyboard.ts et scene/player.ts.
  });
}

function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, v));
}

main().catch((err) => {
  console.error(err);
  document.body.innerHTML = `<pre style="color:#f66;padding:1em">${String(err.stack ?? err)}</pre>`;
});
