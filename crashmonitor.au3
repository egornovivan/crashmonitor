#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=crashmonitor.ico
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Res_SaveSource=y
#AutoIt3Wrapper_Add_Constants=n
#AutoIt3Wrapper_AU3Check_Stop_OnWarning=y
#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
; *** Start added by AutoIt3Wrapper ***
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <File.au3>
#include <GUIConstantsEx.au3>
#include <Memory.au3>
#include <Process.au3>
#include <ProcessConstants.au3>
#include <StaticConstants.au3>
#include <WinAPI.au3>
#include <WindowsConstants.au3>
; *** End added by AutoIt3Wrapper ***
Opt("TrayAutoPause", 0)
Opt("TrayIconHide", 1)



Local $extensions[] = ["*.log", "*.txt", "*.ini", "*.inf", "*.cfg", "*.dll"]
$tempdir = @TempDir & "\crashmonitor"
$scriptdir = @ScriptDir
$crashmonitorlog = $scriptdir & "\crashmonitor.log"



If ($CmdLine[0] > 0) Then
	$hwnd = HWnd(Ptr($CmdLine[1]))
Else
	Opt("WinTitleMatchMode", -1)
	$hwnd = WinWait("[TITLE:Fallout II; CLASS:GNW95 Class]", "", 15)
	Opt("WinTitleMatchMode", 1)
EndIf
If ($hwnd == 0) Then
	Exit
EndIf

$drivespacefree = Round(DriveSpaceFree($scriptdir))
If (($drivespacefree < 1024) And ($drivespacefree > 0)) Then
	Sleep(2000)
	WinSetState($hwnd, "", @SW_MINIMIZE)
	MsgBox(262192, "Free Disk Space", "ENG:You have less than 1GB of free disk space, please free up a few gigabytes." & @CRLF & "RUS:У вас осталось менее 1GB свободного места на диске, пожалуйста освободите несколько гигабайт.")
	WinSetState($hwnd, "", @SW_RESTORE)
EndIf

If ($CmdLine[0] > 1) Then
	If ($CmdLine[2] == 0) Then
		$dumpprocess = False
	Else
		$dumpprocess = True
	EndIf
Else
	$dumpprocess = False
EndIf

If ($CmdLine[0] > 2) Then
	$dumptype = _DWORD(Ptr($CmdLine[3]))
Else
	$dumptype = _DWORD(Ptr("0x00000000"))
EndIf

$pid = WinGetProcess($hwnd)
If ($pid == -1) Then
	Exit
EndIf
$exe = 0
$processlist = 0
$processlist = ProcessList()
If (IsArray($processlist)) Then
	While Not ($processlist[0][0] == 0)
		If ($processlist[$processlist[0][0]][1] == $pid) Then
			$exe = $processlist[$processlist[0][0]][0]
			ExitLoop
		EndIf
		$processlist[0][0] -= 1
	WEnd
Else
	Exit
EndIf
If ($exe == 0) Then
	Exit
EndIf

$gamedir1 = _WinAPI_GetProcessFileName($pid)
$gamedir2 = StringRegExpReplace($scriptdir, "^(.*)(?:[\/\\]{1}[^\/\\]*)$", "\1") & "\" & $exe
If ($gamedir1 == $gamedir2) Then
	If (FileExists($gamedir1) And FileExists($gamedir2)) Then
		$gamedir = StringRegExpReplace($scriptdir, "^(.*)(?:[\/\\]{1}[^\/\\]*)$", "\1")
	Else
		Exit
	EndIf
ElseIf (FileExists($gamedir2)) Then
	$gamedir = StringRegExpReplace($gamedir2, "^(.*)(?:[\/\\]{1}[^\/\\]*)$", "\1")
ElseIf (FileExists($gamedir1)) Then
	$gamedir = StringRegExpReplace($gamedir1, "^(.*)(?:[\/\\]{1}[^\/\\]*)$", "\1")
Else
	Exit
EndIf
$savesdir = $gamedir & "\data\savegame"

