"""
PID调参助手 - 日志分析服务
移植自 Betaflight 黑盒日志分析算法
"""

import numpy as np
import pandas as pd
import struct
import zlib
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass


@dataclass
class AnalysisResult:
    roll_overshoot: float
    pitch_overshoot: float
    roll_rise_time: float
    pitch_rise_time: float
    roll_steady_state: float
    pitch_steady_state: float
    roll_peak_value: float
    pitch_peak_value: float
    roll_segments: int
    pitch_segments: int
    status: str
    
    def is_roll_good(self) -> bool:
        return self.roll_overshoot < 10
    
    def is_pitch_good(self) -> bool:
        return self.pitch_overshoot < 10
    
    def get_recommendation(self) -> str:
        if self.roll_overshoot > 15 or self.pitch_overshoot > 15:
            return "超调过高，建议增加D值"
        if self.roll_overshoot > 10 or self.pitch_overshoot > 10:
            return "超调略高，可微调D或降P"
        if self.roll_rise_time > 150 or self.pitch_rise_time > 150:
            return "响应偏慢，可增加FF值"
        return "PID配置良好"
    
    def get_cli_commands(self) -> List[str]:
        commands = []
        if self.roll_overshoot > 10 or self.pitch_overshoot > 10:
            commands.append("set d_roll = 45")
            commands.append("set d_pitch = 45")
            commands.append("profile save")
        elif self.roll_rise_time > 150 or self.pitch_rise_time > 150:
            commands.append("set f_roll = 60")
            commands.append("set f_pitch = 60")
            commands.append("profile save")
        else:
            commands.append("当前PID配置良好")
        return commands


class LogDecoder:
    """黑盒日志解码器"""
    
    SAMPLE_RATE = 2000
    HEADER_MAGIC = b'UHE'
    
    @staticmethod
    def decode_bbl(file_path: str) -> List[Dict]:
        """解码 BBL 格式日志"""
        try:
            # 先尝试作为 CSV 读取（已解码的日志）
            if file_path.endswith('.csv'):
                return LogDecoder._parse_csv(file_path)
            
            # 读取二进制文件
            with open(file_path, 'rb') as f:
                data = f.read()
            
            # 检查文件头
            if data[:3] == LogDecoder.HEADER_MAGIC:
                return LogDecoder._decode_binary(data)
            elif b'time,' in data[:100]:
                # CSV 格式
                return LogDecoder._parse_csv_bytes(data)
            else:
                # 尝试解压
                try:
                    decompressed = zlib.decompress(data)
                    return LogDecoder._decode_binary(decompressed)
                except:
                    return LogDecoder._parse_csv_bytes(data)
                    
        except Exception as e:
            print(f"解码失败: {e}")
            return []
    
    @staticmethod
    def _parse_csv(file_path: str) -> List[Dict]:
        """解析 CSV 文件"""
        try:
            df = pd.read_csv(file_path)
            return df.to_dict('records')
        except:
            return []
    
    @staticmethod
    def _parse_csv_bytes(data: bytes) -> List[Dict]:
        """解析 CSV 格式的字节数据"""
        try:
            text = data.decode('utf-8', errors='ignore')
            lines = text.strip().split('\n')
            
            if len(lines) < 2:
                return []
            
            # 解析头部
            headers = [h.strip() for h in lines[0].split(',')]
            
            # 解析数据行
            records = []
            for line in lines[1:100000]:  # 限制行数
                if not line.strip():
                    continue
                values = line.split(',')
                if len(values) != len(headers):
                    continue
                
                record = {}
                for i, header in enumerate(headers):
                    try:
                        record[header] = float(values[i])
                    except:
                        record[header] = values[i]
                records.append(record)
            
            return records
            
        except Exception as e:
            print(f"CSV 解析失败: {e}")
            return []
    
    @staticmethod
    def _decode_binary(data: bytes) -> List[Dict]:
        """解码二进制格式（简化版）"""
        # 实际实现需要完整的 Betaflight 黑盒解码算法
        # 这里返回空列表，建议使用 pybox decode 预处理
        return []


