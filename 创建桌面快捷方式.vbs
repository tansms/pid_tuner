Set oWS = WScript.CreateObject("WScript.Shell")
sLinkFile = oWS.SpecialFolders("Desktop") & "\PID调参助手.lnk"

Set oLink = oWS.CreateShortcut(sLinkFile)
oLink.TargetPath = "C:\pid_tuner_app\启动PID调参助手.bat"
oLink.WorkingDirectory = "C:\pid_tuner_app"
oLink.Description = "PID调参助手"
oLink.Save

WScript.Echo "快捷方式已创建到桌面！"
