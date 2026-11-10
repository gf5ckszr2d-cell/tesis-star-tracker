"""Analysis of raw QVGA Y. All centroids here are PC outputs, never FPGA outputs."""
import math
import numpy as np


def components(image, threshold, min_area=2, max_area=500):
    a = np.asarray(image, dtype=np.uint8)
    h, w = a.shape
    mask = a >= threshold
    labels = np.full((h, w), -1, dtype=np.int32)
    blobs = []
    for yy, xx in zip(*np.nonzero(mask)):
        if labels[yy, xx] != -1:
            continue
        label = len(blobs)
        todo, pixels = [(int(xx), int(yy))], []
        labels[yy, xx] = label
        while todo:
            x, y = todo.pop()
            pixels.append((x, y))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and labels[ny, nx] == -1:
                        labels[ny, nx] = label
                        todo.append((nx, ny))
        p = np.array(pixels)
        v = a[p[:, 1], p[:, 0]].astype(float)
        total = float(v.sum())
        # Y weights and inclusive absolute threshold are explicit choices.
        center = (p*v[:, None]).sum(axis=0)/total if total else p.mean(axis=0)
        blobs.append(dict(label=label, area=len(pixels), x=float(center[0]), y=float(center[1]),
                          peak=int(v.max()), sum_y=total,
                          accepted=min_area <= len(pixels) <= max_area,
                          touches_edge=bool(((p[:, 0]==0)|(p[:, 0]==w-1)|(p[:, 1]==0)|(p[:, 1]==h-1)).any())))
    return blobs, labels


def stats(image):
    a = np.asarray(image, dtype=np.uint8)
    median = float(np.median(a))
    return dict(min=int(a.min()), max=int(a.max()), mean=float(a.mean()),
                median=median, std=float(a.std()),
                mad_sigma=float(1.4826*np.median(np.abs(a.astype(float)-median))),
                p999=float(np.percentile(a, 99.9)), rail_255=int((a==255).sum()),
                near_rail_250=int((a>=250).sum()))


def fit_geometry(screen, camera, train_indices):
    screen, camera = np.array(screen, float), np.array(camera, float)
    design = np.column_stack((screen, np.ones(len(screen))))
    train = np.array(train_indices)
    if np.linalg.matrix_rank(design[train]) != 3:
        raise ValueError('Correspondencias geometricas degeneradas')
    matrix = np.linalg.lstsq(design[train], camera[train], rcond=None)[0]
    held = sorted(set(range(len(screen)))-set(train_indices))
    errors = np.linalg.norm(design@matrix-camera, axis=1)
    return dict(model='local affine screen_to_camera; empirical PC reference',
                matrix=matrix.tolist(), train_indices=list(train_indices), heldout_indices=held,
                residual_px=errors.tolist(), heldout_max_px=float(max(errors[held])),
                heldout_rms_px=float(np.sqrt(np.mean(errors[held]**2))),
                screen_bounds=[screen.min(axis=0).tolist(), screen.max(axis=0).tolist()],
                absolute_metrology=False)


def project(points, geometry):
    return (np.column_stack((np.asarray(points, float), np.ones(len(points)))) @
            np.array(geometry['matrix'])).tolist()


def associations(blobs, labels, expected, gate):
    """Separate fused expected sources from one-to-one matches and omissions."""
    accepted = {b['label']: b for b in blobs if b['accepted']}
    ownership = {}
    h, w = labels.shape
    for j, (x, y) in enumerate(expected):
        ix, iy = int(round(x)), int(round(y))
        if not 0 <= ix < w or not 0 <= iy < h:
            raise ValueError('Fuente de referencia fuera del encuadre')
        lab = int(labels[iy, ix])
        if lab >= 0:
            ownership.setdefault(lab, []).append(j)
    fused = {lab: js for lab, js in ownership.items() if len(js)>1}
    fused_refs = {j for js in fused.values() for j in js}
    # At most five expected references in D3. Enumerate feasible assignments and
    # maximize cardinality first, then minimize total squared distance.
    candidates = {}
    for j, (x, y) in enumerate(expected):
        if j in fused_refs:
            continue
        candidates[j] = sorted([(lab, (b['x']-x)**2+(b['y']-y)**2)
                               for lab, b in accepted.items() if lab not in fused and
                               math.hypot(b['x']-x,b['y']-y) <= gate], key=lambda v:v[1])
    refs = list(candidates)
    best = (0, float('inf'), [])
    def visit(i, used, chosen, cost):
        nonlocal best
        if len(chosen)+len(refs)-i < best[0]:
            return
        if i==len(refs):
            if len(chosen)>best[0] or (len(chosen)==best[0] and cost<best[1]):
                best=(len(chosen), cost, list(chosen))
            return
        j=refs[i]
        for lab, distance in candidates[j]:
            if lab not in used:
                visit(i+1, used|{lab}, chosen+[(j,lab,math.sqrt(distance))], cost+distance)
        visit(i+1, used, chosen, cost)
    visit(0, set(), [], 0)
    matched = {lab for _, lab, _ in best[2]}
    return dict(expected=len(expected), correct=best[0],
                omissions=len(expected)-best[0]-len(fused_refs),
                fused_sources=len(fused_refs), fusion_components=len(fused),
                rejected_components=sum(not b['accepted'] for b in blobs),
                false_components=len(set(accepted)-matched-set(fused)),
                matches=[dict(reference=j,label=lab,error_pc_px=d) for j,lab,d in best[2]],
                correct_fraction=best[0]/len(expected) if expected else None,
                gate_camera_px=gate)


def response_curve(rows):
    grouped = {}
    for row in rows:
        grouped.setdefault(row['level'], []).append(row['patch_mean'])
    levels = sorted(grouped)
    means = [float(np.mean(grouped[x])) for x in levels]
    return dict(levels=levels, y_means=means,
                y_std_between_frames=[float(np.std(grouped[x])) for x in levels],
                black_y=means[0], white_y=means[-1], span_y=means[-1]-means[0],
                monotonic_with_2dn_tolerance=all(b >= a-2 for a,b in zip(means,means[1:])),
                units='monitor RGB code -> captured Y DN, fixed settings; not cd/m2 or photons')