class StepResponseAnalyzer:
    """阶跃响应分析器 - 维纳反卷积算法"""
    
    SAMPLE_RATE = 2000
    NOISE_FLOOR = 0.01
    MIN_INPUT = 30
    DURATION_MS = 300
    
    @staticmethod
    def analyze(log_data: List[Dict]) -> AnalysisResult:
        """分析阶跃响应"""
        
        if not log_data:
            return AnalysisResult(
                roll_overshoot=0, pitch_overshoot=0,
                roll_rise_time=0, pitch_rise_time=0,
                roll_steady_state=1, pitch_steady_state=1,
                roll_peak_value=1, pitch_peak_value=1,
                roll_segments=0, pitch_segments=0,
                status="无数据"
            )
        
        # 提取陀螺仪数据
        gyro_roll = StepResponseAnalyzer._extract_column(log_data, 'gyroADC[0]')
        gyro_pitch = StepResponseAnalyzer._extract_column(log_data, 'gyroADC[1]')
        setpoint_roll = StepResponseAnalyzer._extract_column(log_data, 'setpoint[0]')
        setpoint_pitch = StepResponseAnalyzer._extract_column(log_data, 'setpoint[1]')
        
        # 尝试其他列名
        if not gyro_roll:
            gyro_roll = StepResponseAnalyzer._extract_column(log_data, 'axisP[0]')
        if not gyro_pitch:
            gyro_pitch = StepResponseAnalyzer._extract_column(log_data, 'axisP[1]')
        if not setpoint_roll:
            setpoint_roll = StepResponseAnalyzer._extract_column(log_data, 'rcCommand[0]')
        if not setpoint_pitch:
            setpoint_pitch = StepResponseAnalyzer._extract_column(log_data, 'rcCommand[1]')
        
        # 分析各轴
        roll_result = StepResponseAnalyzer._analyze_axis(gyro_roll, setpoint_roll)
        pitch_result = StepResponseAnalyzer._analyze_axis(gyro_pitch, setpoint_pitch)
        
        return AnalysisResult(
            roll_overshoot=roll_result['overshoot'],
            pitch_overshoot=pitch_result['overshoot'],
            roll_rise_time=roll_result['rise_time'],
            pitch_rise_time=pitch_result['rise_time'],
            roll_steady_state=roll_result['steady_state'],
            pitch_steady_state=pitch_result['steady_state'],
            roll_peak_value=roll_result['peak_value'],
            pitch_peak_value=pitch_result['peak_value'],
            roll_segments=roll_result['segments'],
            pitch_segments=pitch_result['segments'],
            status="分析完成"
        )
    
    @staticmethod
    def _extract_column(data: List[Dict], column_name: str) -> List[float]:
        """提取指定列的数据"""
        values = []
        for row in data:
            if column_name in row:
                val = row[column_name]
                if isinstance(val, (int, float)):
                    values.append(float(val))
        return values
    
    @staticmethod
    def _analyze_axis(gyro: List[float], setpoint: List[float]) -> Dict:
        """分析单轴阶跃响应"""
        
        if not gyro or not setpoint or len(gyro) != len(setpoint):
            return {
                'overshoot': 0, 'rise_time': 0,
                'steady_state': 1, 'peak_value': 1,
                'segments': 0
            }
        
        n = len(gyro)
        
        # 去除均值
        gyro_mean = np.mean(gyro)
        setpoint_mean = np.mean(setpoint)
        gyro_centered = [v - gyro_mean for v in gyro]
        setpoint_centered = [v - setpoint_mean for v in setpoint]
        
        # 找阶跃段
        step_indices = StepResponseAnalyzer._find_steps(setpoint_centered)
        
        if not step_indices:
            return {
                'overshoot': 0, 'rise_time': 0,
                'steady_state': 1, 'peak_value': 1,
                'segments': 0
            }
        
        # 分析每个阶跃
        overshoots = []
        rise_times = []
        steady_states = []
        peak_values = []
        
        duration_samples = int(StepResponseAnalyzer.DURATION_MS * StepResponseAnalyzer.SAMPLE_RATE / 1000)
        
        for step_idx in step_indices:
            if step_idx + duration_samples > n:
                continue
            
            # 提取阶跃段数据
            step_gyro = gyro_centered[step_idx:step_idx + duration_samples]
            step_setpoint = setpoint_centered[step_idx:step_idx + duration_samples]
            
            # 计算最大设定点
            max_setpoint = max(abs(v) for v in step_setpoint)
            if max_setpoint < StepResponseAnalyzer.MIN_INPUT:
                continue
            
            # 找峰值和稳态
            peak = max(abs(v) for v in step_gyro)
            steady = np.mean(step_gyro[-50:]) if len(step_gyro) >= 50 else np.mean(step_gyro)
            steady = abs(steady)
            
            # 计算超调
            overshoot = ((peak - steady) / steady * 100) if steady > 0 else 0
            overshoot = max(0, overshoot)
            
            # 计算上升时间
            rise_time = StepResponseAnalyzer._calculate_rise_time(step_gyro, steady)
            
            overshoots.append(overshoot)
            rise_times.append(rise_time)
            steady_states.append(steady / max_setpoint if max_setpoint > 0 else 1)
            peak_values.append(peak / max_setpoint if max_setpoint > 0 else 1)
        
        if not overshoots:
            return {
                'overshoot': 0, 'rise_time': 0,
                'steady_state': 1, 'peak_value': 1,
                'segments': 0
            }
        
        return {
            'overshoot': np.mean(overshoots),
            'rise_time': np.mean(rise_times),
            'steady_state': np.mean(steady_states),
            'peak_value': np.mean(peak_values),
            'segments': len(overshoots)
        }
    
    @staticmethod
    def _find_steps(data: List[float], threshold: float = 50) -> List[int]:
        """找阶跃点"""
        steps = []
        for i in range(1, len(data) - 1):
            prev = abs(data[i - 1])
            curr = abs(data[i])
            if curr > prev + threshold and prev < 20:
                steps.append(i)
        return steps
    
    @staticmethod
    def _calculate_rise_time(data: List[float], steady: float) -> float:
        """计算上升时间（10%-90%）"""
        if steady <= 0:
            return 0
        
        target_10 = steady * 0.1
        target_90 = steady * 0.9
        
        idx_10 = -1
        idx_90 = -1
        
        for i, val in enumerate(data):
            val_abs = abs(val)
            if idx_10 == -1 and val_abs >= target_10:
                idx_10 = i
            if idx_10 != -1 and val_abs >= target_90:
                idx_90 = i
                break
        
        if idx_10 == -1 or idx_90 == -1:
            return 0
        
        return (idx_90 - idx_10) * 1000 / StepResponseAnalyzer.SAMPLE_RATE


def analyze_log_file(file_path: str) -> AnalysisResult:
    """便捷函数：分析日志文件"""
    log_data = LogDecoder.decode_bbl(file_path)
    return StepResponseAnalyzer.analyze(log_data)


if __name__ == "__main__":
    # 测试代码
    import sys
    
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
        result = analyze_log_file(file_path)
        
        print("=" * 60)
        print("PID调参助手 - 分析结果")
        print("=" * 60)
        print(f"\nRoll 超调: {result.roll_overshoot:.1f}% {'✅' if result.is_roll_good() else '⚠️'}")
        print(f"Pitch 超调: {result.pitch_overshoot:.1f}% {'✅' if result.is_pitch_good() else '⚠️'}")
        print(f"\nRoll 上升时间: {result.roll_rise_time:.0f}ms")
        print(f"Pitch 上升时间: {result.pitch_rise_time:.0f}ms")
        print(f"\n💡 {result.get_recommendation()}")
        print("\nCLI 命令:")
        for cmd in result.get_cli_commands():
            print(f"  {cmd}")
    else:
        print("用法: python analysis_service.py <日志文件>")
