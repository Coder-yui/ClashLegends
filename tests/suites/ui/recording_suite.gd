class_name RecordingSuite
extends RefCounted
## 无编码器依赖的有界队列、停止边界与视频契约；实际编码由 recording_smoke 验收。
const OPTIONS := preload("res://scripts/recording/recording_options.gd")
const ENCODER := preload("res://scripts/recording/recording_encoder.gd")

func run(harness: Object) -> void:
	var options := OPTIONS.new()
	options.directory = "/recording-test"
	for index in OPTIONS.PRESETS.size():
		options.preset = index
		var spec := options.session_spec()
		harness._expect(spec.size.x * 16 == spec.size.y * 9, "录像档位固定9:16")
		harness._expect(spec.fps in [30, 60] and spec.path.ends_with(".mp4"), "录像帧率与MP4输出契约")
		var args := ENCODER.video_arguments(spec, "/partial.mp4")
		harness._expect(args[args.find("-video_size") + 1] == "%dx%d" % [spec.size.x, spec.size.y], "编码尺寸来自成片档位")
		harness._expect("-n" in args and args[args.find("-pix_fmt") + 1] == "yuv420p", "编码不覆盖文件且使用兼容像素格式")
	options.directory = "relative/path"
	harness._expect(not options.validate().is_empty(), "无效保存位置不能开始录制")
	var encoder := ENCODER.new()
	for index in ENCODER.MAX_VIDEO_QUEUE:
		harness._expect(encoder.room_for_frame(), "有界帧队列接受可用槽位")
		encoder.submit_frame(PackedByteArray([index]), index)
	harness._expect(not encoder.room_for_frame(), "帧队列满时拒绝继续抓屏，不持续增长内存")
	encoder.submit_frame(PackedByteArray([99]), 99)
	harness._expect(encoder._video.size() == ENCODER.MAX_VIDEO_QUEUE, "拥堵时重复提交也不能越界")
	var audio := PackedByteArray()
	audio.resize(ENCODER.MAX_AUDIO_BYTES)
	harness._expect(encoder.submit_audio(audio), "音频缓冲接受上限以内数据")
	harness._expect(not encoder.submit_audio(PackedByteArray([1])), "音频队列溢出交给录制器停止，不静默丢音")
	encoder.finish(90)
	harness._expect(not encoder.room_for_frame() and not encoder.submit_audio(PackedByteArray([1])), "收尾期间不再接受视频与音频")
	harness._expect(encoder._end_frame == 90 and encoder._video.size() == ENCODER.MAX_VIDEO_QUEUE, "收尾保留已排队帧及真实结束时间")
	encoder.abort("test cancellation")
	harness._expect(encoder._is_aborted() and encoder.snapshot().error == "test cancellation", "取消保留明确失败原因")
