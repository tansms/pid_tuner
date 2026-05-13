import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
}

class LogDecoder {
  static Future<List<Map<String, dynamic>>> decodeBBL(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // 简化解码：假设已经是CSV格式或需要转换
    // 实际BBL解码需要更复杂的逻辑

    return _parseLogBytes(bytes);
  }

  static List<Map<String, dynamic>> _parseLogBytes(Uint8List bytes) {
    // 这里实现简化的日志解析
    // 实际需要完整的黑盒解码算法

    List<Map<String, dynamic>> data = [];

    // 尝试解析为CSV
    String content = String.fromCharCodes(bytes);
    if (content.contains('time,')) {
      // CSV格式
      data = _parseCSV(content);
    }

    return data;
  }

  static List<Map<String, dynamic>> _parseCSV(String content) {
    List<Map<String, dynamic>> data = [];
    List<String> lines = content.split('\n');

    if (lines.isEmpty) return data;

    // 解析头部
    List<String> headers = lines[0].split(',');

    // 解析数据行
    for (int i = 1; i < lines.length && i < 100000; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;

      List<String> values = line.split(',');
      Map<String, dynamic> row = {};

      for (int j = 0; j < headers.length && j < values.length; j++) {
        String header = headers[j].trim();
        String value = values[j].trim();

        // 转换数值
        double? numValue = double.tryParse(value);
        row[header] = numValue ?? value;
      }

      data.add(row);
    }

    return data;
  }
}

class StepResponseAnalyzer {
  static final int sampleRate = 2000;
  static final double noiseFloor = 0.01;
  static final int minInput = 30;
  static final int durationMs = 300;

  static Future<AnalysisResult> analyze(List<Map<String, dynamic>> logData) async {
    if (logData.isEmpty) {
      return AnalysisResult(
        rollOvershoot: 0,
        pitchOvershoot: 0,
        rollRiseTime: 0,
        pitchRiseTime: 0,
        rollSteadyState: 1,
        pitchSteadyState: 1,
        rollPeakValue: 1,
        pitchPeakValue: 1,
        rollSegments: 0,
        pitchSegments: 0,
        status: "无数据",
      );
    }

    // 提取陀螺仪数据
    List<double> gyroRoll = _extractColumn(logData, 'gyroADC[0]');
    List<double> gyroPitch = _extractColumn(logData, 'gyroADC[1]');
    List<double> setpointRoll = _extractColumn(logData, 'setpoint[0]');
    List<double> setpointPitch = _extractColumn(logData, 'setpoint[1]');

    if (gyroRoll.isEmpty || setpointRoll.isEmpty) {
      // 尝试其他列名
      gyroRoll = _extractColumn(logData, 'axisP[0]');
      gyroPitch = _extractColumn(logData, 'axisP[1]');
      setpointRoll = _extractColumn(logData, 'rcCommand[0]');
      setpointPitch = _extractColumn(logData, 'rcCommand[1]');
    }

    // 分析阶跃响应
    Map<String, dynamic> rollResult = _analyzeAxis(gyroRoll, setpointRoll);
    Map<String, dynamic> pitchResult = _analyzeAxis(gyroPitch, setpointPitch);

    return AnalysisResult(
      rollOvershoot: rollResult['overshoot'] ?? 0,
      pitchOvershoot: pitchResult['overshoot'] ?? 0,
      rollRiseTime: rollResult['riseTime'] ?? 0,
      pitchRiseTime: pitchResult['riseTime'] ?? 0,
      rollSteadyState: rollResult['steadyState'] ?? 1,
      pitchSteadyState: pitchResult['steadyState'] ?? 1,
      rollPeakValue: rollResult['peakValue'] ?? 1,
      pitchPeakValue: pitchResult['peakValue'] ?? 1,
      rollSegments: rollResult['segments'] ?? 0,
      pitchSegments: pitchResult['segments'] ?? 0,
      status: "分析完成",
    );
  }

