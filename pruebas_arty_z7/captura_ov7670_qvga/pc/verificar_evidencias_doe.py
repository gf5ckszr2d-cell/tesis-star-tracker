"""Audit saved physical DoE evidence without operating the camera or altering results."""
import argparse
from collections import Counter,defaultdict
import hashlib
import json
import re
from pathlib import Path
from PIL import Image
from doe_device import decode_profile


def audit(directory):
    directory=Path(directory).resolve()
    rows=json.loads((directory/'measurements.json').read_text(encoding='utf-8'))
    manifest=json.loads((directory/'manifest.json').read_text(encoding='utf-8'))
    decisions=json.loads((directory/'decisions.json').read_text(encoding='utf-8'))
    state=json.loads((directory/'state.json').read_text(encoding='utf-8'))
    errors=[];incomplete=[];groups=defaultdict(list)
    active_attempt=max((int(re.match(r'A(\d+)_',r['condition'])[1]) for r in rows if re.match(r'A(\d+)_',r['condition'])),default=1)
    identities=[r['id'] for r in rows]
    if len(identities)!=len(set(identities)):errors.append('DUPLICATE_FRAME_ID')
    for row in rows:
        identity=row['id'];groups[(row['stage'],row['condition'])].append(row)
        png=directory/row['image'];raw=png.with_suffix('.raw')
        try:
            payload=raw.read_bytes()
            with Image.open(png) as im:
                if im.mode!='L' or im.size!=(320,240) or im.tobytes()!=payload:
                    errors.append(identity+': PNG_RAW_MISMATCH')
            if len(payload)!=76800 or hashlib.sha256(payload).hexdigest()!=row['raw_sha256']:
                errors.append(identity+': RAW_SIZE_OR_HASH')
            scene=json.loads((directory/'patterns'/(row['scene']['id']+'.json')).read_text(encoding='utf-8'))
            if scene!=row['scene']:errors.append(identity+': PATTERN_METADATA_MISMATCH')
            if row.get('display',{}).get('id')!=scene['id']:errors.append(identity+': DISPLAY_SCENE_MISMATCH')
            profile=decode_profile(row['registers'])
            if any(profile[k]!=row[k] for k in profile):errors.append(identity+': PROFILE_DECODE_MISMATCH')
        except (OSError,ValueError,KeyError) as exc:errors.append(identity+': '+repr(exc))
    for key,group in groups.items():
        if len({json.dumps(r['registers'],sort_keys=True) for r in group})!=1:
            errors.append(str(key)+': REGISTERS_DIFFER_WITHIN_CONDITION')
        expected=3 if key[0].startswith('CAL_') or key[0]=='GEOMETRIA' else 5
        repetitions=sorted(r['repeat'] for r in group)
        if len(set(repetitions))!=len(repetitions) or any(r<1 or r>expected for r in repetitions):
            errors.append(str(key)+': INVALID_OR_DUPLICATE_REPEATS')
        if repetitions!=list(range(1,expected+1)):
            incomplete.append(dict(stage=key[0],condition=key[1],expected=expected,observed=repetitions,
                active_attempt=key[1].startswith(f'A{active_attempt}_')))
    commands=[json.loads(line) for line in (directory/'commands.jsonl').read_text(encoding='utf-8').splitlines() if line.strip()]
    warnings=['Centroids are PC_OFFLINE_Y8; this does not validate FPGA centroids or absolute accuracy.']
    geometry=manifest.get('display_geometry',{})
    if geometry.get('scale_x')!=geometry.get('scale_y'):warnings.append('Pattern scaled independently in X/Y; stimulus coordinates are design pixels.')
    calibrations={k:{x:v[x] for x in ('black_y','white_y','threshold_y','span_y')} for k,v in manifest.items() if k.startswith('CAL_')}
    if any(v['white_y']>=254 for v in calibrations.values()):warnings.append('At least one uniform white reference clips; it is a digital ceiling, not linear radiometry.')
    retries=sum(c.get('event')=='SCCB_TRANSIENT_RETRY' for c in commands)
    if retries:warnings.append(f'{retries} register-access retries were required and logged; control root cause remains unresolved.')
    restart=max((i for i,d in enumerate(decisions) if d['result']=='RETURN_D1'),default=-1)
    active_decisions=decisions[restart+1:]
    d3=[d for d in active_decisions if d['stage']=='D3' and d.get('condition')]
    if any(d.get('nominal_sources_overlap') for d in d3):warnings.append('Overlapping design disks must not be interpreted as an optical separation limit.')
    result=dict(physical=manifest['physical'],run_state=state['phase'],
        evidence_integrity_pass=bool(rows) and not errors,errors=errors,warnings=warnings,
        n_frames=len(rows),frames_by_stage=dict(Counter(r['stage'] for r in rows)),
        active_flow_attempt=active_attempt,incomplete_conditions=incomplete,
        active_conditions_complete=not any(g['active_attempt'] for g in incomplete),
        register_access_retries=retries,calibrations=calibrations,
        D1_pass=any(d['stage']=='D1' and d['result']=='PASS' for d in active_decisions),
        D2_pass=any(d['stage']=='D2' and d['result']=='PASS' for d in active_decisions),
        D3_conditions=d3,selected_D1=manifest.get('selected_D1'),selected_D2=manifest.get('selected_D2'))
    (directory/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=Path)
    result=audit(parser.parse_args().directory)
    print(json.dumps(result,ensure_ascii=False,indent=2))
    raise SystemExit(0 if result['evidence_integrity_pass'] else 1)
