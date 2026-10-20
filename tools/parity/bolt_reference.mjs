// Movement parity reference. Runs the ORIGINAL web build's movement formulas (copied from
// reference/bs_web/index.html updatePlayer/dash/slide/slam, flat ground at y = hy, no walls) through a set
// of standard moves at a fixed 60 Hz, and writes tests/data/bolt_parity.json. The GDScript test
// tests/unit/test_bolt_parity.gd runs the same moves through BoltMotor and must match within tolerance.
// Usage: node tools/parity/bolt_reference.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const CONFIG = JSON.parse(fs.readFileSync(path.join(root, "data/bs_source/CONFIG.json"), "utf8"));
const lerp = (a, b, t) => a + (b - a) * t;
const damp = (rate, dt) => 1 - Math.exp(-rate * dt);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const DT = 1 / 60;
const HY = 0.95;

function fresh() {
  return { pos: { x: 0, y: HY, z: 0 }, vel: { x: 0, y: 0, z: 0 }, onGround: true, jumps: 0, jumpBuffer: 0, coyote: 0,
    hover: 1, hovering: false, airT: 0, dashT: 0, dashCd: 0, dashDir: { x: 0, z: 1 }, airDashUsed: false,
    slam: null, slamKind: "std", slamFlipT: 0, slamBounceT: 0, slideT: 0, slideCd: 0, slideLow: false,
    slideDir: { x: 0, z: 1 }, hy: HY, yaw: 0, fallPeak: HY };
}