  static List<double> _extractColumn(List<Map<String, dynamic>> data, String columnName) {
    List<double> values = [];
    for (var row in data) {
      var value = row[columnName];
      if (value is double) {
        values.add(value);
      } else if (value is int) {
        values.add(value.toDouble());
      }
    }
    return values;
  }

  static Map<String, dynamic> _analyzeAxis(List<double> gyro, List<double> setpoint) {
    if (gyro.isEmpty || setpoint.isEmpty || gyro.length != setpoint.length) {
      return {'overshoot': 0, 'riseTime': 0, 'steadyState': 1, 'peakValue': 1, 'segments': 0};
    }

    // 维纳反卷积阶跃响应分析
    int n = gyro.length;

    // 预处理：去除均值
    double gyroMean = _calculateMean(gyro);
    double setpointMean = _calculateMean(setpoint);

    List<double> gyroCentered = gyro.map((v) => v - gyroMean).toList();
    List<double> setpointCentered = setpoint.map((v) => v - setpointMean).toList();

    // 找阶跃段
    List<int> stepIndices = _findSteps(setpointCentered);

    if (stepIndices.isEmpty) {
      return {'overshoot': 0, 'riseTime': 0, 'steadyState': 1, 'peakValue': 1, 'segments': 0};
    }

    // 分析每个阶跃
    List<double> overshoots = [];
    List<double> riseTimes = [];
    List<double> steadyStates = [];
    List<double> peakValues = [];

    int durationSamples = (durationMs * sampleRate / 1000).round();

    for (int stepIdx in stepIndices) {
      if (stepIdx + durationSamples > n) continue;

      // 提取阶跃段数据
      List<double> stepGyro = gyroCentered.sublist(stepIdx, stepIdx + durationSamples);
      List<double> stepSetpoint = setpointCentered.sublist(stepIdx, stepIdx + durationSamples);

      // 计算阶跃响应
      double maxSetpoint = stepSetpoint.reduce(max).abs();
      if (maxSetpoint < minInput) continue;

      // 找峰值和稳态
      double peak = stepGyro.reduce((a, b) => a.abs() > b.abs() ? a : b).abs();
      double steady = _calculateMean(stepGyro.sublist(durationSamples - 50, durationSamples)).abs();

      // 计算超调
      double overshoot = peak > steady ? ((peak - steady) / steady * 100) : 0;

      // 计算上升时间 (10%-90%)
      double riseTime = _calculateRiseTime(stepGyro, steady);

      overshoots.add(overshoot);
      riseTimes.add(riseTime);
      steadyStates.add(steady / maxSetpoint);
      peakValues.add(peak / maxSetpoint);
    }

    if (overshoots.isEmpty) {
      return {'overshoot': 0, 'riseTime': 0, 'steadyState': 1, 'peakValue': 1, 'segments': 0};
    }

    return {
      'overshoot': _calculateMean(overshoots),
      'riseTime': _calculateMean(riseTimes),
      'steadyState': _calculateMean(steadyStates),
      'peakValue': _calculateMean(peakValues),
      'segments': overshoots.length,
    };
  }

  static List<int> _findSteps(List<double> data) {
    List<int> steps = [];
    double threshold = 50; // 阶跃阈值

    for (int i = 1; i < data.length - 1; i++) {
      double prev = data[i - 1].abs();
      double curr = data[i].abs();

      if (curr > prev + threshold && prev < 20) {
        steps.add(i);
      }
    }

    return steps;
  }

  static double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _calculateRiseTime(List<double> data, double steady) {
    if (steady == 0) return 0;

    double target10 = steady * 0.1;
    double target90 = steady * 0.9;

    int idx10 = -1;
    int idx90 = -1;

    for (int i = 0; i < data.length; i++) {
      double val = data[i].abs();
      if (idx10 == -1 && val >= target10) {
        idx10 = i;
      }
      if (idx10 != -1 && val >= target90) {
        idx90 = i;
        break;
      }
    }

    if (idx10 == -1 || idx90 == -1) return 0;

    return (idx90 - idx10) * 1000 / sampleRate;
  }
}