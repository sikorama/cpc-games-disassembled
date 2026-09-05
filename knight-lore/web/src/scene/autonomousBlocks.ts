// Blocs à MOUVEMENT AUTONOME (voir web/CONTEXT.md) : bloc mobile 0x36/0x37 et
// cube qui s'enfonce 0x5B.
//
// À ne pas confondre avec les corps poussables (scene/pushables.ts), même
// s'ils partagent le sprite du petit bloc. Ceux-ci ne portent PAS le bit
// poussable -- vérifié sur les 128 salles -- et ne réagissent donc jamais à ce
// qui les heurte. Leur mouvement leur est propre : oscillation pour l'un,
// enfoncement sous le poids pour l'autre.

import type { Box3 } from "../physics/aabb";
import { resolveAxis } from "../physics/aabb";
import type { Obstacle } from "../physics/obstacles";
import { entityBox, BLOCK_HALF_EXTENT, BLOCK_HEIGHT } from "../physics/obstacles";
import { clampDeltaToRoom, clampDeltaToFloor, type RoomBound } from "../physics/roomBounds";
import type { SpriteDrawCall } from "../gl/spriteBatch";
import type { ViewAngle } from "../render/isoMath";
import { entityDrawCall, type ResolvedEntity } from "./room";

export const MOVING_BLOCK_X = 0x36;
export const MOVING_BLOCK_Y = 0x37;
export const SINKING_CUBE = 0x5b;

export function isAutonomousBlockType(type: number): boolean {
  return type === MOVING_BLOCK_X || type === MOVING_BLOCK_Y || type === SINKING_CUBE;
}

/** Base et pas de la table des 40 slots d'entité (`struct_entities_base`). Sert
 * uniquement à retrouver l'adresse d'un slot, dont la ROM extrait un bit pour
 * déphaser les blocs mobiles entre eux -- voir `slotPhase()`. */
const ENTITY_BASE = 0x00d7;
const ENTITY_STRIDE = 0x1c;

/**
 * Déphasage d'un bloc mobile, 0 ou 0x10.
 *
 * FAIT ROM : `push ix / pop bc / ld a,c / rrca / and #10` -- la routine prend
 * l'octet BAS DE L'ADRESSE du slot, le fait tourner d'un cran à droite et en
 * garde le bit 4, ce qui revient à tester le **bit 5 de l'adresse**. Deux blocs
 * d'une même salle n'oscillent donc pas en phase, et le motif dépend de la
 * place qu'ils occupent dans la table d'entités.
 *
 * Le portage peut le reproduire exactement, et pas seulement l'imiter : le
 * manifest conserve l'indice de slot de chaque entité, et l'adresse s'en déduit.
 * Sans lui il aurait fallu inventer un déphasage — visible, donc un écart.
 */
function slotPhase(slot: number): number {
  const addressLow = (ENTITY_BASE + ENTITY_STRIDE * slot) & 0xff;
  return (addressLow & 0x20) !== 0 ? 0x10 : 0x00;
}

/**
 * Position visée par un bloc mobile à une frame donnée, sur 0..15.
 *
 * FAIT ROM : `A = var_frame_counter + phase`, puis `bit 4,a` → si le bit est
 * posé, `cpl` (complément), et enfin `and #0F`. C'est une **onde
 * triangulaire** : la cible monte de 0 à 15 pendant 16 frames, puis redescend
 * pendant les 16 suivantes. Le bloc ne « rebondit » donc pas sur des bornes,
 * il suit une cible qui fait l'aller-retour toute seule.
 */
function targetForFrame(frameCounter: number, phase: number): number {
  const t = (frameCounter + phase) & 0xff;
  return ((t & 0x10) !== 0 ? ~t : t) & 0x0f;
}

abstract class BlockBody {
  gridX: number;
  gridY: number;
  gridZ: number;

  constructor(
    readonly resolved: ResolvedEntity,
    protected readonly halfX: number,
    protected readonly halfY: number,
    protected readonly height: number,
  ) {
    this.gridX = resolved.entity.gridX;
    this.gridY = resolved.entity.gridY;
    this.gridZ = resolved.entity.gridZ;
  }

  box(): Box3 {
    return {
      minX: this.gridX - this.halfX,
      maxX: this.gridX + this.halfX,
      minY: this.gridY - this.halfY,
      maxY: this.gridY + this.halfY,
      minZ: this.gridZ,
      maxZ: this.gridZ + this.height,
    };
  }

  drawCall(view: ViewAngle): SpriteDrawCall {
    return entityDrawCall(this.resolved, this.gridX, this.gridY, this.gridZ, view);
  }

  abstract obstacle(): Obstacle;
}

/**
 * Bloc mobile 0x36 (axe X) / 0x37 (axe Y).
 *
 * UNE SEULE ROUTINE, DEUX AXES. `fn_moving_block_logic` (#0F98) réécrit en code
 * auto-modifiant les octets de DÉPLACEMENT de deux `(ix+dd)` : 0x36 lit
 * `grid_x` et écrit le vecteur X, 0x37 lit `grid_y` et écrit le vecteur Y. Même
 * amplitude, même vitesse — seul l'axe change. Voir docs/METHODOLOGY.md §28.
 */
export class MovingBlock extends BlockBody {
  readonly axis: "x" | "y";
  private readonly phase: number;

  constructor(resolved: ResolvedEntity, halfX: number, halfY: number, height: number) {
    super(resolved, halfX, halfY, height);
    this.axis = resolved.entity.type === MOVING_BLOCK_X ? "x" : "y";
    this.phase = slotPhase(resolved.entity.slot);
  }

