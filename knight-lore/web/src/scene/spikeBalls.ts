// Boules à pics du plafond (type 0x3F) -- `fn_ceiling_spike_ball_logic` (#1092).
//
// Un piège à DEUX ÉTATS seulement, et le second est une chute libre. Au repos
// la boule pend au plafond sans rien faire ; armée, elle tombe jusqu'à ce
// qu'elle heurte quelque chose, puis se désarme sur place.
//
// LA CHUTE EST LA GRAVITÉ GÉNÉRIQUE, PAS UN MOUVEMENT PROPRE. La queue de la
// routine (#10AF) fait `rst #10` sans JAMAIS écrire `(ix+0B)` : le
// `dec (ix+0B)` du prélude s'accumule d'un tick à l'autre, donc la chute
// accélère d'une unité par tick, sans vitesse terminale. C'est mot pour mot le
// mécanisme des corps poussables (scene/pushables.ts), et l'exact complément
// des deux routines qui écrivent ce champ pour choisir leur sort -- le cube
// 0x5B écrit 0 (donc -1, il descend), le bloc mobile écrit 1 (donc 0, il ne
// bouge pas verticalement). Lire une ABSENCE d'instruction est ce qui distingue
// les trois cas.
//
// LA BOULE NE REMONTE JAMAIS. La routine ne restaure pas `grid_z` : une fois
// tombée, elle reste au sol. C'est la ré-instanciation de la salle qui la
// remet au plafond -- d'où l'impression, en jeu, qu'elles « tombent quand on
// entre dans une pièce ».

import type { Box3 } from "../physics/aabb";
import { resolveAxis } from "../physics/aabb";
import type { Obstacle } from "../physics/obstacles";
import { entityBox, BLOCK_HALF_EXTENT, BLOCK_HEIGHT } from "../physics/obstacles";
import { clampDeltaToFloor, type RoomBound } from "../physics/roomBounds";
import { gameplayRng } from "../game/random";
import type { SpriteDrawCall } from "../gl/spriteBatch";
import type { ViewAngle } from "../render/isoMath";
import { entityDrawCall, type ResolvedEntity } from "./room";

/** Type ROM de la boule à pics au plafond. */
export const SPIKE_BALL_TYPE = 0x3f;

/**
 * Seuil d'armement : `ld a,(var_pseudo_random_acc) / cp #10 / ret nc`, donc la
 * boule ne s'arme que si l'octet tiré est **strictement inférieur à 0x10** --
 * environ 1 chance sur 16 par tick. Ce n'est pas un délai fixe : c'est ce qui
 * fait qu'on ne peut pas apprendre le moment de la chute.
 */
const ARM_THRESHOLD = 0x10;

export class SpikeBall {
  gridX: number;
  gridY: number;
  gridZ: number;

  /** Compteur vertical (`+0x0B`). Nul au repos ; en chute, décrémenté d'une
   * unité par tick par le prélude de `RST 10` et jamais réécrit par la
   * routine -- d'où l'accélération. */
  pendingZ = 0;

  /** `bit 2 de state_flags_2` : la boule est armée, donc en train de tomber. */
  falling = false;

