import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import threading
import sys
import os

# 添加 PyBox 路径
sys.path.insert(0, r'C:\PyBox')

class PIDTunerApp:
    def __init__(self, root):
        self.root = root
        self.root.title("PID调参助手 v1.0")
        self.root.geometry("600x700")
        
        self.setup_ui()
        
    def setup_ui(self):
        # 标题
        title = tk.Label(self.root, text="PID调参助手", font=("Arial", 24, "bold"))
        title.pack(pady=20)
        
        # 上传按钮
        upload_frame = tk.Frame(self.root)
        upload_frame.pack(pady=20)
        
        upload_btn = tk.Button(
            upload_frame, 
            text="📁 选择黑盒日志", 
            font=("Arial", 14),
            width=20, 
            height=2,
            command=self.select_file
        )
        upload_btn.pack()
        
        # 状态标签
        self.status_label = tk.Label(self.root, text="", font=("Arial", 12))
        self.status_label.pack(pady=10)
        
        # 结果区域
        self.result_frame = tk.Frame(self.root)
        self.result_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        # 建议区域
        self.recommend_frame = tk.Frame(self.root)
        self.recommend_frame.pack(fill=tk.X, padx=20, pady=10)
        
        # 调参流程按钮
        guide_btn = tk.Button(
            self.root,
            text="📖 调参流程指导",
            font=("Arial", 12),
            command=self.show_guide
        )
        guide_btn.pack(pady=10)
        
    def select_file(self):
        file_path = filedialog.askopenfilename(
            title="选择黑盒日志",
            filetypes=[("Blackbox files", "*.bbl *.bfl *.csv"), ("All files", "*.*")]
        )
        
        if file_path:
            self.analyze_file(file_path)
            
    def analyze_file(self, file_path):
        self.status_label.config(text="正在分析...")
        
        # 清空之前的结果
        for widget in self.result_frame.winfo_children():
            widget.destroy()
        for widget in self.recommend_frame.winfo_children():
            widget.destroy()
        
        # 在线程中执行分析
        thread = threading.Thread(target=self._analyze_thread, args=(file_path,))
        thread.start()
        
    def _analyze_thread(self, file_path):
        try:
            # 导入分析模块
            from analysis_service import LogDecoder, StepResponseAnalyzer, AnalysisResult
            
            # 解码日志
            self.root.after(0, lambda: self.status_label.config(text="正在解码日志..."))
            log_data = LogDecoder.decodeBBL(file_path)
            
            # 分析数据
            self.root.after(0, lambda: self.status_label.config(text="正在分析阶跃响应..."))
            result = StepResponseAnalyzer.analyze(log_data)
            
            # 更新UI
            self.root.after(0, lambda: self.show_result(result))
            
        except Exception as e:
            self.root.after(0, lambda: self.status_label.config(text=f"分析失败: {str(e)}"))
            
    def show_result(self, result):
        self.status_label.config(text="分析完成")
        
        # 创建结果表格
        tree = ttk.Treeview(self.result_frame, columns=("metric", "roll", "pitch", "status"), show="headings", height=5)
        tree.heading("metric", text="指标")
        tree.heading("roll", text="Roll")
        tree.heading("pitch", text="Pitch")
        tree.heading("status", text="状态")
        
        tree.column("metric", width=120)
        tree.column("roll", width=100)
        tree.column("pitch", width=100)
        tree.column("status", width=80)
        
        # 超调
        roll_status = "✅" if result.rollOvershoot < 10 else "⚠️"
        pitch_status = "✅" if result.pitchOvershoot < 10 else "⚠️"
        tree.insert("", "end", values=("超调", f"{result.rollOvershoot:.1f}%", f"{result.pitchOvershoot:.1f}%", roll_status if result.rollOvershoot == result.pitchOvershoot else pitch_status))
        
        # 上升时间
        tree.insert("", "end", values=("上升时间", f"{result.rollRiseTime:.0f}ms", f"{result.pitchRiseTime:.0f}ms", "-"))
        
        # 稳态值
        tree.insert("", "end", values=("稳态值", f"{result.rollSteadyState:.2f}", f"{result.pitchSteadyState:.2f}", "-"))
        
        # 峰值
        tree.insert("", "end", values=("峰值", f"{result.rollPeakValue:.2f}", f"{result.pitchPeakValue:.2f}", "-"))
        
        # 分析段数
        tree.insert("", "end", values=("分析段数", result.rollSegments, result.pitchSegments, "-"))
        
        tree.pack(fill=tk.BOTH, expand=True)
        
        # 显示建议
        recommend_label = tk.Label(
            self.recommend_frame, 
            text=f"💡 {result.getRecommendation()}", 
            font=("Arial", 14),
            wraplength=500
        )
        recommend_label.pack()
        
        # CLI命令
        commands = result.getCLICommands()
        if commands:
            cmd_text = tk.Text(self.recommend_frame, height=4, width=50)
            cmd_text.pack(pady=10)
            cmd_text.insert("1.0", "\n".join(commands))
            cmd_text.config(state="disabled")
            
            # 复制按钮
            copy_btn = tk.Button(
                self.recommend_frame,
                text="📋 复制命令",
                command=lambda: self.copy_commands(commands)
            )
            copy_btn.pack()
            
    def copy_commands(self, commands):
        self.root.clipboard_clear()
        self.root.clipboard_append("\n".join(commands))
        messagebox.showinfo("提示", "已复制到剪贴板")
        
    def show_guide(self):
        guide_window = tk.Toplevel(self.root)
        guide_window.title("调参流程指导")
        guide_window.geometry("400x500")
        
        guide_text = """
🎯 标准调参流程

1️⃣ 机械检查
   • 检查电机螺丝紧固
   • 检查飞控减震
   • 检查桨叶平衡
   • 检查轴承顺滑

2️⃣ 调滤波器
   • 发黑盒日志分析频谱
   • 根据噪声分布设陷波滤波

3️⃣ 调 PID
   顺序: D → P → FF → I

📝 口诀：
   机械先行，P打基础
   D控过冲，FF追跟随
   I保稳定，滤波最后动

4️⃣ 验证
   • 全油门直线
   • 快速翻滚
   • 悬停稳定
   • 电机温度
"""
        
        text = tk.Text(guide_window, wrap=tk.WORD, font=("Arial", 11))
        text.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        text.insert("1.0", guide_text)
        text.config(state="disabled")

if __name__ == "__main__":
    root = tk.Tk()
    app = PIDTunerApp(root)
    root.mainloop()
