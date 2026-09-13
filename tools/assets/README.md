# 源素材工具

返回 [工具索引](../README.md)。默认只读源库为 `/Users/czh/Downloads/LOL_Asset_Source`；其他路径用 `source --source /绝对路径`，放在子命令前。

## 查找与提取

```sh
python3 tools/dev.py source packages --query Garen
python3 tools/dev.py source inspect --package Garen --kind model --pattern 'skins/base/'
python3 tools/dev.py source inspect --package Garen --kind card-art
python3 tools/dev.py source inspect --package Garen --kind effects
python3 tools/dev.py source inspect --package Garen --kind audio
```

`--kind` 是路径筛选提示，不保证包内具有该类内容。语音可能在语言包，卡面可能在客户端游戏数据包；先 `packages --query` 找对应包。`--package` 可填唯一包名或源库内相对路径。

```sh
python3 tools/dev.py source extract --package Garen --pattern 'assets/characters/garen/skins/base/' --output builds/garen-source
# 核对输出清单后，添加 --write 才会实际提取。
```

也可重复 `--path` 精确选择文件。模型要一起选择骨骼、所需动画与材质纹理；特效要保留其引用的纹理和其他依赖。输出必须是新目录，会带 `source_manifest.json` 记录源包和文件校验值。

## 转换

以下路径是输入占位示例，按提取清单替换；输出必须是新文件。

```sh
python3 tools/dev.py source convert --format texture --input /tmp/source/body.tex --output builds/body.png
python3 tools/dev.py source convert --format model --input /tmp/source/body.skn --skeleton /tmp/source/body.skl --animations /tmp/source/animations --texture Body=builds/body.png --output builds/body.glb
python3 tools/dev.py source convert --format bin --input /tmp/source/skin0.bin --output builds/skin0.ritobin
python3 tools/dev.py source convert --format audio --input /tmp/source/voice.wem --output builds/voice.wav
```

材质名必须与模型匹配；多材质重复 `--texture 名称=纹理路径`。每个转换结果附 `.source.json` 来源记录。模型用 `lol2gltf`，纹理用 `ltk-tex-utils`，定义用 `ritobin-tools`，声音用 `vgmstream-cli`。

BNK/WPK 的完整事件还原用 [音频准备工具](../audio/README.md)。特效 BIN 转换只得到可阅读定义，**不会自动生成 Godot 特效**；原版卡面通常只需提取或纹理解码。

## 专门配方

`import_turret_break_animations.py` 是塔破碎动画加工；`export_princess_tower_ruin.py` 是 Blender 废墟导出。两者针对已有塔素材，运行前核对脚本内输入、输出和 [塔说明](../../docs/units/princess_tower.md)。不作为新单位的通用导入器。
