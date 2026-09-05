import { createGLContext, resizeToDisplaySize } from "./gl/context";
import { SpriteRenderer } from "./gl/spriteBatch";
import { Camera } from "./render/camera";
import { rotateGrid, type ViewAngle } from "./render/isoMath";
import { listRoomIds, loadGuardSpawns } from "./data/roomManifest";
import { loadSpriteIndex } from "./data/spriteManifest";
import { loadRoom, type LoadedRoom, type RoomView } from "./scene/room";
import { createKeyboardState, type KeyboardState } from "./input/keyboard";
import { buildObstacles, type Obstacle } from "./physics/obstacles";
import { boundsForRoom } from "./physics/roomBounds";
import {
  createPushables,
  pushableDrawCalls,
  pushableObstacles,
  updatePushables,
  type PushableBody,
} from "./scene/pushables";
import {
  createPlayerState,
  loadPlayerFrames,
  updatePlayer,
  playerDrawCalls,
  armTransformCooldownAfterDoor,
  type PlayerState,
} from "./scene/player";
import { startNewGame, type NewGame } from "./game/newGame";
import { objectsInRoom } from "./game/objectCatalog";
import { loadRoomObjects, objectDrawCalls, type RoomObject } from "./scene/objects";
import {
  createDayNightState,
  updateDayNight,
  cancelPendingTransform,
  dayCounterDecimal,
  halfCycleProgress,
  type DayNightState,
} from "./game/dayNight";
import { createGuardState, updateGuard, guardDrawCalls, type GuardState } from "./scene/guard";
import { drawTopView } from "./debug/topView";
import { TickAccumulator } from "./game/tick";
import { readIntent, type ControlMode } from "./input/controlMode";
import {
  detectEdgeCrossing,
  neighborRoomId,
  repositionForEntry,
  clampToEdge,
  hasDoorForCrossing,
  type EdgeCrossing,
} from "./scene/roomTransition";

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
  /** Mode de contrôle actif. L'original couple ce choix au périphérique
   * (clavier -> toujours rotation) ; le portage les découple -- écart assumé,
   * voir web/DEVIATIONS.md et input/controlMode.ts. "rotation" n'est pas
   * encore appliqué par scene/player.ts : le pilote existe, la règle de jeu
   * viendra avec le chantier correspondant. */
  controlMode: ControlMode;
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
  guards: GuardState[];
  /** Décor INERTE seulement. Les corps mobiles sont dans `pushables` et
   * fournissent leur obstacle à leur position courante -- voir syncObstacles(). */
  obstacles: Obstacle[];
  pushables: PushableBody[];
  /** Horloge du jeu : cycle jour/nuit, compteur de jours, et demande de
   * transformation du joueur. Volontairement HORS de la salle et hors du
   * joueur -- c'est un état de partie, il survit aux changements de salle
   * comme `var_day_night_flag` survit à fn_room_init. */
  dayNight: DayNightState;
  /** Décisions prises au LANCEMENT de la partie : salle de départ et
   * attribution des types du catalogue d'objets. Immuable pour la durée de la
   * partie -- c'est un octet du jeu d'origine (game/newGame.ts). */
  game: NewGame;
  /** Objets à ramasser présents dans la salle courante, tirés du CATALOGUE et
   * non du manifest (voir scene/objects.ts). */
  roomObjects: RoomObject[];
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

  /** Charge les gardes (scene/guard.ts) présents dans une salle -- entités
   * ROM réelles, indexées par le MÊME SpriteIndex que le décor statique
   * (re-fetch léger plutôt que de faire porter ce couplage à LoadedRoom). */
  async function loadGuards(roomId: number): Promise<GuardState[]> {
    const [spawns, spriteIndex] = await Promise.all([loadGuardSpawns(roomId), loadSpriteIndex()]);
    return Promise.all(spawns.map((spawn) => createGuardState(gl, spriteIndex, spawn)));
  }

  // `state` est un objet mutable (pas des `let` séparés) pour que
  // setupControls() et la boucle frame() gardent une référence stable même
  // quand on change de salle ou d'angle.
  // Une partie de Knight Lore, c'est un octet : salle de départ et catalogue
  // d'objets en découlent tous les deux (game/newGame.ts).
  const game = startNewGame();
  // Le sélecteur suit la salle de départ tirée : sans ça il afficherait
  // encore DEFAULT_ROOM_ID alors qu'on joue ailleurs.
  select.value = String(game.startRoom);
  const room = await loadRoom(gl, game.startRoom);
  const built = room.build(0, false);
  const playerSpriteIndex = await loadSpriteIndex();
  const playerFrames = await loadPlayerFrames(gl, playerSpriteIndex);
  const guards = await loadGuards(game.startRoom);
  const startObjects = await loadRoomObjects(
    gl,
    playerSpriteIndex,
    objectsInRoom(game.catalog, game.startRoom),
  );
  const state: AppState = {
    controlMode: "directional",
    room,
    roomId: game.startRoom,
    view: 0,
    hideWalls: false,
    built,
    camera: new Camera(built.bounds),
    player: createPlayerState(playerFrames, PLAYER_SPAWN),
    guards,
    obstacles: buildObstacles(room.getEntities()),
    pushables: createPushables(room.getMovableEntities()),
    dayNight: createDayNightState(),
    game,
    roomObjects: startObjects,
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
    state.pushables = createPushables(state.room.getMovableEntities());
    state.guards = await loadGuards(roomId);
    state.roomObjects = await loadRoomObjects(
      gl,
      await loadSpriteIndex(),
      objectsInRoom(state.game.catalog, roomId),
    );
    state.player.gridX = PLAYER_SPAWN.gridX;
    state.player.gridY = PLAYER_SPAWN.gridY;
    state.player.gridZ = PLAYER_SPAWN.gridZ;
    state.player.velX = 0;
    state.player.velY = 0;
    state.player.velZ = 0;
    state.player.airborne = true;
    // Phase de marche remise à zéro en changeant de salle : le joueur y est
    // replacé à l'arrêt, et le gel de phase (walkAnimation.ts) le laisserait
    // sinon figé au milieu d'une foulée d'une salle à l'autre.
    // Phase de marche remise à zéro en changeant de salle : le joueur y est
    // replacé à l'arrêt, et le gel de phase (walkAnimation.ts) le laisserait
    // sinon figé au milieu d'une foulée d'une salle à l'autre.
    state.player.anim.phase = 0;
    cancelPendingTransform(state.dayNight);
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
      // Les corps mobiles repartent de leur position de manifest à chaque
      // (re)chargement : la ROM ne conserve pas l'état d'une salle qu'on
      // quitte non plus -- ses 40 slots sont réécrits depuis les données de
      // la nouvelle salle (fn_room_init). Un coffre poussé n'est donc pas un
      // état persistant à sauvegarder.
      state.pushables = createPushables(state.room.getMovableEntities());
      state.guards = await loadGuards(targetRoomId);
      state.roomObjects = await loadRoomObjects(
        gl,
        await loadSpriteIndex(),
        objectsInRoom(state.game.catalog, targetRoomId),
      );
      repositionForEntry(state.player, crossing);
      // Franchir une porte refuse la transformation pendant 3 ticks (`or #30`
      // sur le cooldown, asm/code/doors_and_player_logic.asm:761-763). Armé
      // ici parce que c'est ici que le portage fait ce que la ROM fait dans
      // fn_player_door_transition.
      armTransformCooldownAfterDoor(state.player);
      // Une demande de transformation en attente est PERDUE en entrant dans
      // une salle (fn_init_room_entities #29B4 remet #0077 à zéro). Le cycle,
      // lui, continue -- seule la demande tombe.
      cancelPendingTransform(state.dayNight);
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

  // Boucle à PAS FIXE (game/tick.ts). Le temps réel écoulé est converti en
  // un nombre entier de ticks de logique ; le rendu affiche l'état DU TICK,
  // sans interpolation. Choix délibéré : interpoler afficherait le joueur à
  // des positions qu'il n'occupe jamais, donc à des endroits où aucun test
  // de collision n'a été fait -- des bugs perçus comme du hasard.
  const ticker = new TickAccumulator();
  let lastTime = 0;
  function frame(now: number) {
    const dt = lastTime ? Math.min((now - lastTime) / 1000, MAX_DT) : 0;
    lastTime = now;

    const ticks = ticker.take(dt);
    for (let i = 0; i < ticks && !state.transitioning; i++) {
      // Les corps mobiles sont des obstacles À LEUR POSITION COURANTE : la
      // liste est reconstruite à chaque tick, elle ne peut pas être mise en
      // cache avec le décor.
      const obstacles = state.obstacles.concat(pushableObstacles(state.pushables));

      // AVANT le joueur : c'est le cycle qui pose la demande de
      // transformation, et le joueur la consomme dans le même tick s'il le
      // peut. L'ordre inverse ajouterait un tick de latence à chaque
      // basculement, invisible mais faux.
      updateDayNight(state.dayNight);

      // Limite de salle : dépend de la salle courante (3 calibrations selon
      // le ratio d'aspect, physics/roomBounds.ts), donc relue à chaque tick
      // plutôt que mise en cache -- une lecture de table, et une source de
      // vérité unique quand on change de salle.
      const bounds = boundsForRoom(state.roomId);

      const intent = readIntent(state.controlMode, state.input);
      updatePlayer(state.player, intent, obstacles, state.dayNight);
      for (const guard of state.guards) {
        updateGuard(guard, obstacles, bounds);
      }
      // APRÈS le joueur et les gardes, jamais avant : le joueur est le slot 0
      // de la table d'entités et fn_main_loop dispatche en ordre croissant
      // (asm/code/low_ram_and_boot.asm:224-252). Les poussées de ce tick sont
      // donc déjà écrites quand les corps jouent le leur -- et c'est
      // précisément cet ordre qui décide du comportement du bloc 0x3E (voir
      // physics/solidTypes.ts).
      updatePushables(state.pushables, state.obstacles, bounds);

      const crossing = detectEdgeCrossing(state.player);
      if (crossing) {
        // Une transition n'a lieu QUE là où une vraie porte existe sur ce
        // côté précis (règle confirmée en testant, 2026-09-04) -- sinon,
        // même si neighborRoomId() désigne une salle existante, un trou
        // dans la couverture des murs (données réelles imparfaites, voir
        // physics/obstacles.ts) pourrait donner accès à une salle qui n'est
        // pas réellement connectée par une porte.
        const targetRoomId = neighborRoomId(state.roomId, crossing);
        const perpCoord = crossing.axis === "x" ? state.player.gridY : state.player.gridX;
        if (hasDoorForCrossing(state.room.getEntities(), crossing, perpCoord) && validRoomIds.has(targetRoomId)) {
          void transitionRoom(targetRoomId, crossing);
        } else {
          // Pas de porte sur ce côté, ou pas de salle voisine à cette
          // coordonnée de la grille monde 16x16 (bord du monde, case
          // inutilisée) -- bloqué comme un mur plutôt que de traverser.
          clampToEdge(state.player, crossing);
        }
      }
    }

    resizeToDisplaySize(canvas);
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clearColor(0.05, 0.05, 0.08, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    const aspect = canvas.width / canvas.height;
    const drawCalls = [
      ...state.built.drawCalls,
      ...playerDrawCalls(state.player, state.view),
      ...state.guards.flatMap((guard) => guardDrawCalls(guard, state.view)),
      ...pushableDrawCalls(state.pushables, state.view),
      ...objectDrawCalls(state.roomObjects, state.view),
    ];
    renderer.draw(state.camera.getView(), state.camera.getProjection(aspect), drawCalls);
    drawTopView(
      topViewCtx,
      topViewCanvas.width,
      state.obstacles.concat(pushableObstacles(state.pushables)),
      state.player,
      state.guards,
    );
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
  const player = state.player;
  document.getElementById("hud-player-pos")!.textContent =
    `${player.gridX.toFixed(1)},${player.gridY.toFixed(1)},${player.gridZ.toFixed(1)}`;
  document.getElementById("hud-player-vel")!.textContent =
    `${player.velX.toFixed(0)},${player.velY.toFixed(0)},${player.velZ.toFixed(0)}`;
  document.getElementById("hud-player-air")!.textContent = player.airborne ? "en l'air" : "au sol";

  const dn = state.dayNight;
  const phase = dn.phase === "day" ? "jour" : "nuit";
  const progress = Math.round(halfCycleProgress(dn) * 100);
  document.getElementById("hud-phase")!.textContent = player.transform
    ? `transformation (${player.transform.stepsLeft})`
    : `${phase} ${progress}%`;
  document.getElementById("hud-days")!.textContent = dn.daysExhausted
    ? `${dayCounterDecimal(dn)} (épuisé)`
    : String(dayCounterDecimal(dn));
  document.getElementById("hud-seed")!.textContent =
    `${state.game.seed.toString(16)} (départ 0x${state.game.startRoom.toString(16)})`;
  document.getElementById("hud-objects")!.textContent = state.roomObjects.length
    ? state.roomObjects.map((o) => `0x${o.placed.type.toString(16)}`).join(" ")
    : "aucun";
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