// ---- original logic (updatePlayer 3366+, dash 3131, startSlide 3273, updateSlide 3298, slideLongJump 3321, startSlam 3170)
function dash(P, dir) {
  const D = CONFIG.dash;
  if (P.dashCd > 0 || P.slam) return;
  if (!P.onGround && P.airDashUsed) return;
  if (!P.onGround) P.airDashUsed = true;
  if (P.slideLow) { P.slideLow = false; P.hy = 0.95; P.pos.y += 0.95 - CONFIG.slide.hy; P.slideT = 0; }
  P.dashDir = dir;
  P.dashT = D.time; P.dashCd = D.cooldown;
}
function startSlide(P, dir) {
  const S = CONFIG.slide;
  if (P.slideT > 0 || P.slideLow || P.slideCd > 0 || !P.onGround || P.dashT > 0) return;
  if (Math.hypot(P.vel.x, P.vel.z) < CONFIG.move.walk * 0.9) return;
  P.slideDir = dir;
  P.slideT = S.time; P.slideCd = S.cooldown;
  P.slideLow = true; P.hy = S.hy; P.pos.y -= 0.95 - S.hy;
}
function startSlam(P, kind) {
  if (P.slam || P.onGround) return;
  P.slam = kind === "super" ? "hang" : "flip";
  P.slamKind = kind;
  P.slamFlipT = kind === "super" ? CONFIG.slam.superHang : CONFIG.slam.flipTime;
  P.dashT = 0;
}
function step(P, inp) {
  const dt = DT;
  P.dashCd -= dt; P.slideCd -= dt; P.jumpBuffer -= dt; P.coyote -= dt; P.slamBounceT -= dt;
  P.airT = P.onGround ? 0 : P.airT + dt;
  P.hovering = false;
  const M = CONFIG.move, J = CONFIG.jump;
  const dir = inp.dir || { x: 0, z: 0 };
  const dl = Math.hypot(dir.x, dir.z);
  const hasInput = dl * dl > 0.01;
  const sprint = !!inp.sprint || dl > 0.93;
  const speed = sprint ? M.sprint : M.walk;
  const hSpd = Math.hypot(P.vel.x, P.vel.z);
  if (P.dashT > 0) {
    P.dashT -= dt;
    P.vel.x = P.dashDir.x * CONFIG.dash.speed; P.vel.z = P.dashDir.z * CONFIG.dash.speed; P.vel.y = 0;
  } else if (P.slideT > 0 || P.slideLow) {
    const S = CONFIG.slide;
    P.slideT -= dt;
    const k = clamp(P.slideT / S.time, 0, 1);
    const spd = lerp(7.5, S.speed, k);
    P.vel.x = P.slideDir.x * spd; P.vel.z = P.slideDir.z * spd;
    if (P.slideT <= 0 && !(inp.crouchHeld && P.slideT > -1.5)) { P.slideLow = false; P.hy = 0.95; P.pos.y += 0.95 - S.hy; P.slideT = 0; }
  } else if (P.slam) {
    P.vel.x *= 1 - Math.min(1, dt * 8); P.vel.z *= 1 - Math.min(1, dt * 8);
  } else {
    let rate;
    if (hasInput) {
      rate = P.onGround ? M.accel : M.airAccel;
      const reversing = (P.vel.x * dir.x + P.vel.z * dir.z) < 0;
      if (P.onGround && hSpd < M.snapTurnSpeed) rate *= 3;
      else if (P.onGround && sprint && reversing) rate *= M.sprintCarry;
    } else rate = P.onGround ? M.decel : M.airDecel;
    let tx = dir.x * speed, tz = dir.z * speed;
    if (!P.onGround && hasInput && hSpd > speed) {
      const along = P.vel.x * dir.x + P.vel.z * dir.z;
      if (along > 0) { tx = dir.x * hSpd; tz = dir.z * hSpd; }
    }
    P.vel.x = lerp(P.vel.x, tx, damp(rate, dt));
    P.vel.z = lerp(P.vel.z, tz, damp(rate, dt));
  }
  if (P.slam === "flip") { P.vel.y = 0; P.slamFlipT -= dt; if (P.slamFlipT <= 0) P.slam = "fall"; }
  else if (P.slam === "hang") { P.vel.y = -1.4; P.slamFlipT -= dt; if (P.slamFlipT <= 0) P.slam = "fall"; }
  else if (P.slam === "fall") { P.vel.y = -(P.slamKind === "super" ? CONFIG.slam.superFall : CONFIG.slam.fallSpeed); }
  else if (P.dashT > 0) { /* suspended */ }
  else {
    let g = (P.vel.y > 0 ? (inp.jumpHeld ? J.riseGrav : J.cutGrav) : J.fallGrav);
    if (!P.onGround && Math.abs(P.vel.y) < 1.6 && inp.jumpHeld) g *= J.apexGrav;
    P.vel.y = Math.max(-J.maxFall, P.vel.y - g * dt);
  }
  if (!P.onGround && !P.slam && P.dashT <= 0 && inp.jumpHeld && P.jumpBuffer <= 0 && P.vel.y < CONFIG.hover.engageBelow && P.hover > 0) {
    P.vel.y += (CONFIG.hover.thrust - P.vel.y) * Math.min(1, dt * 6);
    P.hover = Math.max(0, P.hover - dt / CONFIG.hover.drainTime);
    P.hovering = true;
  }
  if (P.jumpBuffer > 0 && !P.slam) {
    if (P.dashT > 0) {
      const DJ = CONFIG.dashJump, dS = CONFIG.dash.speed * DJ.hMul;
      P.vel.x = P.dashDir.x * dS; P.vel.z = P.dashDir.z * dS; P.vel.y = DJ.v;
      P.dashT = 0; P.jumpBuffer = 0; P.coyote = 0; P.jumps = P.onGround ? 1 : 2;
    } else if (P.slideT > 0 || P.slideLow) {
      const S = CONFIG.slide;
      P.jumpBuffer = 0; P.slideLow = false; P.hy = 0.95; P.pos.y += 0.95 - S.hy; P.slideT = 0;
      P.vel.x = P.slideDir.x * S.longJumpH; P.vel.z = P.slideDir.z * S.longJumpH; P.vel.y = S.longJumpV;
      P.jumps = 1; P.coyote = 0;
    } else if (P.onGround && P.slamBounceT > 0) {
      const SB = CONFIG.slamBounce;
      P.vel.y = P.slamKind === "super" ? SB.superV : SB.v;
      P.jumps = 1; P.coyote = 0; P.jumpBuffer = 0; P.slamBounceT = 0;
    } else if (P.onGround || P.coyote > 0) {
      P.vel.y = J.vel; P.jumps = 1; P.coyote = 0; P.jumpBuffer = 0;
      if (sprint && hSpd > M.walk) { P.vel.x *= M.sprintJumpBoost; P.vel.z *= M.sprintJumpBoost; }
    } else if (P.jumps < 2) {
      P.vel.y = J.doubleVel; P.jumps = 2; P.jumpBuffer = 0; P.dashT = 0;
    }
  }
  // movePlayer on a flat floor whose surface is y = 0 (body centre y = hy when standing)
  P.onGround = false;
  P.pos.x += P.vel.x * dt; P.pos.z += P.vel.z * dt; P.pos.y += P.vel.y * dt;
  if (P.pos.y - P.hy <= 0) { P.pos.y = P.hy; if (P.vel.y < 0) P.vel.y = 0; P.onGround = true; }
  if (P.onGround) {
    if (P.slam) { P.slam = null; P.slamBounceT = CONFIG.slamBounce.window; P.jumpBuffer = Math.min(P.jumpBuffer, 0); }
    P.jumps = 0; P.coyote = J.coyote; P.airDashUsed = false;
    P.hover = Math.min(1, P.hover + dt * CONFIG.hover.regen);
  }
}