  constructor(
    readonly resolved: ResolvedEntity,
    private readonly halfX: number,
    private readonly halfY: number,
    private readonly height: number,
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

  /** La boule est une entité du tableau des 40 slots comme une autre : le scan
   * de collision générique la voit. Elle n'est PAS une cible de poussée (elle
   * ne porte pas le bit 2 de `flags` -- vérifié sur les 112 instances). */
  obstacle(): Obstacle {
    return { kind: "block", box: this.box() };
  }

  drawCall(view: ViewAngle): SpriteDrawCall {
    return entityDrawCall(this.resolved, this.gridX, this.gridY, this.gridZ, view);
  }
}

/** Construit les boules d'une salle depuis ses entités résolues. */
export function createSpikeBalls(entities: ResolvedEntity[]): SpikeBall[] {
  return entities.map((resolved) => {
    const box = entityBox(resolved.entity, BLOCK_HALF_EXTENT, BLOCK_HALF_EXTENT, BLOCK_HEIGHT);
    return new SpikeBall(
      resolved,
      (box.maxX - box.minX) / 2,
      (box.maxY - box.minY) / 2,
      box.maxZ - box.minZ,
    );
  });
}

export function spikeBallObstacles(balls: SpikeBall[]): Obstacle[] {
  return balls.map((ball) => ball.obstacle());
}

/**
 * Avance les boules d'un tick.
 *
 * VERROU PAR SALLE : `var_room_reset_flag_4` empêche une deuxième boule de
 * s'armer tant qu'une autre tombe -- une seule à la fois par pièce, fait établi
 * de longue date (`notes/2026-08-07-entity-logic-ceiling-spikes.md`) et relu
 * dans le code. Il est posé à l'armement et libéré à l'impact. On le modélise
 * ici par « une boule est-elle déjà en chute ? », strictement équivalent
 * puisque la ROM pose et libère le drapeau exactement aux deux mêmes instants,
 * et sans variable de salle à faire vivre en plus.
 *
 * DEUX PASSES, LÀ OÙ LA ROM EN FAIT UNE. La boucle principale du jeu dispatche
 * ses 40 slots l'un après l'autre : chute et tentative d'armement y sont donc
 * entrelacées, et une boule située plus loin dans la table PEUT s'armer dans la
 * frame même où une autre a atterri. Ici on fait tomber d'abord, on arme
 * ensuite. La différence ne porte que sur le slot qui obtient le tour dans
 * cette frame précise -- inobservable, puisque le choix est de toute façon
 * tiré au hasard -- et elle évite de faire dépendre le comportement de l'ordre
 * du tableau. À ne pas « corriger » en croyant y gagner en fidélité : ce serait
 * échanger une différence invisible contre une dépendance à un ordre que le
 * portage ne garantit pas.
 */
export function updateSpikeBalls(balls: SpikeBall[], obstacles: Obstacle[], bounds: RoomBound): void {
  for (const ball of balls) {
    if (!ball.falling) continue;

    // Prélude de `RST 10`, inconditionnel.
    ball.pendingZ -= 1;

    // Plancher de salle (fn_entity_clamp_pending_z, #230C) puis collision
    // solide -- le même enchaînement que pour tout le reste.
    //
    // ATTEINDRE LE PLANCHER COMPTE COMME UN IMPACT : le clamp de la ROM pose le
    // MÊME bit de collision que le scan solide. Une boule tombée dans le vide
    // doit donc se désarmer en touchant le sol -- sans ça elle reste « en
    // chute » indéfiniment et garde le verrou de salle, ce qui empêche toutes
    // les autres de tomber (bug attrapé au test).
    const floorLimited = clampDeltaToFloor(ball.gridZ, ball.pendingZ, bounds.z);
    const hitFloor = floorLimited !== ball.pendingZ;
    const others = obstacles.concat(
      balls.filter((o) => o !== ball).map((o) => o.obstacle()),
    );
    const res = resolveAxis(ball.box(), floorLimited, "z", others);
    ball.gridZ += res.delta;
    ball.pendingZ = res.delta;

    // IMPACT : `bit 2,(ix+off_cooldown_or_collision_flags)` -> `res 2` et
    // libération du verrou. La boule reste où elle est tombée ; rien ne la
    // remonte, seule la ré-entrée dans la salle la replace.
    if (res.blocked || hitFloor) {
      ball.falling = false;
      ball.pendingZ = 0;
    }
  }

  if (balls.some((ball) => ball.falling)) return; // verrou de salle pris

  for (const ball of balls) {
    if (gameplayRng.nextByte() < ARM_THRESHOLD) {
      ball.falling = true;
      return; // le verrou n'autorise qu'un seul armement
    }
  }
}

export function spikeBallDrawCalls(balls: SpikeBall[], view: ViewAngle): SpriteDrawCall[] {
  return balls.map((ball) => ball.drawCall(view));
}
