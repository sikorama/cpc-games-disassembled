// Corps mobiles poussables d'une salle -- table (0x54), coffre (0x55), bloc
// (0x3E). Modélisés comme de VRAIES entités vivantes : ils portent leur
// position et leur vecteur en attente, fournissent leur obstacle à cette
// position courante, et sont redessinés chaque frame -- par opposition au
// décor statique de scene/room.ts, figé à sa position de manifest.
//
// FAIT ROM CENTRAL : la poussée n'est pas un cas particulier codé dans la
// logique du joueur, c'est une propriété du MOUVEMENT. Le scan de collision par
// axe partagé par toutes les entités mobiles (fn_entity_collide_axis_x/_y,
// #244C/#249B, asm/code/doors_and_player_logic.asm:895-990) recopie le vecteur
// en attente du mobile dans celui de l'entité heurtée dès que celle-ci porte le
// bit 2 de `flags`. Voir physics/solidTypes.ts pour le détail du bit et des
// trois politiques de vecteur.
//
// Conséquences directes sur la forme de ce module :
//
// - le joueur ET le garde poussent, sans que ni l'un ni l'autre ne connaisse
//   les types poussables : ils se contentent de rendre le vecteur à l'obstacle
//   qui les a bloqués (physics/obstacles.ts, `PushTarget`) ;
// - un corps poussé pousse à son tour ce qu'il heurte -- c'est le même scan.
//   Salle 0x6C (8 coffres alignés) et salle 0x34 (8 tables) sont les cas où ça
//   se voit ;
// - le pousseur est arrêté par ce qu'il pousse dans le MÊME tick (la ROM rogne
//   son propre delta jusqu'à ce qu'il tienne, fn_step_toward_zero #233B) et ne
//   le suit qu'au tick suivant. Ce retard d'un tick est le ressenti d'origine,
//   pas une latence à rattraper.

import type { Box3 } from "../physics/aabb";
import { resolveAxis } from "../physics/aabb";
import { BLOCK_HALF_EXTENT, BLOCK_HEIGHT, entityBox, type Obstacle } from "../physics/obstacles";
import { pushPolicyFor, type PushPolicy } from "../physics/solidTypes";
import type { SpriteDrawCall } from "../gl/spriteBatch";
import type { ViewAngle } from "../render/isoMath";
import { entityDrawCall, type ResolvedEntity } from "./room";
import { clampDeltaToRoom, clampDeltaToFloor, type RoomBound } from "../physics/roomBounds";

export class PushableBody {
  gridX: number;
  gridY: number;
  gridZ: number;

  /** Vecteur en attente, en unités de grille (`+0x09`/`+0x0A` de la structure
   * d'entité). Écrit par le pousseur, consommé par ce corps à son tick. */
  pendingX = 0;
  pendingY = 0;
  /** Compteur vertical (`+0x0B`). C'est LUI la gravité : aucune des trois
   * routines poussables n'écrit ce champ, et le prélude de `RST 10`
   * (`dec (ix+0B)`, #0010) le décrémente à chaque tick avant que la primitive
   * ne l'applique comme composante Z. La chute ACCÉLÈRE donc d'une unité par
   * tick, sans vitesse terminale -- contrairement au joueur, dont
   * `fn_player_gravity_and_door_dispatch` fait converger ce même champ. */
  pendingZ = 0;

  constructor(
    readonly resolved: ResolvedEntity,
    readonly policy: PushPolicy,
    readonly halfX: number,
    readonly halfY: number,
    private readonly height: number,
  ) {
    this.gridX = resolved.entity.gridX;
    this.gridY = resolved.entity.gridY;
    this.gridZ = resolved.entity.gridZ;
  }

