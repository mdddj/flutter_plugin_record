import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_plugin_record/flutter_plugin_record.dart';
import 'package:flutter_plugin_record/utils/common_toast.dart';

import 'custom_overlay.dart';

// typedef startRecord = Future Function();
// typedef stopRecord = Future Function();
typedef VoiceWidgetBuilder = Widget Function(String text, Widget defaultChild);

class VoiceWidget extends StatefulWidget {
  final Function? startRecord;
  final void Function(String? filepath, double? len)? stopRecord;
  final double? height;
  final EdgeInsets? margin;
  final Decoration? decoration;
  final double cancelHeight; //向上滑动触发取消发生高度,默认手指向上滑动30表示关闭
  final VoiceWidgetBuilder builder;
  final int duration; //最大录制时长

  /// startRecord 开始录制回调  stopRecord回调
  const VoiceWidget(
      {super.key,
      this.startRecord,
      this.stopRecord,
      this.height,
      this.decoration,
      this.cancelHeight = 30,
      required this.builder,
      this.margin,
      this.duration = 30});

  @override
  _VoiceWidgetState createState() => _VoiceWidgetState();
}

class _VoiceWidgetState extends State<VoiceWidget> {
  // 倒计时总时长
  late final int _countTotal = widget.duration;
  double starty = 0.0;
  double offset = 0.0;
  bool isUp = false;
  String textShow = "按住说话";
  String toastShow = "手指上滑,取消发送";
  String voiceIco = "images/voice_volume_1.png";

  ///默认隐藏状态
  bool voiceState = true;
  FlutterPluginRecord recordPlugin = FlutterPluginRecord();
  Timer? _timer;
  int _count = 0;
  OverlayEntry? overlayEntry;

  @override
  void initState() {
    super.initState();
    debugPrint("_count :${widget.duration}");
    _init();

    ///初始化方法的监听
    recordPlugin.responseFromInit.listen((data) {
      if (data) {
        debugPrint("初始化成功");
      } else {
        debugPrint("初始化失败");
      }
    });

    /// 开始录制或结束录制的监听
    recordPlugin.response.listen((data) {
      if (data.msg == "onStop") {
        ///结束录制时会返回录制文件的地址方便上传服务器
        debugPrint("onStop  ${data.path!}");
        widget.stopRecord?.call(data.path, data.audioTimeLength);
      } else if (data.msg == "onStart") {
        debugPrint("onStart --");
        if (widget.startRecord != null) widget.startRecord!();
      }
    });

    ///录制过程监听录制的声音的大小 方便做语音动画显示图片的样式
    recordPlugin.responseFromAmplitude.listen((data) {
      var voiceData = double.parse(data.msg ?? '');
      setState(() {
        if (voiceData > 0 && voiceData < 0.1) {
          voiceIco = "images/voice_volume_2.png";
        } else if (voiceData > 0.2 && voiceData < 0.3) {
          voiceIco = "images/voice_volume_3.png";
        } else if (voiceData > 0.3 && voiceData < 0.4) {
          voiceIco = "images/voice_volume_4.png";
        } else if (voiceData > 0.4 && voiceData < 0.5) {
          voiceIco = "images/voice_volume_5.png";
        } else if (voiceData > 0.5 && voiceData < 0.6) {
          voiceIco = "images/voice_volume_6.png";
        } else if (voiceData > 0.6 && voiceData < 0.7) {
          voiceIco = "images/voice_volume_7.png";
        } else if (voiceData > 0.7 && voiceData < 1) {
          voiceIco = "images/voice_volume_7.png";
        } else {
          voiceIco = "images/voice_volume_1.png";
        }
        if (overlayEntry != null) {
          overlayEntry!.markNeedsBuild();
        }
      });

      debugPrint("振幅大小   $voiceData  $voiceIco");
    });
  }

  ///显示录音悬浮布局
  buildOverLayView(BuildContext context) {
    if (overlayEntry == null) {
      overlayEntry = OverlayEntry(builder: (content) {
        debugPrint("total:$_countTotal   count:$_count");
        return CustomOverlay(
          icon: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: _countTotal - _count < 11
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 15.0),
                            child: Text(
                              (_countTotal - _count).toString(),
                              style: TextStyle(
                                fontSize: 70.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : Image.asset(
                          voiceIco,
                          width: 100,
                          height: 100,
                          package: 'flutter_plugin_record',
                        ),
                ),
                Text(
                  toastShow,
                  style: TextStyle(
                    fontStyle: FontStyle.normal,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                )
              ],
            ),
          ),
        );
      });
      Overlay.of(context).insert(overlayEntry!);
    }
  }

  showVoiceView() {
    setState(() {
      textShow = "松开结束";
      voiceState = false;
    });

    ///显示录音悬浮布局
    buildOverLayView(context);

    start();
  }

  hideVoiceView() {
    if (_timer!.isActive) {
      if (_count < 1) {
        CommonToast.showView(
            context: context,
            msg: '说话时间太短',
            icon: Text(
              '!',
              style: TextStyle(fontSize: 80, color: Colors.white),
            ));
        isUp = true;
      }
      _timer?.cancel();
      _count = 0;
    }

    setState(() {
      textShow = "按住说话";
      voiceState = true;
    });

    stop();
    if (overlayEntry != null) {
      overlayEntry?.remove();
      overlayEntry = null;
    }

    if (isUp) {
      debugPrint("取消发送");
    } else {
      debugPrint("进行发送");
    }
  }

  moveVoiceView() {
    // print(offset - start);
    setState(() {
      isUp = starty - offset > widget.cancelHeight ? true : false;
      if (isUp) {
        textShow = "松开手指,取消发送";
        toastShow = textShow;
      } else {
        textShow = "松开结束";
        toastShow = "手指上滑,取消发送";
      }
    });
  }

  ///初始化语音录制的方法
  void _init() async {
    recordPlugin.init();
  }

  ///开始语音录制的方法
  void start() async {
    recordPlugin.start();
  }

  ///停止语音录制的方法
  void stop() {
    recordPlugin.stop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onLongPressStart: (details) {
          starty = details.globalPosition.dy;
          _timer = Timer.periodic(Duration(milliseconds: 1000), (t) {
            _count++;
            debugPrint('_count is 👉 $_count');
            if (_count == _countTotal) {
              hideVoiceView();
            }
          });
          showVoiceView();
        },
        onLongPressEnd: (details) {
          hideVoiceView();
        },
        onLongPressMoveUpdate: (details) {
          offset = details.globalPosition.dy;
          moveVoiceView();
        },
        child:
            widget.builder.call(textShow, DefaultVoiceWidget(text: textShow)));
  }

  @override
  void dispose() {
    recordPlugin.dispose();
    _timer?.cancel();
    super.dispose();
  }
}

class DefaultVoiceWidget extends StatelessWidget {
  final String text;

  const DefaultVoiceWidget({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(width: 1.0, color: Colors.grey.shade200),
      ),
      margin: EdgeInsets.fromLTRB(50, 0, 50, 20),
      child: Center(
        child: Text(
          text,
        ),
      ),
    );
  }
}
