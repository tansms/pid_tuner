import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/analysis_service.dart';
import '../models/analysis_result.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = false;
  String _status = "";
  AnalysisResult? _result;
  List<String> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _loadRecentLogs();
  }

  void _loadRecentLogs() {
    // 加载最近分析的日志列表
    setState(() {
      _recentLogs = [
        "3.5寸圈圈机 - 2026-05-12",
        "5寸穿越机 - 2026-05-09",
      ];
    });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bbl', 'bfl', 'csv'],
      );

      if (result != null) {
        String filePath = result.files.single.path!;
        await _analyzeFile(filePath);
      }
    } catch (e) {
      setState(() {
        _status = "选择文件失败: $e";
      });
    }
  }

  Future<void> _analyzeFile(String filePath) async {
    setState(() {
      _isLoading = true;
      _status = "正在解码日志...";
      _result = null;
    });

    try {
      // 解码日志
      List<Map<String, dynamic>> logData = await LogDecoder.decodeBBL(filePath);

      setState(() {
        _status = "正在分析阶跃响应...";
      });

      // 分析数据
      AnalysisResult result = await StepResponseAnalyzer.analyze(logData);

      setState(() {
        _result = result;
        _status = "分析完成";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = "分析失败: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("PID调参助手"),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              _showGuide(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上传区域
            _buildUploadSection(),
            SizedBox(height: 24),

            // 状态显示
            if (_status.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (_isLoading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (!_isLoading)
                        Icon(_result != null ? Icons.check_circle : Icons.error,
                            color: _result != null ? Colors.green : Colors.red),
                      SizedBox(width: 12),
                      Expanded(child: Text(_status)),
                    ],
                  ),
                ),
              ),

            // 分析结果
            if (_result != null) ...[
              SizedBox(height: 16),
              _buildResultSection(),
              SizedBox(height: 16),
              _buildRecommendationSection(),
            ],

            // 最近分析
            if (_recentLogs.isNotEmpty) ...[
              SizedBox(height: 24),
              Text("最近分析", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              ..._recentLogs.map((log) => Card(
                child: ListTile(
                  leading: Icon(Icons.flight),
                  title: Text(log),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Card(
      child: InkWell(
        onTap: _isLoading ? null : _pickFile,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.upload_file, size: 48, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                "点击上传黑盒日志",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "支持 .bbl / .bfl / .csv 格式",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("分析结果", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Table(
              children: [
                TableRow(
                  children: [
                    Text("指标", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Roll", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Pitch", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("状态", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                TableRow(
                  children: [
                    Text("超调"),
                    Text("${_result!.rollOvershoot.toStringAsFixed(1)}%"),
                    Text("${_result!.pitchOvershoot.toStringAsFixed(1)}%"),
                    Icon(
                      _result!.isRollGood() && _result!.isPitchGood()
                          ? Icons.check_circle
                          : Icons.warning,
                      color: _result!.isRollGood() && _result!.isPitchGood()
                          ? Colors.green
                          : Colors.orange,
                      size: 20,
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Text("上升时间"),
                    Text("${_result!.rollRiseTime.toStringAsFixed(0)}ms"),
                    Text("${_result!.pitchRiseTime.toStringAsFixed(0)}ms"),
                    Text("-"),
                  ],
                ),
                TableRow(
                  children: [
                    Text("稳态值"),
                    Text(_result!.rollSteadyState.toStringAsFixed(2)),
                    Text(_result!.pitchSteadyState.toStringAsFixed(2)),
                    Text("-"),
                  ],
                ),
                TableRow(
                  children: [
                    Text("分析段数"),
                    Text("${_result!.rollSegments}"),
                    Text("${_result!.pitchSegments}"),
                    Text("-"),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("参数建议", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result!.getRecommendation(),
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 16),
            Text("CLI 命令:", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                fontFamily: 'monospace',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _result!.getCLICommands()
                    .map((cmd) => Text(cmd))
                    .toList(),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                // 复制到剪贴板
              },
              icon: Icon(Icons.copy),
              label: Text("复制命令"),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("调参流程"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("1. 机械检查", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("   检查螺丝、电机、桨叶"),
              SizedBox(height: 8),
              Text("2. 调滤波器", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("   分析频谱，设置陷波"),
              SizedBox(height: 8),
              Text("3. 调 PID", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("   D → P → FF → I"),
              SizedBox(height: 8),
              Text("口诀:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("机械先行，P打基础"),
              Text("D控过冲，FF追跟随"),
              Text("I保稳定，滤波最后动"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("知道了"),
          ),
        ],
      ),
    );
  }
}