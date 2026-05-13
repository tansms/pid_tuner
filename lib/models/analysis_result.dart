import 'package:flutter/material.dart';

class AnalysisResult {
  final double rollOvershoot;
  final double pitchOvershoot;
  final double rollRiseTime;
  final double pitchRiseTime;
  final double rollSteadyState;
  final double pitchSteadyState;
  final double rollPeakValue;
  final double pitchPeakValue;
  final int rollSegments;
  final int pitchSegments;
  final String status;

  AnalysisResult({
    required this.rollOvershoot,
    required this.pitchOvershoot,
    required this.rollRiseTime,
    required this.pitchRiseTime,
    required this.rollSteadyState,
    required this.pitchSteadyState,
    required this.rollPeakValue,
    required this.pitchPeakValue,
    required this.rollSegments,
    required this.pitchSegments,
    required this.status,
  });

  bool isRollGood() => rollOvershoot < 10;
  bool isPitchGood() => pitchOvershoot < 10;

  String getRecommendation() {
    if (rollOvershoot > 15 || pitchOvershoot > 15) {
      return "超调过高，建议增加D值";
    }
    if (rollOvershoot > 10 || pitchOvershoot > 10) {
      return "超调略高，可微调D或降P";
    }
    if (rollRiseTime > 150 || pitchRiseTime > 150) {
      return "响应偏慢，可增加FF值";
    }
    return "PID配置良好";
  }

  List<String> getCLICommands() {
    List<String> commands = [];

    if (rollOvershoot > 10) {
      double newD = 45;
      commands.add("set d_roll = ${newD.toInt()}");
    }
    if (pitchOvershoot > 10) {
      double newD = 45;
      commands.add("set d_pitch = ${newD.toInt()}");
    }

    if (commands.isEmpty) {
      commands.add("当前PID配置良好");
    } else {
      commands.add("profile save");
    }

    return commands;
  }
}