  /**
   * Reçoit le vecteur d'un mobile qui vient d'être bloqué par ce corps
   * (physics/obstacles.ts, `PushTarget`).
   *
   * `delta` est le pas ENTIER voulu par le pousseur, pas le reliquat autorisé :
   * la ROM recopie `(ix+09)`, l'octet de la structure, qui n'est réécrit avec
   * la valeur rognée qu'à la toute fin de la résolution (#23F7, loc_243E).
   * Une poussée transmet donc toujours un pas plein, même quand le pousseur,
   * lui, n'avance pas du tout ce tick.
   */
  receivePush(axis: "x" | "y", delta: number): void {
    if (axis === "x") this.pendingX = delta;
    else this.pendingY = delta;
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

  obstacle(): Obstacle {
    return { kind: "block", box: this.box(), pushTarget: this };
  }

  drawCall(view: ViewAngle): SpriteDrawCall {
    return entityDrawCall(this.resolved, this.gridX, this.gridY, this.gridZ, view);
  }
}

/** Construit les corps mobiles d'une salle depuis ses entités résolues
 * (scene/room.ts `getMovableEntities()`). Les demi-étendues viennent de la
 * vraie bbox quand elle est connue, sinon du même repli que le décor
 * (physics/obstacles.ts) -- une table et un bloc statique ont le même
 * footprint, il n'y a pas de raison d'en inventer un second. */
export function createPushables(movables: ResolvedEntity[]): PushableBody[] {
  const bodies: PushableBody[] = [];
  for (const resolved of movables) {
    const policy = pushPolicyFor(resolved.entity.type, resolved.entity.flags);
    if (policy === null) continue; // ne devrait pas arriver : c'est le critère de sélection
    const box = entityBox(resolved.entity, BLOCK_HALF_EXTENT, BLOCK_HALF_EXTENT, BLOCK_HEIGHT);
    bodies.push(
      new PushableBody(
        resolved,
        policy,
        (box.maxX - box.minX) / 2,
        (box.maxY - box.minY) / 2,
        box.maxZ - box.minZ,
      ),
    );
  }
  return bodies;
}

export function pushableObstacles(bodies: PushableBody[]): Obstacle[] {
  return bodies.map((body) => body.obstacle());
}

/**
 * Avance les corps mobiles d'UN tick, après le joueur et les gardes -- l'ordre
 * de la ROM : `fn_main_loop` dispatche les slots en ordre croissant et le joueur
 * est le slot 0 (asm/code/low_ram_and_boot.asm:224-252), donc les poussées d'un
 * tick sont écrites avant que les corps ne jouent le leur.
 *
 * Cet ordre n'est pas un détail de style : c'est lui qui rend le bloc 0x3E
 * immobile (sa routine efface son vecteur AVANT de l'appliquer), et le laisser
 * dériver changerait un comportement de jeu. Voir physics/solidTypes.ts.
 */
export function updatePushables(
  bodies: PushableBody[],
  staticObstacles: Obstacle[],
  bounds: RoomBound,
): void {
  for (const body of bodies) {
    if (body.policy === "clear-then-apply") {
      // fn_pushable_block_logic (#1D53) : CALL #22A5 puis RST 10.
      body.pendingX = 0;
      body.pendingY = 0;
    }

    // PLUS D'ARRÊT ANTICIPÉ SUR UN VECTEUR NUL. La primitive de déplacement
    // tourne à chaque tick, vecteur horizontal ou pas : c'est elle qui fait
    // tomber. Sortir tôt ici, c'est supprimer la gravité.

    // Les AUTRES corps sont des obstacles à leur position courante -- et des
    // cibles de poussée, comme pour le joueur : le scan par axe de la ROM est
    // le même quel que soit le mobile.
    const obstacles = staticObstacles.concat(
      bodies.filter((other) => other !== body).map((other) => other.obstacle()),
    );

    // PRÉLUDE DE `RST 10` : `dec (ix+0B)`, inconditionnel, avant tout le reste
    // (asm/code/low_ram_and_boot.asm, vecteur RST 10). C'est la seule source de
    // gravité de ces corps.
    body.pendingZ -= 1;

    // AXE Z EN PREMIER, puis X, puis Y -- l'ordre de
    // fn_entity_movement_vector_resolve (#23F7), pas un choix du portage.
    //
    // Le plancher vient de fn_entity_clamp_pending_z (#230C), qui compare
    // `grid_z + delta` à `var_room_data_field_2` : un PLANCHER simple à 0x80,
    // et non la formule centrée des axes X/Y. Les trois calibrations de salle
    // donnent toutes 0x80, mais on lit quand même la valeur de la salle plutôt
    // que d'écrire la constante -- c'est la même donnée que les bornes X/Y.
    const floorLimited = clampDeltaToFloor(body.gridZ, body.pendingZ, bounds.z);
    const zRes = resolveAxis(body.box(), floorLimited, "z", obstacles);
    body.gridZ += zRes.delta;

    // PORTÉ PAR CE SUR QUOI ON REPOSE. `fn_entity_collide_axis_z` (#24EA), une
    // fois le chevauchement constaté, fait hériter au mobile le vecteur en
    // attente de son SUPPORT -- mais seulement sur les axes où le sien est
    // encore nul (`ld a,(ix+09) / and a / jr nz`), pour ne pas écraser une
    // poussée qu'il aurait déjà reçue. C'est ce qui fait qu'une pile poussée
    // avance d'un bloc au lieu de se défaire.
    if (zRes.blocked && zRes.delta <= 0) zRes.blocker?.standTarget?.onStoodOn();
    const support = zRes.blocked && zRes.delta <= 0 ? zRes.blocker?.pushTarget : undefined;
    if (support) {
      if (body.pendingX === 0) body.pendingX = support.pendingX;
      if (body.pendingY === 0) body.pendingY = support.pendingY;
    }

    // Le compteur vertical est réécrit ROGNÉ (`ld (ix+0B),h` en loc_243E) :
    // posé sur quelque chose, il retombe à 0, et le prélude du tick suivant le
    // remet à -1 -- une sonde d'une unité par tick, exactement comme la ROM.
    // C'est aussi ce qui remet la chute à zéro à l'atterrissage plutôt que de
    // laisser l'accélération s'accumuler pendant le repos.
    body.pendingZ = zRes.delta;

    // LIMITE DE SALLE, appliquée AVANT le scan de collision solide -- c'est
    // l'ordre de la ROM, où fn_entity_clamp_pending_x/_y sont appelées par
    // fn_entity_movement_vector_resolve en amont du scan. Sans ça, un corps
    // poussé vers un côté SANS MUR (les salles n'en ont que sur deux côtés)
    // sort de la pièce et de l'écran -- constaté salle 0xB4.
    const clampedX = clampDeltaToRoom(body.gridX, body.pendingX, body.halfX, bounds.x);
    const clampedY = clampDeltaToRoom(body.gridY, body.pendingY, body.halfY, bounds.y);

    // Même ordre d'axes que la ROM (X puis Y, l'axe Z ne bougeant pas ici),
    // en reconstruisant la boîte entre les deux pour que Y voie déjà l'effet
    // de X.
    //
    // La poussée transmise reste le vecteur d'ORIGINE et non le vecteur
    // clampé : la ROM recopie `(ix+09)`, l'octet de structure, qui n'est
    // réécrit avec la valeur rognée qu'en toute fin de résolution (loc_243E).
    // Un coffre bloqué par le bord transmet donc quand même un pas plein à ce
    // qu'il touche.
    const xRes = resolveAxis(body.box(), clampedX, "x", obstacles);
    xRes.blocker?.pushTarget?.receivePush("x", body.pendingX);
    body.gridX += xRes.delta;

    const yRes = resolveAxis(body.box(), clampedY, "y", obstacles);
    yRes.blocker?.pushTarget?.receivePush("y", body.pendingY);
    body.gridY += yRes.delta;

    if (body.policy === "apply-then-clear") {
      // fn_pushable_table_logic (#1D71) : RST 10 puis CALL #22A5. La table
      // exige un contact à chaque tick pour avancer -- elle s'arrête net dès
      // que le joueur cesse de pousser.
      body.pendingX = 0;
      body.pendingY = 0;
    } else {
      // fn_sliding_chest_logic (#1D66) : pas de CALL #22A5, le vecteur
      // persiste et le coffre continue de glisser tout seul. On garde le
      // delta REELLEMENT autorisé, ce qui reproduit fn_step_toward_zero :
      // contre un mur il tombe à 0 et le coffre s'immobilise -- « poussés
      // jusqu'au mur, puis parfaitement stables ».
      body.pendingX = xRes.delta;
      body.pendingY = yRes.delta;
    }
  }
}

export function pushableDrawCalls(bodies: PushableBody[], view: ViewAngle): SpriteDrawCall[] {
  return bodies.map((body) => body.drawCall(view));
}
