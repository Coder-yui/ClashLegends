#!/usr/bin/env python3
"""Package the existing Pantheon review capture manifest into an offline video gallery."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import csv
import hashlib
import json
from pathlib import Path
import subprocess

from PIL import Image, ImageChops, ImageStat

GROUPS = {
    'Spear_Landing': 'G · 长矛空中光焰与轨迹',
    'Spear_Impact': 'A · 长矛插地',
    'update_missile': 'B · 空中俯冲',
    'Sliding_Comet': 'C · 滑行彗星',
    'Damage_Mis': 'D · 滑行冲击波',
    'Update_Impact': 'E · 人物撞地',
    'Ending_Shockwave': 'F · 到点收尾波',
    '独立对象': 'P · 长矛与人物代理',
}


def encode(item, source, target):
    frames = sorted((source / 'frames' / item['id']).glob('*.png'))
    if len(frames) != int(item['frames']):
        raise ValueError(f"{item['id']}: expected {item['frames']}, found {len(frames)} frames")
    bounds, best, score = None, frames[0], -1
    if item['kind'] != 'deployment':
        for frame in frames:
            with Image.open(frame) as image:
                image = image.convert('RGB')
                background = Image.new('RGB', image.size, image.getpixel((0, 0)))
                difference = ImageChops.difference(image, background)
                channels = difference.split()
                mask = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])
                box = mask.point(lambda x: 255 if x > 5 else 0).getbbox()
                value = sum(ImageStat.Stat(difference).sum)
                if value > score:
                    score, best = value, frame
                if box:
                    bounds = box if bounds is None else (min(bounds[0], box[0]), min(bounds[1], box[1]), max(bounds[2], box[2]), max(bounds[3], box[3]))
        if bounds:
            cx, cy = (bounds[0] + bounds[2]) / 2, (bounds[1] + bounds[3]) / 2
            side = min(512, max(96, int(max(bounds[2]-bounds[0], bounds[3]-bounds[1]) * 1.18)))
            side += side % 2
            x, y = max(0, min(512-side, int(cx-side/2))), max(0, min(512-side, int(cy-side/2)))
            crop = (x, y, x+side, y+side)
        else:
            crop = (0, 0, 512, 512)
        filter_arg = f'crop={crop[2]-crop[0]}:{crop[3]-crop[1]}:{crop[0]}:{crop[1]},scale=512:512:flags=lanczos'
        with Image.open(best) as image:
            image.convert('RGB').crop(crop).resize((512, 512), Image.Resampling.LANCZOS).save(target / f"{item['id']}.jpg", quality=92)
        item['crop'] = crop
        item['visible_pixels'] = bounds is not None
    else:
        filter_arg = 'format=yuv420p'
        best = frames[min(95, len(frames)-1)]
        with Image.open(best) as image:
            image.convert('RGB').save(target / f"{item['id']}.jpg", quality=92)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-framerate', str(item['fps']), '-i', str(source/'frames'/item['id']/'%04d.png'),
                    '-vf', filter_arg, '-an', '-c:v', 'libx264', '-crf', '19', '-preset', 'fast', '-threads', '1',
                    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(target/f"{item['id']}.mp4")], check=True)
    item['label'] = GROUPS.get(item['system'], item['system'])
    print('ENCODED', item['id'], flush=True)
    return item


def build_page(items, disabled_systems=(), disabled_layers=()):
    items = [dict(item, applied_disabled=item["system"] in disabled_systems or (item["system"]+"/"+item.get("emitter", "")) in disabled_layers) for item in items]
    data = json.dumps(items, ensure_ascii=False).replace('</', '<\\/')
    return r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>潘森 · 落地特效逐层审查</title>
<style>
:root{color-scheme:dark;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;background:#101614;color:#e9eee9}*{box-sizing:border-box}body{max-width:1500px;margin:auto;padding:30px}h1{font-size:30px;margin:5px 0 12px}p{line-height:1.8;color:#acb9b0}button,input,select{font:inherit;color:inherit;background:#25332b;border:1px solid #496353;border-radius:8px;padding:9px 14px}button{cursor:pointer}button:hover{background:#344a3c}header{margin-bottom:24px}.tag{color:#ffd88a;font:600 13px monospace}.lead{max-width:980px}.toolbar{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:16px 0}.deployment{border:1px solid #3b4c41;padding:18px;border-radius:14px;background:#19221d}.deployment video{width:100%;background:#080c09;max-height:650px}h2{font-size:22px}.views{display:flex;justify-content:space-around;color:#bdccbe;margin-bottom:10px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:14px}article{background:#1b2620;border:1px solid #344a3d;border-radius:12px;overflow:hidden;cursor:pointer}article:hover{border-color:#dfbf72}article img{width:100%;aspect-ratio:1;object-fit:cover;display:block}article .text{padding:12px}article strong{font-size:15px;display:block;margin:5px 0;overflow-wrap:anywhere}small{color:#9baea0}details{margin-top:25px}summary{font-size:21px;cursor:pointer;padding:15px 0}.sticky{position:sticky;top:0;background:#101614ed;backdrop-filter:blur(12px);padding:12px 0;z-index:2;border-bottom:1px solid #344a3d}.sticky input{min-width:270px}#viewer{position:fixed;inset:2vh 0 auto;margin:auto;z-index:20;max-height:96vh;overflow:auto;box-shadow:0 0 0 100vmax #000b;width:min(900px,96vw);border:1px solid #63785e;border-radius:14px;background:#152019;color:#eff5eb;padding:22px}#viewer video{display:block;width:100%;max-height:66vh;background:#434f49}#viewer .toolbar{justify-content:space-between}.hint{background:#283425;padding:12px 16px;border-radius:9px;color:#d4dccf}.hidden{display:none!important}.foot{margin:35px 0;color:#98ad9c}a{color:#dfbf72}output{font-variant-numeric:tabular-nums;color:#ffd88a}
.sticky input[type=checkbox]{min-width:0;width:18px;height:18px}.toolbar label:has(input[type=checkbox]){display:flex;align-items:center;gap:8px}article.rejected{border:2px solid #e58b79} .reject-choice{display:flex;gap:10px;align-items:center;padding:12px;color:#ffd1c7;cursor:pointer} .reject-choice input{min-width:0;width:20px;height:20px} .selection-status{color:#ffd88a} .applied{color:#eda798}</style>
<header><span class="tag">CURRENT GAME RENDER · LANDING ONLY</span><h1>潘森 · 落地特效逐层审查</h1><p class="lead">先看两个视角的完整部署，再对照下面的编号定位。目录保留__LAYERS__个粒子层、__GROUPS__组组合效果，以及独立长矛和两段人物代理，包含已停用效果供对照。完整部署显示当前简化版。只包含落地段。L001–L098沿用原编号；新增长矛飞行效果从L099开始。</p><p class="hint">当前编排：空中彗星播放第一剪影（fly），滑行彗星播放第二剪影（slide）；这两组已选素材恢复原版相对位置、旋转和缩放。滑行冲击波与余波保留上一版组合，只将余波接到冲击罩消亡的位置与时刻。长矛重新标记下牌处，取消按拿矛首帧适配。已选“不要”的43层保持停用。</p></header>
<section class="deployment"><h2>完整部署 · 两个视角同步慢放</h2><div class="toolbar"><button data-team="0">蓝方</button><button data-team="1">红方</button><label>实际速度 <select id="speed"><option value="1">¼ 倍速</option><option value="0.5">⅛ 倍速</option><option value="2">½ 倍速</option><option value="4">原速</option></select></label><button id="replay">重播</button><button id="depBack">−1帧</button><button id="depForward">+1帧</button><output id="clock"></output></div><div class="views"><span>左 · 实战俯视近景</span><span>右 · 侧面观察</span></div><video id="deployment" src="media/deploy_blue.mp4" controls loop playsinline preload="metadata" poster="media/deploy_blue.jpg"></video><p>两边来自同一次真实出牌。已放慢为¼倍速，声音静音，避免慢放音频干扰判断。可以暂停、拖动进度或切到⅛倍速。</p></section>
<div class="sticky"><div class="toolbar"><input id="search" placeholder="搜索编号或原版名称，如 L046"><select id="filter"><option value="all">所有内容</option><option value="group">只看__GROUPS__组合成</option><option value="layer">只看__LAYERS__个单层</option><option value="prop">只看长矛 / 人物代理</option></select><span id="count"></span></div><div class="toolbar"><label><input type="checkbox" id="onlyRejected"> 只看已选不要</label><span id="rejectCount"></span><button id="exportChoices">导出清单</button><span id="saveStatus" class="selection-status" role="status">正在读取清单…</span></div></div>
<p class="hint">点开卡片即可播放单层慢放。单层为中性灰底并自动放大，方便辨认，不能用缩略图比较各层实际大小。勾选“不要”会自动保存；组合卡可以整组勾选。选完告诉我“按清单修改”即可。勾选不会即时改变录像；已应用清单的层标记为“已在游戏中停用”，旧单层录像保留作对照。</p><main id="catalog"></main>
<section id="viewer" class="hidden" role="dialog" aria-label="单层特效播放器"><div class="toolbar"><div><span class="tag" id="vid"></span><strong id="vname"></strong></div><button id="close">关闭</button></div><video id="clip" controls loop playsinline></video><p id="vmeta"></p><label class="reject-choice"><input type="checkbox" id="rejectCurrent"> 不要这个效果</label><div class="toolbar"><button id="previous">← 上一项</button><button id="copy">复制编号与名称</button><button id="next">下一项 →</button></div><div class="toolbar"><button id="clipBack">−1帧</button><button id="clipForward">+1帧</button></div><label>单层速度 <select id="clipSpeed"><option value="1">¼ 倍速</option><option value="0.5">⅛ 倍速</option><option value="2">½ 倍速</option><option value="4">原速</option></select></label></section>
<p class="foot">勾选保存在本机审查清单，刷新后保留；不直接改动游戏配置。编号映射保存在 <a href="items.csv">items.csv</a>，全部信息保存在 <a href="manifest.json">manifest.json</a>。细小或不可见层也保留登记，避免遗漏。</p>
<script>const items=__DATA__;const $=s=>document.querySelector(s);let chosen=0,visible=[];const listed=items.filter(x=>x.kind!=='deployment');

let rejected = new Set(listed.filter(i=>i.applied_disabled && i.kind!=='group').map(i=>i.id));
let ready=false, saveChain=Promise.resolve();
const localKey='pantheon-review-rejections-v1';
function targets(item){return item.kind==='group'?listed.filter(i=>i.kind==='layer'&&i.system===item.system):[item]}
function selected(item){return targets(item).every(i=>rejected.has(i.id))}
function refreshChoices(){
 for(const input of document.querySelectorAll('[data-reject]')){
  const item=listed.find(i=>i.id===input.dataset.reject),group=targets(item);
  input.checked=selected(item); input.indeterminate=!input.checked&&group.some(i=>rejected.has(i.id));input.disabled=!ready;
  input.closest('article')?.classList.toggle('rejected',input.checked);
 }
 $('#rejectCount').textContent=`已选不要 ${rejected.size} 项`;
 $('#rejectCurrent').checked=listed.length?selected(listed[chosen]):false;$('#rejectCurrent').disabled=!ready||!listed.length;
}
function saveChoices(){
 const payload={rejected:[...rejected].sort()};
 try{localStorage.setItem(localKey,JSON.stringify(payload))}catch{}
 $('#saveStatus').textContent='正在保存…';
 saveChain=saveChain.catch(()=>{}).then(async()=>{
  try{
   const response=await fetch('/api/selections',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
   if(!response.ok)throw Error('save');await response.json();$('#saveStatus').textContent='已保存';
  }catch{$('#saveStatus').textContent='未写入本机清单，请导出清单留存'}
 });
}
function toggleItem(item,checked){for(const i of targets(item))checked?rejected.add(i.id):rejected.delete(i.id);refreshChoices();saveChoices();if($('#onlyRejected').checked)render()}
function choice(item){const label=document.createElement('label');label.className='reject-choice';const box=document.createElement('input');box.type='checkbox';box.dataset.reject=item.id;box.setAttribute('aria-label',`${item.id} 不要`);box.onchange=()=>toggleItem(item,box.checked);label.append(box,document.createTextNode(item.kind==='group'?'整组不要':'不要'));label.onclick=e=>e.stopPropagation();label.onkeydown=e=>e.stopPropagation();return label}
async function loadChoices(){
 try{const response=await fetch('/api/selections',{cache:'no-store'});if(!response.ok)throw Error('read');const data=await response.json();rejected=new Set(data.rejected);$('#saveStatus').textContent='已读取保存的清单'}
 catch{try{const saved=JSON.parse(localStorage.getItem(localKey));if(saved)rejected=new Set(saved.rejected)}catch{}$('#saveStatus').textContent='离线模式：请导出清单留存'}
 ready=true;render();
}
$('#onlyRejected').onchange=render;
$('#rejectCurrent').onchange=()=>toggleItem(listed[chosen],$('#rejectCurrent').checked);
$('#exportChoices').onclick=()=>{const data={rejected:[...rejected].sort(),items:listed.filter(i=>rejected.has(i.id)).map(i=>({id:i.id,system:i.system,emitter:i.emitter}))};const url=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='pantheon-rejections.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)};

function render(){const query=$('#search').value.toLowerCase();const kind=$('#filter').value;visible=listed.filter(x=>(kind==='all'||x.kind===kind)&&(!$('#onlyRejected').checked||targets(x).some(i=>rejected.has(i.id)))&&[x.id,x.system,x.emitter,x.label].join(' ').toLowerCase().includes(query));$('#count').textContent=`${visible.length} / ${listed.length} 项`;const root=$('#catalog');root.replaceChildren();for(const group of [...new Set(visible.map(x=>x.label))]){const section=document.createElement('details');section.open=true;const heading=document.createElement('summary');heading.textContent=group;section.append(heading);const grid=document.createElement('div');grid.className='grid';section.append(grid);for(const item of visible.filter(x=>x.label===group)){const card=document.createElement('article');card.tabIndex=0;const img=document.createElement('img');img.src=`media/${item.id}.jpg`;img.loading='lazy';img.alt=item.id+' '+item.emitter;card.append(img);const text=document.createElement('div');text.className='text';const tag=document.createElement('span');tag.className='tag';tag.textContent=item.id+' · '+(item.kind==='group'?'组合效果':item.kind==='prop'?'独立对象':'单层');const name=document.createElement('strong');name.textContent=item.emitter||item.system;const meta=document.createElement('small');meta.textContent=`部署 ${item.source_start.toFixed(2)}–${(item.source_start+item.source_duration).toFixed(2)}秒 · ${item.visible_pixels===false?'当前极弱或不可见':'点击慢放'}`;text.append(tag,name,meta);if(item.applied_disabled){const status=document.createElement('p');status.className='applied';status.textContent='已在游戏中停用';text.append(status)}card.append(text);card.append(choice(item));card.onclick=()=>show(listed.indexOf(item));card.onkeydown=e=>{if(e.key==='Enter')card.click()};grid.append(card)}root.append(section)}refreshChoices()}
function show(index){chosen=(index+listed.length)%listed.length;const item=listed[chosen];$('#vid').textContent=item.id+' · '+item.label;$('#vname').textContent=' / '+(item.emitter||'整组合成');$('#vmeta').textContent=`原版系统：${item.system}　｜　部署时间：${item.source_start.toFixed(2)}–${(item.source_start+item.source_duration).toFixed(2)}秒。灰底自动取景，实际大小请对照完整部署。${item.visible_pixels===false?" 此层在当前时段极弱或不可见，仍保留编号供你决定是否移除。":""}`;$('#clip').src=`media/${item.id}.mp4`;$('#clip').poster=`media/${item.id}.jpg`;$('#clip').playbackRate=Number($('#clipSpeed').value);refreshChoices();$('#viewer').classList.remove('hidden');$('#clip').play().catch(()=>{})}
$('#close').onclick=()=>{$('#viewer').classList.add('hidden');$('#clip').pause()};$('#previous').onclick=()=>show(chosen-1);$('#next').onclick=()=>show(chosen+1);$('#copy').onclick=async()=>{const i=listed[chosen];const text=i.id+' '+i.system+'/'+i.emitter;try{await navigator.clipboard.writeText(text);$('#copy').textContent='已复制'}catch{$('#copy').textContent=text}setTimeout(()=>$('#copy').textContent='复制编号与名称',1600)};$('#clipSpeed').onchange=()=>$('#clip').playbackRate=Number($('#clipSpeed').value);$('#search').oninput=render;$('#filter').onchange=render;
const dep=$('#deployment');for(const b of document.querySelectorAll('[data-team]'))b.onclick=()=>{const side=b.dataset.team==='0'?'blue':'red';dep.src=`media/deploy_${side}.mp4`;dep.poster=`media/deploy_${side}.jpg`;dep.playbackRate=Number($('#speed').value);dep.play().catch(()=>{});document.querySelectorAll('[data-team]').forEach(x=>x.style.borderColor=x===b?'#e5c375':'#496353')};$('#depBack').onclick=()=>{dep.pause();dep.currentTime=Math.max(0,dep.currentTime-1/30)};$('#depForward').onclick=()=>{dep.pause();dep.currentTime=Math.min(dep.duration,dep.currentTime+1/30)};$('#clipBack').onclick=()=>{const c=$('#clip');c.pause();c.currentTime=Math.max(0,c.currentTime-1/listed[chosen].fps)};$('#clipForward').onclick=()=>{const c=$('#clip');c.pause();c.currentTime=Math.min(c.duration,c.currentTime+1/listed[chosen].fps)};$('#speed').onchange=()=>dep.playbackRate=Number($('#speed').value);$('#replay').onclick=()=>{dep.currentTime=0;dep.play()};dep.ontimeupdate=()=>$('#clock').textContent=`动作时间约 ${(dep.currentTime*.25).toFixed(2)} 秒`;render();loadChoices();
</script></html>'''.replace('__DATA__', data).replace('__LAYERS__', str(sum(i['kind']=='layer' for i in items))).replace('__GROUPS__', str(sum(i['kind']=='group' for i in items)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise SystemExit('Output must be a new directory')
    manifest = json.loads((args.input/'review_manifest.json').read_text())
    project = Path(__file__).resolve().parents[2]
    paths = ['assets/units/pantheon/r_original/systems.json', 'assets/units/pantheon/arrival/integration.json', 'assets/units/pantheon/arrival/particle_player.gd', 'assets/units/pantheon/pantheon_arrival.gd', 'assets/units/pantheon/pantheon_view.gd', 'assets/units/pantheon/arrival/native_composition.json', 'assets/units/pantheon/arrival/profile.gd', 'assets/units/pantheon/arrival/original_comet.gd']
    manifest['runtime_sha256'] = {path: hashlib.sha256((project/path).read_bytes()).hexdigest() for path in paths}
    manifest['capture_path'] = str(args.input.resolve())
    media = args.output/'media'
    media.mkdir(parents=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        items = list(pool.map(lambda item: encode(item, args.input, media), manifest['items']))
    for team, name in [(0, 'blue'), (1, 'red')]:
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(media/f'D{team}0.mp4'),'-i',str(media/f'D{team}1.mp4'),'-filter_complex','hstack=inputs=2','-an','-c:v','libx264','-crf','19','-preset','fast','-threads','2','-pix_fmt','yuv420p','-movflags','+faststart',str(media/f'deploy_{name}.mp4')],check=True)
        montage=Image.new('RGB',(1920,720))
        for index in range(2):
            with Image.open(media/f'D{team}{index}.jpg') as image:montage.paste(image,(index*960,0))
        montage.save(media/f'deploy_{name}.jpg',quality=92)
    manifest['items'] = items
    (args.output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    profile=json.loads((project/'assets/units/pantheon/arrival/integration.json').read_text())
    disabled=[name for name,phase in profile['systems'].items() if not phase.get('enabled', True)]
    disabled_layers = [key for key, layer in profile['layers'].items() if not layer.get('enabled', True)]
    (args.output/'index.html').write_text(build_page(items, disabled, disabled_layers))
    (args.output/'selections.json').write_text(json.dumps({'version':1,'rejected':[i['id'] for i in items if i['kind']=='layer' and (i['system'] in disabled or i['system']+'/'+i.get('emitter','') in disabled_layers)]},indent=2))
    (args.output/'README.txt').write_text('打开index.html查看。无需网络。完整部署左为实战俯视近景，右为侧面；蓝红可切换。\n全部视频默认已编码为1/4速度；单层灰底自动放大不能用来比较实际尺寸。\nL编号为粒子层（原L001-L098保持；长矛飞行追加L099-L112）；G编号为组合；P01-P03为长矛与人物代理。\n告诉Agent编号与修改/删除意见即可。此审查包不改游戏配置。\n', encoding='utf-8')
    with (args.output/'items.csv').open('w',newline='') as file:
        writer=csv.writer(file);writer.writerow(['编号','分类','系统','发射器/对象','开始','时长'])
        for item in items:writer.writerow([item['id'],item['kind'],item['system'],item.get('emitter',''),item.get('source_start',''),item['source_duration']])
    print('REVIEW_GALLERY',args.output.resolve(),flush=True)


if __name__=='__main__':main()