  obstacle(): Obstacle {
    return { kind: "block", box: this.box() };
  }

  update(frameCounter: number, obstacles: Obstacle[], bounds: RoomBound): void {
    const coord = this.axis === "x" ? this.gridX : this.gridY;
    // `ld a,(ix+grid) / add a,#08 / and #0F` : la position est repliée sur 16
    // unités avant comparaison, ce qui rend le mouvement local -- le bloc
    // oscille dans sa case, il ne traverse pas la salle.
    const current = (coord + 8) & 0x0f;
    const target = targetForFrame(frameCounter, this.phase);
    if (current === target) return;

    // `ld a,#01 / jr c / neg` : un pas de ±1 vers la cible. PAS ±3 comme le
    // joueur -- ces blocs sont lents, et c'est ce qui les rend franchissables.
    const wanted = current < target ? 1 : -1;
    const clamped = clampDeltaToRoom(
      coord,
      wanted,
      this.axis === "x" ? this.halfX : this.halfY,
      this.axis === "x" ? bounds.x : bounds.y,
    );
    const res = resolveAxis(this.box(), clamped, this.axis, obstacles);
    if (this.axis === "x") this.gridX += res.delta;
    else this.gridY += res.delta;

    // Aucun mouvement vertical : la routine écrit `ld (ix+0B),#01`, ce qui
    // donne 0 après le décrément de prélude de `RST 10`. C'est une neutralisation
    // DÉLIBÉRÉE de la gravité générique, pas une absence de code.
  }
}

/**
 * Cube qui s'enfonce 0x5B -- une plaque de pression.
 *
 * DEUX FAITS QUI SE RÉPONDENT, et qui ont mis longtemps à se rejoindre :
 *
 * - `fn_sinking_cube_logic` (#0F67) ne descend que si le bit 3 de
 *   `state_flags_2` est posé, et le consomme aussitôt (`res 3`). La descente
 *   elle-même est l'effet de bord du prélude de `RST 10` : la routine écrit
 *   `(ix+0B) = 0` juste avant, le prélude décrémente, l'octet vaut -1 quand la
 *   primitive le relit comme composante Z. Une unité par déclenchement.
 * - le POSEUR de ce bit est `fn_entity_collide_axis_z` (#24EA), qui fait
 *   `set 3,(iy+off_state_flags_2)` sur ce SUR QUOI on repose. Autrement dit :
 *   « quelque chose s'est posé sur moi ».
 *
 * Le cube s'enfonce donc tant qu'on lui reste dessus, d'une unité par tick, et
 * ne remonte jamais -- aucune ligne de code ne restaure `grid_z`. Seule la
 * réinitialisation de la salle le remet en place.
 */
export class SinkingCube extends BlockBody {
  /** Bit 3 de `state_flags_2`, posé par ce qui repose dessus. */
  private triggered = false;

  obstacle(): Obstacle {
    return { kind: "block", box: this.box(), standTarget: this };
  }

  /** `set 3,(iy+off_state_flags_2)` : quelque chose vient de se poser dessus. */
  onStoodOn(): void {
    this.triggered = true;
  }

  update(obstacles: Obstacle[], bounds: RoomBound): void {
    if (!this.triggered) return;
    this.triggered = false; // `res 3` -- consommé, il faudra le reposer au tick suivant

    const delta = clampDeltaToFloor(this.gridZ, -1, bounds.z);
    const res = resolveAxis(this.box(), delta, "z", obstacles);
    this.gridZ += res.delta;
  }
}

export interface AutonomousBlocks {
  moving: MovingBlock[];
  sinking: SinkingCube[];
}

export function createAutonomousBlocks(entities: ResolvedEntity[]): AutonomousBlocks {
  const moving: MovingBlock[] = [];
  const sinking: SinkingCube[] = [];
  for (const resolved of entities) {
    const box = entityBox(resolved.entity, BLOCK_HALF_EXTENT, BLOCK_HALF_EXTENT, BLOCK_HEIGHT);
    const dims = [
      (box.maxX - box.minX) / 2,
      (box.maxY - box.minY) / 2,
      box.maxZ - box.minZ,
    ] as const;
    if (resolved.entity.type === SINKING_CUBE) {
      sinking.push(new SinkingCube(resolved, ...dims));
    } else {
      moving.push(new MovingBlock(resolved, ...dims));
    }
  }
  return { moving, sinking };
}

export function autonomousBlockObstacles(blocks: AutonomousBlocks): Obstacle[] {
  return [
    ...blocks.moving.map((b) => b.obstacle()),
    ...blocks.sinking.map((b) => b.obstacle()),
  ];
}

/**
 * Avance les blocs autonomes d'un tick.
 *
 * Les cubes APRÈS les blocs mobiles, et surtout après le joueur : le bit
 * « on me marche dessus » est posé pendant la résolution des autres entités,
 * et le cube ne fait que le consommer à son tour -- exactement l'ordre de la
 * boucle principale, qui dispatche ses slots en ordre croissant.
 */
export function updateAutonomousBlocks(
  blocks: AutonomousBlocks,
  frameCounter: number,
  obstacles: Obstacle[],
  bounds: RoomBound,
): void {
  for (const block of blocks.moving) block.update(frameCounter, obstacles, bounds);
  for (const cube of blocks.sinking) cube.update(obstacles, bounds);
}

export function autonomousBlockDrawCalls(blocks: AutonomousBlocks, view: ViewAngle): SpriteDrawCall[] {
  return [
    ...blocks.moving.map((b) => b.drawCall(view)),
    ...blocks.sinking.map((b) => b.drawCall(view)),
  ];
}