While 1
	If (WinExists($hwnd)) Then
		$hwnde = 0
		$crash = ""
	Else
		If (WinExists($hwnd)) Then
			$hwnde = 0
			$crash = ""
		Else
			If (ProcessExists($pid)) Then
				$hwnd = 0
				$hwnde = 0
				$crash = "The window is gone, but the process still exists."
			Else
				ExitLoop
			EndIf
		EndIf
	EndIf
	$hwndarray = 0
	$hwndarray = _WinAPI_EnumProcessWindows($pid, True)
	If (IsArray($hwndarray)) Then
		While Not ($hwndarray[0][0] == 0)
			If ($hwndarray[$hwndarray[0][0]][0] == $hwnd) Then
				If (_WinAPI_IsHungAppWindow($hwndarray[$hwndarray[0][0]][0])) Then
					$hwnde = $hwndarray[$hwndarray[0][0]][0]
					$crash = "The window is frozen/hung."
				EndIf
				$hwndarray[0][0] -= 1
			Else
				If ($hwndarray[$hwndarray[0][0]][1] == "#32770") Then
					If (WinGetProcess($hwndarray[$hwndarray[0][0]][0]) == $pid) Then
						$hwnde = $hwndarray[$hwndarray[0][0]][0]
						$crash = WinGetText($hwnde)
						ExitLoop
					EndIf
				EndIf
				$hwndarray[0][0] -= 1
			EndIf
		WEnd
	EndIf
	If ($hwnd == 0) Then
		If ($hwnde == 0) Then
			If (ProcessWaitClose($pid, 5)) Then
				ExitLoop
			EndIf
		EndIf
	EndIf
	If Not ($crash == "") Then
		WinMinimizeAll()
		ProgressOn("Please, wait", "Please, wait")
		$crashreport = @YEAR & @MON & @MDAY & @HOUR & @MIN & @SEC
		$crashreportdir = $scriptdir & "\" & $crashreport
		$dumpfile = $crashreportdir & "\" & $crashreport & ".dmp"
		If Not (DirCreate($crashreportdir)) Then
			_error_log($crashmonitorlog, $crashreport, $crash, 'DirCreate($crashreportdir)')
		EndIf
		$hfile = FileOpen($crashreportdir & "\" & $crashreport & "_crash.txt", 521)
		If Not ($hfile == -1) Then
			FileWrite($hfile, $crash)
			FileClose($hfile)
		EndIf
		If ($dumpprocess And FileExists($crashreportdir) And ProcessExists($pid)) Then
			$hprocess = 0
			$hprocess = _WinAPI_OpenProcess($PROCESS_ALL_ACCESS, 0, $pid, True)
			If Not ($hprocess == 0) Then
				$hfile = 0
				$hfile = _WinAPI_CreateFile($dumpfile, 1)
				If Not ($hfile == 0) Then
					$minidumpcall = DllCall("dbghelp.dll", "bool", "MiniDumpWriteDump", "handle", $hprocess, "dword", $pid, "handle", $hfile, "dword", $dumptype, "dword", 0, "dword", 0, "dword", 0)
					If (IsArray($minidumpcall)) Then
						If ($minidumpcall[0] == 1) Then
							_WinAPI_CloseHandle($hfile)
							_WinAPI_CloseHandle($hprocess)
						Else
							_error_log($crashmonitorlog, $crashreport, $crash, '$minidumpcall = DllCall')
						EndIf
					Else
						_error_log($crashmonitorlog, $crashreport, $crash, 'IsArray($minidumpcall)')
					EndIf
				Else
					_error_log($crashmonitorlog, $crashreport, $crash, '_WinAPI_CreateFile')
				EndIf
			Else
				_error_log($crashmonitorlog, $crashreport, $crash, '_WinAPI_OpenProcess')
			EndIf
		EndIf
		ProgressOff()
		If Not ($hwnde == 0) Then
			If ($hwnde == $hwnd) Then
				WinClose($hwnde)
				If Not (WinWaitClose($hwnde, "", 5)) Then
					_error_log($crashmonitorlog, $crashreport, $crash, 'WinWaitClose($hwnde, "", 5)')
					WinKill($hwnde)
				EndIf
			Else
				WinSetState($hwnde, "", @SW_RESTORE)
				WinSetOnTop($hwnde, "", 1)
				WinActivate($hwnde)
				If Not (WinWaitClose($hwnde, "", 15)) Then
					WinClose($hwnde)
					If Not (WinWaitClose($hwnde, "", 5)) Then
						_error_log($crashmonitorlog, $crashreport, $crash, 'WinWaitClose($hwnde, "", 5)')
						WinKill($hwnde)
					EndIf
				EndIf
			EndIf
		EndIf
		#Region ### START Koda GUI section ###
		$Form1 = GUICreate("Report", 641, 481, -1, -1, -1, BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE))
		$Edit1 = GUICtrlCreateEdit("", 0, 60, 640, 360)
		$Button1 = GUICtrlCreateButton("Done", 283, 436, 75, 25)
		$Label1 = GUICtrlCreateLabel("ENG:Please tell us what happened in the game a few seconds before the crash", 0, 0, 640, 30, BitOR($SS_CENTER, $SS_CENTERIMAGE))
		$Label2 = GUICtrlCreateLabel("RUS:Пожалуйста расскажите что происходило в игре за несколько секунд до краша", 0, 30, 640, 30, BitOR($SS_CENTER, $SS_CENTERIMAGE))
		GUISetState(@SW_SHOW)
		GUICtrlSetState($Edit1, $GUI_FOCUS)
		#EndRegion ### END Koda GUI section ###
		While 1
			$nMsg = GUIGetMsg()
			Switch $nMsg
				Case $GUI_EVENT_CLOSE, $Button1
					$report = GUICtrlRead($Edit1)
					GUIDelete($Form1)
					ExitLoop
			EndSwitch
		WEnd
		$hfile = FileOpen($crashreportdir & "\" & $crashreport & "_report.txt", 521)
		If Not ($hfile == -1) Then
			FileWrite($hfile, "`" & $report & "`")
			FileClose($hfile)
		EndIf
		$files = 0
		$files = _FileListToArray($crashreportdir, "*.txt", 1, 0)
		If (IsArray($files)) Then
			While Not ($files[0] == 0)
				FileCopy($crashreportdir & "\" & $files[$files[0]], $scriptdir & "\" & $files[$files[0]])
				$files[0] -= 1
			WEnd
		EndIf
		If (FileExists($savesdir)) Then
			$saves = 0
			$saves = _FileListToArray($savesdir, "slot*", 2, 0)
			If (IsArray($saves)) Then
				$savestime = $saves
				While Not ($savestime[0] == 0)
					$savestime[$savestime[0]] = FileGetTime($savesdir & "\" & $savestime[$savestime[0]], 0, 1)
					$savestime[0] -= 1
				WEnd
				For $i = 1 To 3
					$maxindex = _ArrayMaxIndex($savestime, 1)
					If Not ($maxindex == 0 Or $maxindex == -1) Then
						If (DirCopy($savesdir & "\" & $saves[$maxindex], $crashreportdir & "\" & $saves[$maxindex])) Then
							FileSetTime($crashreportdir & "\" & $saves[$maxindex], $savestime[$maxindex])
						EndIf
						$savestime[$maxindex] = -1
					EndIf
				Next
			EndIf
		EndIf
		$hfile = FileOpen($gamedir & "\debug.log", 9)
		If Not ($hfile == -1) Then
			FileWrite($hfile, @CRLF & $crashreport & @CRLF & $crash & @CRLF)
			FileClose($hfile)
		EndIf
		For $i In $extensions
			$files = 0
			$files = _FileListToArray($gamedir, $i, 1, 0)
			If (IsArray($files)) Then
				While Not ($files[0] == 0)
					If (FileCopy($gamedir & "\" & $files[$files[0]], $crashreportdir & "\" & $files[$files[0]])) Then
						FileSetTime($crashreportdir & "\" & $files[$files[0]], FileGetTime($gamedir & "\" & $files[$files[0]], 0, 1))
					EndIf
					$files[0] -= 1
				WEnd
			EndIf
		Next
		If (($hwnd == 0) And ($hwnde == 0)) Then
			If (ProcessExists($pid)) Then
				If (ProcessClose($pid)) Then
					ExitLoop
				Else
					Exit
				EndIf
			Else
				ExitLoop
			EndIf
		EndIf
	EndIf
	Sleep(1000)
WEnd

$dirs = 0
$dirs = _FileListToArray($scriptdir, "*", 2, 0)
If (IsArray($dirs)) Then
	While Not ($dirs[0] == 0)
		If (StringRegExp($dirs[$dirs[0]], "^([0-9]{14})$", 0, 1)) Then
			ExitLoop
		Else
			$dirs[0] -= 1
		EndIf
	WEnd
	If Not ($dirs[0] == 0) Then
		ProgressOn("Please, wait", "Please, wait")
		DirRemove($tempdir, 1)
		DirCreate($tempdir)
		FileInstall(".\7za.exe", $tempdir & "\7za.exe", 1)
		FileInstall(".\7za.dll", $tempdir & "\7za.dll", 1)
		FileInstall(".\7zxa.dll", $tempdir & "\7zxa.dll", 1)
		If (FileExists($tempdir & "\7za.exe") And FileExists($tempdir & "\7za.dll") And FileExists($tempdir & "\7zxa.dll")) Then
			ProgressSet(50)
			While Not ($dirs[0] == 0)
				If (StringRegExp($dirs[$dirs[0]], "^([0-9]{14})$", 0, 1)) Then
					$crashreportdir = $scriptdir & "\" & $dirs[$dirs[0]]
					If Not (FileExists($crashreportdir & "_crash.txt")) Then
						If (FileExists($crashreportdir & "\" & $dirs[$dirs[0]] & "_crash.txt")) Then
							FileCopy($crashreportdir & "\" & $dirs[$dirs[0]] & "_crash.txt", $crashreportdir & "_crash.txt", 9)
						Else
							If (FileExists($crashreportdir & "\" & $dirs[$dirs[0]] & ".dmp")) Then
								$hfile = FileOpen($crashreportdir & "\" & $dirs[$dirs[0]] & "_crash.txt", 521)
								If Not ($hfile == -1) Then
									FileWrite($hfile, @CRLF & "Unknown" & @CRLF)
									FileClose($hfile)
								EndIf
								FileCopy($crashreportdir & "\" & $dirs[$dirs[0]] & "_crash.txt", $crashreportdir & "_crash.txt", 9)
							Else
								DirRemove($crashreportdir, 1)
								$dirs[0] -= 1
								ContinueLoop
							EndIf
						EndIf
					EndIf
					If Not (FileExists($crashreportdir & "_report.txt")) Then
						If (FileExists($crashreportdir & "\" & $dirs[$dirs[0]] & "_report.txt")) Then
							FileCopy($crashreportdir & "\" & $dirs[$dirs[0]] & "_report.txt", $crashreportdir & "_report.txt", 9)
						Else
							$hfile = FileOpen($crashreportdir & "\" & $dirs[$dirs[0]] & "_report.txt", 521)
							If Not ($hfile == -1) Then
								FileWrite($hfile, "``")
								FileClose($hfile)
							EndIf
							FileCopy($crashreportdir & "\" & $dirs[$dirs[0]] & "_report.txt", $crashreportdir & "_report.txt", 9)
						EndIf
					EndIf
					If (FileExists($crashmonitorlog)) Then
						FileCopy($crashmonitorlog, $crashreportdir & "\crashmonitor.log", 9)
					EndIf
					If (FileExists($crashreportdir & ".7z")) Then
						FileDelete($crashreportdir & ".7z")
					EndIf
					If Not (RunWait('"' & $tempdir & '\7za.exe" a "' & $crashreportdir & '.7z" "' & $crashreportdir & '"', $scriptdir, @SW_HIDE)) Then
						If (FileExists($crashreportdir & ".7z")) Then
							DirRemove($crashreportdir, 1)
						Else
							_error_log($crashmonitorlog, $dirs[$dirs[0]], "7za", 'FileExists($crashreportdir & ".7z")')
						EndIf
					Else
						_error_log($crashmonitorlog, $dirs[$dirs[0]], "7za", 'RunWait')
					EndIf
					$dirs[0] -= 1
				Else
					$dirs[0] -= 1
				EndIf
			WEnd
		Else
			_error_log($crashmonitorlog, $dirs[$dirs[0]], "7za", 'FileExists($tempdir & "\7za.exe")')
		EndIf
		DirRemove($tempdir, 1)
		ProgressOff()
	EndIf
EndIf

$files = 0
$files = _FileListToArray($scriptdir, "*.7z", 1, 1)
If (IsArray($files)) Then
	While Not ($files[0] == 0)
		If (StringRegExp($files[$files[0]], "^.*[0-9]{14}\.7z$", 0, 1)) Then
			$idbutton = MsgBox(262192, "Crashreport is ready", "ENG:Please transfer this archive to the developers of this mod or the developers of sfall" & @CRLF & "RUS:Пожалуйста, передайте этот архив разработчикам мода или разработчикам sfall" & @CRLF & @CRLF & $files[$files[0]])
			If ($idbutton == 1) Then
				ShellExecute($scriptdir)
			EndIf
			ExitLoop
		Else
			$files[0] -= 1
		EndIf
	WEnd
EndIf



Exit



Func _error_log($a, $b, $c, $d)
	Local $thfile = FileOpen($a, 9)
	FileWrite($thfile, "__________" & @CRLF & $b & @CRLF & $c & @CRLF & $d & @CRLF & "__________")
	FileClose($thfile)
EndFunc   ;==>_error_log

Func _DWORD($a)
	Local $tDWORD = DllStructCreate("DWORD")
	DllStructSetData($tDWORD, 1, $a)
	Return DllStructGetData($tDWORD, 1)
EndFunc   ;==>_DWORD


