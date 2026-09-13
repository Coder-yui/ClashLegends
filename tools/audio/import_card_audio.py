"""Import explicitly selected base-skin event renders; original WAD libraries stay read-only.
Requires externally prepared wwiser TXTP banks under --source (see AUDIO_CARD_MAP.md).
No event-name guessing: the reviewed JSON whitelist owns all mappings.
"""
from audio_manifest_merge import merge_audio_manifest
import argparse, hashlib, json, re, shutil, subprocess, wave
from pathlib import Path
from death_audio_envelope import apply_death_envelope, DEATH_AUDIO_NOTE

ROOT = Path(__file__).resolve().parents[2]

def event_id(name):
    result = 2166136261
    for char in name.lower().encode():
        result = ((result * 16777619) ^ char) & 0xffffffff
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--cards', nargs='+', required=True, help='Only import these reviewed plan IDs; gnar_mega is explicit')
    parser.add_argument('--plan', type=Path, default=Path(__file__).with_name('card_audio_plan.json'))
    parser.add_argument('--dry-run', action='store_true', help='Print selected plan destinations without reading or writing audio')
    args = parser.parse_args()
    args.source = args.source.resolve()
    plans = json.loads(args.plan.read_text())
    unknown = set(args.cards) - plans.keys()
    if unknown:
        parser.error('Unknown card plan IDs: ' + ', '.join(sorted(unknown)))
    plans = {card_id: plans[card_id] for card_id in dict.fromkeys(args.cards)}
    if args.dry_run:
        for card_id, plan in plans.items():
            print(f'{card_id}: {args.source / plan["source"]} -> assets/audio/units/{"gnar" if card_id == "gnar_mega" else card_id}')
        return
    for card_id, plan in plans.items():
        dest = ROOT/'assets/audio/units'/('gnar' if card_id == 'gnar_mega' else card_id)
        dest.mkdir(parents=True, exist_ok=True)
        manifest, rows, cache = [], [], {}
        def pool(event):
            if event in cache:
                return cache[event]
            source = args.source/(plan['source'] + ('_vo' if event.startswith('Play_vo') else ''))
            candidates = sorted(p for p in (source/'txtp').glob('*.txtp') if re.split(r' [\[{]', p.stem)[0] == event)
            if not candidates:
                raise RuntimeError(f'{card_id}: no rendered event graph for {event}')
            # Keep one explicit switch combination; random variations within it are interchangeable.
            condition = lambda p: re.sub(r'\{r\d+\}', '', p.stem).strip()
            selected = [p for p in candidates if condition(p) == condition(candidates[0])][:int(plan.get("event_variant_limits", {}).get(event, 3))]
            paths = []
            for txtp in selected:
                assert re.search(r"CAkEvent\[\d+\] " + str(event_id(event)) + r"\b", txtp.read_text()), event
                preview = source/'event_wav'/(txtp.stem+'.wav')
                preview.parent.mkdir(exist_ok=True)
                if not preview.exists():
                    subprocess.run(['vgmstream-cli','-i','-o',str(preview),str(txtp)],check=True,capture_output=True)
                processing = 'vgmstream-cli -i; source event gain retained'
                if event in plan.get('trim_events', {}):
                    duration = float(plan['trim_events'][event])
                    trimmed = preview.with_stem(preview.stem+'_onset')
                    subprocess.run(['ffmpeg','-v','error','-y','-i',str(preview),'-t',str(duration),'-af',f'afade=t=out:st={duration-.05}:d=0.05','-c:a','pcm_s16le',str(trimmed)],check=True)
                    preview = trimmed
                    processing += f'; first {duration}s, final 50ms fade'
                with wave.open(str(preview)) as wav:
                    frames = wav.readframes(wav.getnframes())
                    assert wav.getnframes() > 0 and any(frames), preview
                    duration = wav.getnframes()/wav.getframerate()
                filename = re.sub('[^a-z0-9]+','_',preview.stem.lower()).strip('_')+('_zh_cn' if event.startswith('Play_vo') else '')+'.wav'
                shutil.copy2(preview,dest/filename)
                paths.append('res://'+str((dest/filename).relative_to(ROOT)))
                manifest.append(dict(file=filename,event=event,event_id=event_id(event),source_preview=str(preview),source_txtp=str(txtp),media_ids=sorted(set(map(int,re.findall(r'^#\s+Source (\d+)',txtp.read_text(),re.M)))),duration=round(duration,4),processing=processing,sha256=hashlib.sha256(preview.read_bytes()).hexdigest(),selection_note='首个明确 Switch 条件，最多三个外层随机变体；media_ids 为该 TXTP 可达媒体，嵌套随机未穷举。'))
                if event == plan['events'].get('death'):
                    apply_death_envelope(dest/filename, manifest[-1])
            cache[event] = paths
            return paths
        audio = {'events':{}}
        if plan['attack']:
            audio['attack_swing'] = [pool(e) for e in plan['attack']]
            audio['attack_swing_volume_db'] = -3.0
            rows.extend((f'attack_swing[{i+1}]',e) for i,e in enumerate(plan['attack']))
        if plan['hit']:
            audio['attack_hit'] = pool(plan['hit'])
            audio['attack_hit_volume_db'] = -5.0
            rows.append(('attack_hit',plan['hit']))
        if plan.get('launch_segments'):
            audio['attack_launch_by_segment'] = [pool(e) for e in plan['launch_segments']]
            rows.extend((f'attack_launch_by_segment[{i+1}]', e) for i, e in enumerate(plan['launch_segments']))
        if plan.get('hit_segments'):
            audio['attack_hit_by_segment'] = [pool(e) for e in plan['hit_segments']]
            rows.extend((f'attack_hit_by_segment[{i+1}]',e) for i,e in enumerate(plan['hit_segments']))
        if plan.get('empowered_hit'):
            audio['empowered_hit'] = pool(plan['empowered_hit'])
            rows.append(('empowered_hit',plan['empowered_hit']))
        for cue,event in plan['events'].items():
            audio['events'][cue] = {'pool':pool(event),'volume_db':float(plan.get('event_volume_db', {}).get(cue, 0.0)),'bus':'Voice' if event.startswith('Play_vo') else 'Combat'}
            rows.append((cue,event))
        for cue, sequence in plan.get('sequences', {}).items():
            inputs = [pool(item['event'])[0] for item in sequence]
            mix = args.source/plan['source']/'event_wav'/('gwen_q_'+cue.split(':')[0]+'.wav')
            command = ['ffmpeg', '-v', 'error', '-y']
            for path in inputs:
                command += ['-i', str(ROOT/path.removeprefix('res://'))]
            filters = [f'[{i}:a]adelay={round(item["time"]*1000)}:all=1[a{i}]' for i,item in enumerate(sequence)]
            filters.append(''.join(f'[a{i}]' for i in range(len(sequence)))+f'amix=inputs={len(sequence)}:normalize=0,atrim=duration=1.5,afade=t=out:st=1.48:d=0.02[out]')
            subprocess.run(command+['-filter_complex',';'.join(filters),'-map','[out]','-ar','44100','-ac','1','-c:a','pcm_s16le',str(mix)],check=True)
            shutil.copy2(mix,dest/mix.name)
            audio['events'][cue] = {'pool':['res://'+str((dest/mix.name).relative_to(ROOT))], 'volume_db':0.0}
            manifest.append(dict(file=mix.name,event=' + '.join(item['event'] for item in sequence),source_preview=str(mix),sequence=sequence,processing='ffmpeg adelay ms; amix normalize=0; 1.5 s with final 20 ms fade; 44.1k mono PCM16',sha256=hashlib.sha256(mix.read_bytes()).hexdigest()))
            rows.append((cue,' → '.join(f"{item['time']:.3f}s {item['event']}" for item in sequence)))
        audio.update(plan.get('audio_overrides', {}))
        target = ROOT/'scripts/data/cards'/('gnar.gd' if card_id == 'gnar_mega' else card_id+'.gd')
        indent = '\t' * (4 if card_id == 'gnar_mega' else 2)
        block = indent+'# BEGIN IMPORTED AUDIO '+card_id+'\n'+indent+'"audio": '+json.dumps(audio,ensure_ascii=False,indent='\t').replace('\n','\n'+indent)+',\n'+indent+'# END IMPORTED AUDIO '+card_id+'\n'
        content = target.read_text()
        pattern = re.escape(indent+'# BEGIN IMPORTED AUDIO '+card_id)+'\n.*?'+re.escape(indent+'# END IMPORTED AUDIO '+card_id)+'\n'
        if re.search(pattern, content, re.S):
            content = re.sub(pattern, lambda _: block, content, count=1, flags=re.S)
        else:
            marker = indent+'"visual_scene_path":' if card_id == 'gnar_mega' else indent+'"card_art":'
            assert marker in content
            content = content.replace(marker,block+marker,1)
        target.write_text(content)
        manifest = merge_audio_manifest(dest/('mega_event_manifest.json' if card_id=='gnar_mega' else 'event_manifest.json'), manifest)
        (dest/('mega_event_manifest.json' if card_id=='gnar_mega' else 'event_manifest.json')).write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
        (dest/('MEGA_README.md' if card_id=='gnar_mega' else 'README.md')).write_text(f'# {card_id} 音频映射\n\n{plan["notes"]}\n\n| 项目 cue / 动作段 | 原始事件 |\n| --- | --- |\n'+''.join(f'| `{c}` | `{e}` |\n' for c,e in rows)+'\n文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。\n\n来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。\n\n验收状态与缺口见 docs/AUDIO_CARD_MAP.md。\n')
        if 'death' in plan['events']:
            with (dest/('MEGA_README.md' if card_id=='gnar_mega' else 'README.md')).open('a') as readme:
                readme.write('\n'+DEATH_AUDIO_NOTE+'\n')
        print(card_id,len(manifest),flush=True)

if __name__ == '__main__':
    main()
