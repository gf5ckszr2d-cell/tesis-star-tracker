(function attachStarGeometry(root, factory) {
  const api = factory();
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  root.StarGeometry = api;
}(typeof globalThis !== "undefined" ? globalThis : this, function buildStarGeometry() {
  "use strict";

  const DEG = Math.PI / 180;
  const degToRad = (value) => value * DEG;
  const radToDeg = (value) => value / DEG;
  const clamp = (value, minimum, maximum) => Math.min(maximum, Math.max(minimum, value));
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

  function addScaled(target, source, scale) {
    target[0] += source[0] * scale;
    target[1] += source[1] * scale;
    target[2] += source[2] * scale;
    return target;
  }

  function normalize(vector) {
    const length = Math.hypot(vector[0], vector[1], vector[2]);
    return length === 0 ? [0, 0, 0] : [vector[0] / length, vector[1] / length, vector[2] / length];
  }

  function celestialUnitVector(raDeg, decDeg) {
    const ra = degToRad(raDeg);
    const dec = degToRad(decDeg);
    const cosDec = Math.cos(dec);
    return [cosDec * Math.cos(ra), cosDec * Math.sin(ra), Math.sin(dec)];
  }

  function celestialBasis(centerRaDeg, centerDecDeg, rollDeg) {
    const ra = degToRad(centerRaDeg);
    const dec = degToRad(centerDecDeg);
    const roll = degToRad(rollDeg);
    const forward = celestialUnitVector(centerRaDeg, centerDecDeg);
    const east = [-Math.sin(ra), Math.cos(ra), 0];
    const north = [-Math.cos(ra) * Math.sin(dec), -Math.sin(ra) * Math.sin(dec), Math.cos(dec)];
    const cosRoll = Math.cos(roll);
    const sinRoll = Math.sin(roll);
    return {
      forward,
      right: [east[0] * cosRoll + north[0] * sinRoll, east[1] * cosRoll + north[1] * sinRoll, east[2] * cosRoll + north[2] * sinRoll],
      up: [north[0] * cosRoll - east[0] * sinRoll, north[1] * cosRoll - east[1] * sinRoll, north[2] * cosRoll - east[2] * sinRoll],
    };
  }

  function celestialToMonitorRay(starVector, basis) {
    const forwardComponent = dot(starVector, basis.forward);
    if (forwardComponent <= 0) return null;
    return normalize([dot(starVector, basis.right), dot(starVector, basis.up), -forwardComponent]);
  }

  function cameraBasis(yawDeg, pitchDeg, rollDeg) {
    const yaw = degToRad(yawDeg);
    const pitch = degToRad(pitchDeg);
    const roll = degToRad(rollDeg);
    const yawRight = [Math.cos(yaw), 0, Math.sin(yaw)];
    const yawUp = [0, 1, 0];
    const yawForward = [Math.sin(yaw), 0, -Math.cos(yaw)];
    const pitchedForward = normalize([
      yawForward[0] * Math.cos(pitch) + yawUp[0] * Math.sin(pitch),
      yawForward[1] * Math.cos(pitch) + yawUp[1] * Math.sin(pitch),
      yawForward[2] * Math.cos(pitch) + yawUp[2] * Math.sin(pitch),
    ]);
    const pitchedUp = normalize([
      yawUp[0] * Math.cos(pitch) - yawForward[0] * Math.sin(pitch),
      yawUp[1] * Math.cos(pitch) - yawForward[1] * Math.sin(pitch),
      yawUp[2] * Math.cos(pitch) - yawForward[2] * Math.sin(pitch),
    ]);
    return {
      forward: pitchedForward,
      right: normalize([
        yawRight[0] * Math.cos(roll) + pitchedUp[0] * Math.sin(roll),
        yawRight[1] * Math.cos(roll) + pitchedUp[1] * Math.sin(roll),
        yawRight[2] * Math.cos(roll) + pitchedUp[2] * Math.sin(roll),
      ]),
      up: normalize([
        pitchedUp[0] * Math.cos(roll) - yawRight[0] * Math.sin(roll),
        pitchedUp[1] * Math.cos(roll) - yawRight[1] * Math.sin(roll),
        pitchedUp[2] * Math.cos(roll) - yawRight[2] * Math.sin(roll),
      ]),
    };
  }

  function cameraRayToMonitor(localRay, basis) {
    return normalize(addScaled(addScaled(addScaled([0, 0, 0], basis.right, localRay[0]), basis.up, localRay[1]), basis.forward, localRay[2]));
  }

  function monitorRayToCamera(monitorRay, basis) {
    return [dot(monitorRay, basis.right), dot(monitorRay, basis.up), dot(monitorRay, basis.forward)];
  }

  function cameraVerticalFov(horizontalFovDeg, sensorWidth, sensorHeight) {
    return radToDeg(2 * Math.atan(Math.tan(degToRad(horizontalFovDeg) / 2) * sensorHeight / sensorWidth));
  }

  // Inverse of r_d = r * (1 + k1*r^2 + k2*r^4), on the monotonic central branch.
  // Reject folds instead of inventing a second, ambiguous image of the sky.
  function undistortTangent(x, y, k1 = 0, k2 = 0) {
    const rd = Math.hypot(x, y);
    if (rd === 0 || (k1 === 0 && k2 === 0)) return [x, y];
    const roots = [];
    if (Math.abs(k2) < 1e-14) {
      if (k1 < 0) roots.push(-1 / (3 * k1));
    } else {
      const discriminant = 9 * k1 * k1 - 20 * k2;
      if (discriminant >= 0) {
        roots.push((-3 * k1 + Math.sqrt(discriminant)) / (10 * k2));
        roots.push((-3 * k1 - Math.sqrt(discriminant)) / (10 * k2));
      }
    }
    const fold = Math.min(...roots.filter((r) => r > 0), Infinity);
    let hi = Math.min(64, Math.sqrt(fold) * (1 - 1e-9));
    const distort = (r) => r * (1 + k1 * r * r + k2 * r ** 4);
    if (rd > distort(hi)) return null;
    let lo = 0;
    for (let i = 0; i < 55; i += 1) {
      const mid = (lo + hi) / 2;
      if (distort(mid) < rd) lo = mid; else hi = mid;
    }
    const scale = (lo + hi) / (2 * rd);
    return [x * scale, y * scale];
  }

  function cameraPixelRay(x, y, camera, basis) {
    const tanH = Math.tan(degToRad(camera.horizontalFovDeg) / 2);
    const tanV = tanH * camera.sensorHeight / camera.sensorWidth;
    const tangent = undistortTangent(
      (2 * x / camera.sensorWidth - 1) * tanH,
      (1 - 2 * y / camera.sensorHeight) * tanV,
      camera.lensK1, camera.lensK2,
    );
    return tangent ? cameraRayToMonitor([tangent[0], tangent[1], 1], basis) : null;
  }

  function screenPointToRay(point, cameraDistanceMm) {
    return normalize([point[0], point[1], point[2] - cameraDistanceMm]);
  }

  function intersectCylindricalScreen(ray, model) {
    const radius = model.curveRadiusMm;
    const cameraZ = model.cameraDistanceMm;
    const a = ray[0] * ray[0] + ray[2] * ray[2];
    const b = 2 * (cameraZ - radius) * ray[2];
    const c = (cameraZ - radius) * (cameraZ - radius) - radius * radius;
    const discriminant = b * b - 4 * a * c;
    if (a <= 1e-12 || discriminant < 0) return null;
    const root = Math.sqrt(discriminant);
    const candidates = [(-b - root) / (2 * a), (-b + root) / (2 * a)].filter((value) => value > 1e-9).sort((left, right) => left - right);
    const halfArc = model.screenWidthMm / (2 * radius);
    for (const distance of candidates) {
      const x = distance * ray[0];
      const y = distance * ray[1];
      const z = cameraZ + distance * ray[2];
      const alpha = Math.atan2(x, radius - z);
      if (Math.abs(alpha) <= halfArc + 1e-10 && Math.abs(y) <= model.screenHeightMm / 2 + 1e-10) {
        return { distance, point: [x, y, z], alpha, u: alpha / (2 * halfArc) + 0.5, v: 0.5 - y / model.screenHeightMm };
      }
    }
    return null;
  }

  function projectMonitorRayToScreen(ray, model) {
    const hit = intersectCylindricalScreen(ray, model);
    return hit ? { ...hit, xPx: hit.u * model.screenWidthPx, yPx: hit.v * model.screenHeightPx } : null;
  }

  function projectMonitorRayToCamera(ray, camera, basis) {
    const local = monitorRayToCamera(ray, basis);
    if (local[2] <= 0) return null;
    const halfHorizontal = degToRad(camera.horizontalFovDeg) / 2;
    const halfVertical = degToRad(cameraVerticalFov(camera.horizontalFovDeg, camera.sensorWidth, camera.sensorHeight)) / 2;
    const xTangent = local[0] / local[2];
    const yTangent = local[1] / local[2];
    const radiusSquared = xTangent * xTangent + yTangent * yTangent;
    const radial = 1 + camera.lensK1 * radiusSquared + camera.lensK2 * radiusSquared * radiusSquared;
    const normalizedX = xTangent * radial / Math.tan(halfHorizontal);
    const normalizedY = yTangent * radial / Math.tan(halfVertical);
    return {
      normalizedX,
      normalizedY,
      inside: Math.abs(normalizedX) <= 1 && Math.abs(normalizedY) <= 1,
      xPx: (normalizedX * 0.5 + 0.5) * camera.sensorWidth,
      yPx: (0.5 - normalizedY * 0.5) * camera.sensorHeight,
    };
  }

  function screenAngularCoverage(model) {
    const halfArc = model.screenWidthMm / (2 * model.curveRadiusMm);
    const edgeX = model.curveRadiusMm * Math.sin(halfArc);
    const edgeZ = model.curveRadiusMm * (1 - Math.cos(halfArc));
    return {
      horizontalDeg: radToDeg(2 * Math.atan2(edgeX, model.cameraDistanceMm - edgeZ)),
      verticalDeg: radToDeg(2 * Math.atan2(model.screenHeightMm / 2, model.cameraDistanceMm)),
    };
  }

  function screenSurfacePoint(alpha, yMm, model) {
    return [model.curveRadiusMm * Math.sin(alpha), yMm, model.curveRadiusMm * (1 - Math.cos(alpha))];
  }

  function cameraFovBoundary(camera, basis, model, steps = 28) {
    const samples = [];
    for (let index = 0; index <= steps; index += 1) samples.push([-1 + 2 * index / steps, -1]);
    for (let index = 1; index <= steps; index += 1) samples.push([1, -1 + 2 * index / steps]);
    for (let index = 1; index <= steps; index += 1) samples.push([1 - 2 * index / steps, 1]);
    for (let index = 1; index <= steps; index += 1) samples.push([-1, 1 - 2 * index / steps]);
    samples.push(samples[0]);
    return samples.map(([normalizedX, normalizedY]) => {
      const ray = cameraPixelRay((normalizedX + 1) * camera.sensorWidth / 2,
        (normalizedY + 1) * camera.sensorHeight / 2, camera, basis);
      return ray ? projectMonitorRayToScreen(ray, model) : null;
    });
  }

  function cameraFootprint(camera, basis, model) {
    const boundary = cameraFovBoundary(camera, basis, model);
    const hits = boundary.filter(Boolean);
    if (hits.length === 0) return null;
    const alphas = hits.map((hit) => hit.alpha);
    const heights = hits.map((hit) => hit.point[1]);
    const widthMm = (Math.max(...alphas) - Math.min(...alphas)) * model.curveRadiusMm;
    const heightMm = Math.max(...heights) - Math.min(...heights);
    return {
      widthMm,
      heightMm,
      widthFraction: widthMm / model.screenWidthMm,
      heightFraction: heightMm / model.screenHeightMm,
      clipped: hits.length !== boundary.length,
    };
  }

  return Object.freeze({
    clamp, degToRad, radToDeg, normalize, celestialUnitVector, celestialBasis, celestialToMonitorRay,
    cameraBasis, cameraRayToMonitor, monitorRayToCamera, cameraVerticalFov, intersectCylindricalScreen,
    projectMonitorRayToScreen, projectMonitorRayToCamera, screenAngularCoverage, screenSurfacePoint,
    cameraFovBoundary, cameraFootprint, undistortTangent, cameraPixelRay, screenPointToRay,
  });
}));