// ---- scenarios: each returns metrics. A scenario is a script of per-frame inputs.
// Every scenario is described as data so the GDScript test can run the identical script.
const SCENARIOS = [
  { id: "jump_full", frames: 150, script: [{ at: 0, press: "jump" }, { from: 0, to: 150, hold: "jump" }] },
  { id: "jump_tap", frames: 120, script: [{ at: 0, press: "jump" }, { from: 0, to: 6, hold: "jump" }] },
  { id: "double_jump", frames: 200, script: [{ at: 0, press: "jump" }, { at: 30, press: "jump" }, { from: 0, to: 200, hold: "jump" }] },
  { id: "hover", frames: 260, script: [{ at: 0, press: "jump" }, { at: 30, press: "jump" }, { from: 0, to: 260, hold: "jump" }] },
  { id: "walk_accel", frames: 60, script: [{ from: 0, to: 60, dir: [0, 1] }] },
  { id: "sprint_accel", frames: 90, script: [{ from: 0, to: 90, dir: [0, 1], sprint: true }] },
  { id: "dash_ground", frames: 40, script: [{ at: 0, dash: [1, 0] }] },
  { id: "dash_jump", frames: 120, script: [{ at: 0, dash: [1, 0] }, { at: 4, press: "jump" }, { from: 4, to: 120, hold: "jump" }] },
  { id: "slide", frames: 80, script: [{ from: 0, to: 80, dir: [0, 1], sprint: true }, { at: 40, slide: [0, 1] }] },
  { id: "long_jump", frames: 140, script: [{ from: 0, to: 140, dir: [0, 1], sprint: true }, { at: 40, slide: [0, 1] }, { at: 46, press: "jump" }] },
  { id: "slam", frames: 200, script: [{ at: 0, press: "jump" }, { at: 30, press: "jump" }, { from: 0, to: 45, hold: "jump" }, { at: 45, slam: "std" }] },
  { id: "slam_bounce", frames: 220, script: [{ at: 0, press: "jump" }, { at: 30, press: "jump" }, { from: 0, to: 45, hold: "jump" }, { at: 45, slam: "std" }, { from: 46, to: 220, pressEachGroundFrame: true, hold: "jump" }] },
  { id: "sprint_jump", frames: 140, script: [{ from: 0, to: 140, dir: [0, 1], sprint: true }, { at: 50, press: "jump" }, { from: 50, to: 140, hold: "jump" }] },
];

export function inputsAt(sc, f, P) {
  const inp = { dir: { x: 0, z: 0 }, jumpHeld: false, sprint: false, crouchHeld: false, press: false, dash: null, slide: null, slam: null };
  for (const s of sc.script) {
    const active = s.at !== undefined ? s.at === f : (f >= s.from && f < s.to);
    if (!active) continue;
    if (s.press === "jump") inp.press = true;
    if (s.hold === "jump") inp.jumpHeld = true;
    if (s.dir) inp.dir = { x: s.dir[0], z: s.dir[1] };
    if (s.sprint) inp.sprint = true;
    if (s.dash) inp.dash = { x: s.dash[0], z: s.dash[1] };
    if (s.slide) inp.slide = { x: s.slide[0], z: s.slide[1] };
    if (s.slam) inp.slam = s.slam;
    if (s.pressEachGroundFrame && P.onGround && P.slamBounceT > 0) inp.press = true;
  }
  return inp;
}

function run(sc) {
  const P = fresh();
  let apex = P.pos.y - HY, airFrames = 0, firstLand = -1, leftGround = -1, maxSpeed = 0, t95 = -1;
  const trace = [];
  for (let f = 0; f < sc.frames; f++) {
    const inp = inputsAt(sc, f, P);
    if (inp.press) P.jumpBuffer = CONFIG.jump.buffer;
    if (inp.dash) dash(P, inp.dash);
    if (inp.slide) startSlide(P, inp.slide);
    if (inp.slam) startSlam(P, inp.slam);
    step(P, inp);
    const feet = P.pos.y - P.hy;
    apex = Math.max(apex, feet);
    if (!P.onGround) { airFrames++; if (leftGround < 0) leftGround = f; }
    if (P.onGround && leftGround >= 0 && firstLand < 0) firstLand = f;
    const hs = Math.hypot(P.vel.x, P.vel.z);
    maxSpeed = Math.max(maxSpeed, hs);
    if (t95 < 0 && hs >= 0.95 * (sc.id === "sprint_accel" ? CONFIG.move.sprint : CONFIG.move.walk)) t95 = f;
    if (f % 5 === 4) trace.push([+P.pos.x.toFixed(4), +feet.toFixed(4), +P.pos.z.toFixed(4)]);
  }
  return { apex: +apex.toFixed(4), air_frames: airFrames, first_land: firstLand, max_speed: +maxSpeed.toFixed(4),
    t95_frame: t95, end: [+P.pos.x.toFixed(4), +(P.pos.y - P.hy).toFixed(4), +P.pos.z.toFixed(4)], trace };
}

const out = { _doc: "Generated by tools/parity/bolt_reference.mjs from the original CONFIG and formulas. Do not edit by hand.", dt: DT, scenarios: {} };
for (const sc of SCENARIOS) out.scenarios[sc.id] = { script: sc.script, frames: sc.frames, expect: run(sc) };
fs.mkdirSync(path.join(root, "tests/data"), { recursive: true });
fs.writeFileSync(path.join(root, "tests/data/bolt_parity.json"), JSON.stringify(out, null, 1));
for (const [id, s] of Object.entries(out.scenarios)) console.log(id.padEnd(13), JSON.stringify({ apex: s.expect.apex, air: s.expect.air_frames, max_speed: s.expect.max_speed, t95: s.expect.t95_frame, end: s.expect.end }));
