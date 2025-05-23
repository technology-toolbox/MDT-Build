'////////////////////////////////////////////////////////////////////////
' OSD Deploy Tool Applications Scanner
'////////////////////////////////////////////////////////////////////////
' Reads applications list from Config.xml.app file and registry.
' Compare list of application and create a list of installed and uninstalled
' application. The list will be saved in the registry.
'////////////////////////////////////////////////////////////////////////
' V1.00 05.02.2012	v-basabu
'////////////////////////////////////////////////////////////////////////
Option Explicit

'||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
' Constants
'||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
Const	REG32			= "%windir%\System32\reg.exe"
Const	REG64			= "%windir%\Sysnative\reg.exe"
Const	REGBRANDPATH	= "Software\Microsoft\MPSD\OSD"
Const	REGBRAND64PATH	= "Software\WOW6432Node\Microsoft\MPSD\OSD"

Const tsAppVariableName      = "TsApplicationBaseVariable"
Const tsWindowsAppPackageAppVariableName = "TsWindowsAppPackageAppBaseVariable"

Const COMPUTERNAME = "."
Const WMICONST = "winmgmts:{impersonationLevel=impersonate}!\\"
Const WMIROOT = "\root\default:StdRegProv"
Const HKEY_LOCAL_MACHINE =  &H80000002
Const APPSTATUSREGVALUE = "InstalledApps"
Const STATUSDELIMITER = ":"

'||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
' Globals
'||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
Dim errorCode
Dim REGBRAND
Dim oARG
Dim oWSH
Dim oTSE
Dim oXML
Dim oWMI
Dim xmlAppFilename
Dim devMode
Dim strApplications : strApplications = ""

'[##############################################################################################################################]
' MAIN BEGIN
'[##############################################################################################################################]

PrintTitle("Parsing arguments...")
IF (ParseArguments = false) Then QuitScript( 100 )

PrintTitle("Initializing Objects")
IF (Initialize = false) Then QuitScript( 200 )

PrintTitle("Comparing Desired Application with Installed Applications")
IF (CompareApps = false)  Then QuitScript( 300 )

' Print completion and exit
PrintTitle("Script Completed Successfully!")
QuitScript ( 0 )

'[##############################################################################################################################]
' FUNCTIONS
'[##############################################################################################################################]

Function CompareApps

    On Error Resume NEXT
	Err.Number = 0
	CompareApps = true

    Dim applicationsPrefix : applicationsPrefix =  oTSE(tsAppVariableName)
    Dim windowsAppPackageAppPrefix : windowsAppPackageAppPrefix = oTSE(tsWindowsAppPackageAppVariableName)
    Dim delimiter : delimiter = "|"

    Dim tV
    For Each tV in oTSE.GetVariables()

        MatchApplication applicationsPrefix, tV, delimiter
        MatchApplication windowsAppPackageAppPrefix, tV, delimiter

    Next

    iF(Len(strApplications) > 0) Then

        WriteArrayToRegistry  strApplications, delimiter

    End If

    On Error Goto 0

End Function

Function MatchApplication(prefix, item, delimiter)

    If ( InStr(1, item, prefix, 1) = 1 ) Then

                Dim appName : appName =  oTSE(item)

                Dim status : status = IsSelected(appName)

                if(Len(strApplications) > 0) Then strApplications = strApplications & delimiter

                strApplications = strApplications & appName & STATUSDELIMITER & status

	End IF

End Function

Function IsSelected(appName)

    IsSelected = "0"
    Dim appNode
    Dim selectedNode
    Dim appId
    Set appNode = oXML.selectSingleNode( "/Applications//Application[@Name='" & appName & "']" )

    If (not appNode is Nothing)  Then
        appId = appNode.getAttribute("Id")
        Set selectedNode = oXML.selectSingleNode( "/Applications/SelectedApplications/SelectApplication[@Application.Id='" & appId & "']" )
        If (not selectedNode is Nothing) Then IsSelected = "1"

    End IF

End Function

' /////////////////////////////////////////////////////////
' Parses command line arguments and populates two global variables
' xmlAppFilename : contains the path and name of XML file to be loaded later
' devMode        : flag indicates if in debug mode. Allows us to enable/disable
'                  initialization of some objects (mainly "Microsoft.SMS.TSEnvironment")
'                  See function INITIALIZE for more information.
' /////////////////////////////////////////////////////////
Function ParseArguments

	On Error Resume NEXT
	Err.Number = 0

	ParseArguments = true

	SET oARG = WScript.Arguments

	IF (oARG.Length = 0) THEN
		PrintTitle("Missing required arguments")
		QuitScript( 110 )
	END IF

	' Populate global variables from command line arguments.
	' FileName is manadatory
	IF NOT oARG.Named.Exists("FileName") THEN
		Err.Number = 2
		Err.Description = "Usage: /FileName:<XML filename> is required."
	END IF

	xmlAppFilename = oARG.Named.Item("FileName")

	' DevMode is optional
	IF oARG.Named.Exists("DevMode") THEN
		devMode = oARG.Named.Item("DevMode")
	END IF

	IF (Err.Number <> 0) Then
		ParseArguments = false
		wscript.echo " --| Error: [" & Err.Number & "]"
		wscript.echo " --| Description: [" & Err.Description & "]"
	End IF

	On Error Goto 0

End Function

' /////////////////////////////////////////////////////////
' Initialize Objects
' /////////////////////////////////////////////////////////
Function Initialize

	Initialize = true

	On Error Resume NEXT
	Err.Number = 0

	SET oARG = WScript.Arguments.Named
	SET oWSH = CreateObject("WScript.Shell")

	' this object is not available in Windows normal mode
	' so, don't attempt to initialize it if in dev mode
	IF (devMode = false) THEN
		SET oTSE = CreateObject("Microsoft.SMS.TSEnvironment")
	END IF

	SET oXML = CreateObject("Microsoft.XMLDOM")
	SET oWMI = GetObject(WMICONST & COMPUTERNAME & WMIROOT)

	IF (Err.Number <> 0) THEN
		Initialize = false
		wscript.echo " --| Error: [" & Err.Number & "]"
		wscript.echo " --| Description: [" & Err.Description & "]"
	End IF

    PrintTitle( "Loading XML from file [" & xmlAppFilename & "]..." )
    IF (oXML.Load( xmlAppFilename ) = false) THEN
        Initialize = false
	    Wscript.Echo "Failed to load XML from file."
    END IF

	On Error Goto 0

End Function

' ////////////////////////////////////////////////////
' WriteArrayToRegistry
' Needed to write to resitry variables of type multi_sz from VBS.
' It seems that writing a REG_MULTI to registry is not supported in VBS script.
'
' It splits the passed in "|" delimited string creating an array
' which it uses to write to the registry.
' ////////////////////////////////////////////////////
Function WriteArrayToRegistry ( listToWriteToRegistry, delimiter )

	Dim multipStringArray

	' Split the string along its delimeters. This will create the strings array to store in the registry
	multipStringArray = Split (listToWriteToRegistry, delimiter)

	'create an instance of the registry provider

	'write multistring value
	oWMI.SetMultiStringValue HKEY_LOCAL_MACHINE, REGBRANDPATH, APPSTATUSREGVALUE, multipStringArray
    oWMI.SetMultiStringValue HKEY_LOCAL_MACHINE, REGBRAND64PATH, APPSTATUSREGVALUE, multipStringArray

    WriteArrayToRegistry = true

End Function

' /////////////////////////////////////////////////////////
' Print Title
' /////////////////////////////////////////////////////////
Sub PrintTitle( theTitle )

	wscript.echo "--------------------------------"
	wscript.echo theTitle
	wscript.echo "--------------------------------"
	wscript.echo ""

End Sub

' /////////////////////////////////////////////////////////
' Quit Script
' /////////////////////////////////////////////////////////
Sub QuitScript( theExitCode )

	wscript.echo "--------------------------------"
	wscript.echo "Exiting with [" & theExitCode & "]"
	wscript.echo "--------------------------------"

	wscript.Quit( theExitCode )

End Sub
'' SIG '' Begin signature block
'' SIG '' MIIaWgYJKoZIhvcNAQcCoIIaSzCCGkcCAQExCzAJBgUr
'' SIG '' DgMCGgUAMGcGCisGAQQBgjcCAQSgWTBXMDIGCisGAQQB
'' SIG '' gjcCAR4wJAIBAQQQTvApFpkntU2P5azhDxfrqwIBAAIB
'' SIG '' AAIBAAIBAAIBADAhMAkGBSsOAwIaBQAEFJmrwzdToBpH
'' SIG '' mmFNcd1b52AfIJtloIIVNjCCBKkwggORoAMCAQICEzMA
'' SIG '' AACIWQ48UR/iamcAAQAAAIgwDQYJKoZIhvcNAQEFBQAw
'' SIG '' eTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
'' SIG '' b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
'' SIG '' Y3Jvc29mdCBDb3Jwb3JhdGlvbjEjMCEGA1UEAxMaTWlj
'' SIG '' cm9zb2Z0IENvZGUgU2lnbmluZyBQQ0EwHhcNMTIwNzI2
'' SIG '' MjA1MDQxWhcNMTMxMDI2MjA1MDQxWjCBgzELMAkGA1UE
'' SIG '' BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
'' SIG '' BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
'' SIG '' b3Jwb3JhdGlvbjENMAsGA1UECxMETU9QUjEeMBwGA1UE
'' SIG '' AxMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMIIBIjANBgkq
'' SIG '' hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAs3R00II8h6ea
'' SIG '' 1I6yBEKAlyUu5EHOk2M2XxPytHiYgMYofsyKE+89N4w7
'' SIG '' CaDYFMVcXtipHX8BwbOYG1B37P7qfEXPf+EhDsWEyp8P
'' SIG '' a7MJOLd0xFcevvBIqHla3w6bHJqovMhStQxpj4TOcVV7
'' SIG '' /wkgv0B3NyEwdFuV33fLoOXBchIGPfLIVWyvwftqFifI
'' SIG '' 9bNh49nOGw8e9OTNTDRsPkcR5wIrXxR6BAf11z2L22d9
'' SIG '' Vz41622NAUCNGoeW4g93TIm6OJz7jgKR2yIP5dA2qbg3
'' SIG '' RdAq/JaNwWBxM6WIsfbCBDCHW8PXL7J5EdiLZWKiihFm
'' SIG '' XX5/BXpzih96heXNKBDRPQIDAQABo4IBHTCCARkwEwYD
'' SIG '' VR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFCZbPltd
'' SIG '' ll/i93eIf15FU1ioLlu4MA4GA1UdDwEB/wQEAwIHgDAf
'' SIG '' BgNVHSMEGDAWgBTLEejK0rQWWAHJNy4zFha5TJoKHzBW
'' SIG '' BgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jv
'' SIG '' c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNDb2RT
'' SIG '' aWdQQ0FfMDgtMzEtMjAxMC5jcmwwWgYIKwYBBQUHAQEE
'' SIG '' TjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jv
'' SIG '' c29mdC5jb20vcGtpL2NlcnRzL01pY0NvZFNpZ1BDQV8w
'' SIG '' OC0zMS0yMDEwLmNydDANBgkqhkiG9w0BAQUFAAOCAQEA
'' SIG '' D95ASYiR0TE3o0Q4abJqK9SR+2iFrli7HgyPVvqZ18qX
'' SIG '' J0zohY55aSzkvZY/5XBml5UwZSmtxsqs9Q95qGe/afQP
'' SIG '' l+MKD7/ulnYpsiLQM8b/i0mtrrL9vyXq7ydQwOsZ+Bpk
'' SIG '' aqDhF1mv8c/sgaiJ6LHSFAbjam10UmTalpQqXGlrH+0F
'' SIG '' mRrc6GWqiBsVlRrTpFGW/VWV+GONnxQMsZ5/SgT/w2at
'' SIG '' Cq+upN5j+vDqw7Oy64fbxTittnPSeGTq7CFbazvWRCL0
'' SIG '' gVKlK0MpiwyhKnGCQsurG37Upaet9973RprOQznoKlPt
'' SIG '' z0Dkd4hCv0cW4KU2au+nGo06PTME9iUgIzCCBLowggOi
'' SIG '' oAMCAQICCmECkkoAAAAAACAwDQYJKoZIhvcNAQEFBQAw
'' SIG '' dzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
'' SIG '' b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
'' SIG '' Y3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWlj
'' SIG '' cm9zb2Z0IFRpbWUtU3RhbXAgUENBMB4XDTEyMDEwOTIy
'' SIG '' MjU1OVoXDTEzMDQwOTIyMjU1OVowgbMxCzAJBgNVBAYT
'' SIG '' AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
'' SIG '' EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
'' SIG '' cG9yYXRpb24xDTALBgNVBAsTBE1PUFIxJzAlBgNVBAsT
'' SIG '' Hm5DaXBoZXIgRFNFIEVTTjpCOEVDLTMwQTQtNzE0NDEl
'' SIG '' MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
'' SIG '' dmljZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
'' SIG '' ggEBAM1jw/eitUfZ+TmUU6xrj6Z5OCH00W49FTgWwXMs
'' SIG '' mY/74Dxb4aJMi7Kri7TySse5k1DRJvWHU7B6dfNHDxcr
'' SIG '' Zyxk62DnSozgi17EVmk3OioEXRcByL+pt9PJq6ORqIHj
'' SIG '' Py232OTEeAB5Oc/9x2TiIxJ4ngx2J0mPmqwOdOMGVVVJ
'' SIG '' yO2hfHBFYX6ycRYe4cFBudLSMulSJPM2UATX3W88SdUL
'' SIG '' 1HZA/GVlE36VUTrV/7iap1drSxXlN1gf3AANxa7q34FH
'' SIG '' +fBSrubPWqzgFEqmcZSA+v2wIzBg6YNgrA4kHv8R8uel
'' SIG '' VWKV7p9/ninWzUsKdoPwQwTfBkkg8lNaRLBRejkCAwEA
'' SIG '' AaOCAQkwggEFMB0GA1UdDgQWBBTNGaxhTZRnK/avlHVZ
'' SIG '' 2/BYAIOhOjAfBgNVHSMEGDAWgBQjNPjZUkZwCu1A+3b7
'' SIG '' syuwwzWzDzBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
'' SIG '' Y3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0
'' SIG '' cy9NaWNyb3NvZnRUaW1lU3RhbXBQQ0EuY3JsMFgGCCsG
'' SIG '' AQUFBwEBBEwwSjBIBggrBgEFBQcwAoY8aHR0cDovL3d3
'' SIG '' dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNyb3Nv
'' SIG '' ZnRUaW1lU3RhbXBQQ0EuY3J0MBMGA1UdJQQMMAoGCCsG
'' SIG '' AQUFBwMIMA0GCSqGSIb3DQEBBQUAA4IBAQBRHNbfNh3c
'' SIG '' gLwCp8aZ3xbIkAZpFZoyufNkENKK82IpG3mPymCps13E
'' SIG '' 5BYtNYxEm/H0XGGkQa6ai7pQ0Wp5arNijJ1NUVALqY7U
'' SIG '' v6IQwEfVTnVSiR4/lmqPLkAUBnLuP3BZkl2F7YOZ+oKE
'' SIG '' nuQDASETqyfWzHFJ5dod/288CU7VjWboDMl/7jEUAjdf
'' SIG '' e2nsiT5FfyVE5x8a1sUaw0rk4fGEmOdP+amYpxhG7IRs
'' SIG '' 7KkDCv18elIdnGukqA+YkqSSeFwreON9ssfZtnB931tz
'' SIG '' U7+q1GZQS/DJO5WF5cFKZZ0lWFC7IFSReTobB1xqVyiv
'' SIG '' Mcef58Md7kf9J9d/z3TcZcU/MIIFvDCCA6SgAwIBAgIK
'' SIG '' YTMmGgAAAAAAMTANBgkqhkiG9w0BAQUFADBfMRMwEQYK
'' SIG '' CZImiZPyLGQBGRYDY29tMRkwFwYKCZImiZPyLGQBGRYJ
'' SIG '' bWljcm9zb2Z0MS0wKwYDVQQDEyRNaWNyb3NvZnQgUm9v
'' SIG '' dCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMTAwODMx
'' SIG '' MjIxOTMyWhcNMjAwODMxMjIyOTMyWjB5MQswCQYDVQQG
'' SIG '' EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
'' SIG '' BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
'' SIG '' cnBvcmF0aW9uMSMwIQYDVQQDExpNaWNyb3NvZnQgQ29k
'' SIG '' ZSBTaWduaW5nIFBDQTCCASIwDQYJKoZIhvcNAQEBBQAD
'' SIG '' ggEPADCCAQoCggEBALJyWVwZMGS/HZpgICBCmXZTbD4b
'' SIG '' 1m/My/Hqa/6XFhDg3zp0gxq3L6Ay7P/ewkJOI9VyANs1
'' SIG '' VwqJyq4gSfTwaKxNS42lvXlLcZtHB9r9Jd+ddYjPqnNE
'' SIG '' f9eB2/O98jakyVxF3K+tPeAoaJcap6Vyc1bxF5Tk/TWU
'' SIG '' cqDWdl8ed0WDhTgW0HNbBbpnUo2lsmkv2hkL/pJ0KeJ2
'' SIG '' L1TdFDBZ+NKNYv3LyV9GMVC5JxPkQDDPcikQKCLHN049
'' SIG '' oDI9kM2hOAaFXE5WgigqBTK3S9dPY+fSLWLxRT3nrAgA
'' SIG '' 9kahntFbjCZT6HqqSvJGzzc8OJ60d1ylF56NyxGPVjzB
'' SIG '' rAlfA9MCAwEAAaOCAV4wggFaMA8GA1UdEwEB/wQFMAMB
'' SIG '' Af8wHQYDVR0OBBYEFMsR6MrStBZYAck3LjMWFrlMmgof
'' SIG '' MAsGA1UdDwQEAwIBhjASBgkrBgEEAYI3FQEEBQIDAQAB
'' SIG '' MCMGCSsGAQQBgjcVAgQWBBT90TFO0yaKleGYYDuoMW+m
'' SIG '' PLzYLTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAf
'' SIG '' BgNVHSMEGDAWgBQOrIJgQFYnl+UlE/wq4QpTlVnkpDBQ
'' SIG '' BgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLm1pY3Jv
'' SIG '' c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9taWNyb3Nv
'' SIG '' ZnRyb290Y2VydC5jcmwwVAYIKwYBBQUHAQEESDBGMEQG
'' SIG '' CCsGAQUFBzAChjhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
'' SIG '' b20vcGtpL2NlcnRzL01pY3Jvc29mdFJvb3RDZXJ0LmNy
'' SIG '' dDANBgkqhkiG9w0BAQUFAAOCAgEAWTk+fyZGr+tvQLEy
'' SIG '' tWrrDi9uqEn361917Uw7LddDrQv+y+ktMaMjzHxQmIAh
'' SIG '' Xaw9L0y6oqhWnONwu7i0+Hm1SXL3PupBf8rhDBdpy6Wc
'' SIG '' IC36C1DEVs0t40rSvHDnqA2iA6VW4LiKS1fylUKc8fPv
'' SIG '' 7uOGHzQ8uFaa8FMjhSqkghyT4pQHHfLiTviMocroE6WR
'' SIG '' Tsgb0o9ylSpxbZsa+BzwU9ZnzCL/XB3Nooy9J7J5Y1ZE
'' SIG '' olHN+emjWFbdmwJFRC9f9Nqu1IIybvyklRPk62nnqaIs
'' SIG '' vsgrEA5ljpnb9aL6EiYJZTiU8XofSrvR4Vbo0HiWGFzJ
'' SIG '' NRZf3ZMdSY4tvq00RBzuEBUaAF3dNVshzpjHCe6FDoxP
'' SIG '' bQ4TTj18KUicctHzbMrB7HCjV5JXfZSNoBtIA1r3z6Nn
'' SIG '' CnSlNu0tLxfI5nI3EvRvsTxngvlSso0zFmUeDordEN5k
'' SIG '' 9G/ORtTTF+l5xAS00/ss3x+KnqwK+xMnQK3k+eGpf0a7
'' SIG '' B2BHZWBATrBC7E7ts3Z52Ao0CW0cgDEf4g5U3eWh++VH
'' SIG '' EK1kmP9QFi58vwUheuKVQSdpw5OPlcmN2Jshrg1cnPCi
'' SIG '' roZogwxqLbt2awAdlq3yFnv2FoMkuYjPaqhHMS+a3ONx
'' SIG '' PdcAfmJH0c6IybgY+g5yjcGjPa8CQGr/aZuW4hCoELQ3
'' SIG '' UAjWwz0wggYHMIID76ADAgECAgphFmg0AAAAAAAcMA0G
'' SIG '' CSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNj
'' SIG '' b20xGTAXBgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTAr
'' SIG '' BgNVBAMTJE1pY3Jvc29mdCBSb290IENlcnRpZmljYXRl
'' SIG '' IEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0
'' SIG '' MDMxMzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
'' SIG '' EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
'' SIG '' HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
'' SIG '' BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCC
'' SIG '' ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJ+h
'' SIG '' bLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn0Uyt
'' SIG '' dDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4E
'' SIG '' mPCJzB/LMySHnfL0Zxws/HvniB3q506jocEjU8qN+kXP
'' SIG '' CdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4nrIZPVVIM
'' SIG '' 5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0
'' SIG '' RZCfSABKR2YRJylmqJfk0waBSqL5hKcRRxQJgp+E7VV4
'' SIG '' /gGaHVAIhQAQMEbtt94jRrvELVSfrx54QTF3zJvfO4OT
'' SIG '' oWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAasw
'' SIG '' ggGnMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0
'' SIG '' +NlSRnAK7UD7dvuzK7DDNbMPMAsGA1UdDwQEAwIBhjAQ
'' SIG '' BgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQO
'' SIG '' rIJgQFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmS
'' SIG '' JomT8ixkARkWA2NvbTEZMBcGCgmSJomT8ixkARkWCW1p
'' SIG '' Y3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
'' SIG '' Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxz
'' SIG '' WPQHEy5lMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9j
'' SIG '' cmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
'' SIG '' L21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcB
'' SIG '' AQRIMEYwRAYIKwYBBQUHMAKGOGh0dHA6Ly93d3cubWlj
'' SIG '' cm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9zb2Z0Um9v
'' SIG '' dENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0G
'' SIG '' CSqGSIb3DQEBBQUAA4ICAQAQl4rDXANENt3ptK132855
'' SIG '' UU0BsS50cVttDBOrzr57j7gu1BKijG1iuFcCy04gE1CZ
'' SIG '' 3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji
'' SIG '' 8FMV3U+rkuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZ
'' SIG '' Lg33B+JwvBhOnY5rCnKVuKE5nGctxVEO6mJcPxaYiyA/
'' SIG '' 4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tO
'' SIG '' i3/FNSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLa
'' SIG '' FJj1PLlmWLMtL+f5hYbMUVbonXCUbKw5TNT2eb+qGHpi
'' SIG '' Ke+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
'' SIG '' NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCe
'' SIG '' FTBm6EISXhrIniIh0EPpK+m79EjMLNTYMoBMJipIJF9a
'' SIG '' 6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2JoXZh
'' SIG '' tG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0t
'' SIG '' r1mPuOQh5bWwymO0eFQF1EEuUKyUsKV4q7OglnUa2ZKH
'' SIG '' E3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng9wFlb4kL
'' SIG '' fchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj
'' SIG '' /TGCBJAwggSMAgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMw
'' SIG '' EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
'' SIG '' b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
'' SIG '' b24xIzAhBgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25p
'' SIG '' bmcgUENBAhMzAAAAiFkOPFEf4mpnAAEAAACIMAkGBSsO
'' SIG '' AwIaBQCggbIwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
'' SIG '' AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUw
'' SIG '' IwYJKoZIhvcNAQkEMRYEFOxDpiQnKF4XkSz5mIIvtZWI
'' SIG '' b+eDMFIGCisGAQQBgjcCAQwxRDBCoCSAIgBNAEQAVAAg
'' SIG '' AFUARABJAHYAMwAgAFQAbwBvAGwAawBpAHShGoAYaHR0
'' SIG '' cDovL3d3dy5taWNyb3NvZnQuY29tMA0GCSqGSIb3DQEB
'' SIG '' AQUABIIBAAd0dGVcnpAEHN0oGcOgS6OrpUP3OP3X/4b1
'' SIG '' dQB8Q6XQX/Cvp8PmDWVExiMDeLhiXofz+irJVnRaQWbw
'' SIG '' TUJv7DJm1gSoT0c1SQjvFe1dMq+6AwR4hIxKotjKbMqi
'' SIG '' 5MjAlN5tJnQsj4y5YNzkYT7wvoDy7ER3K5MsEcLSlN6r
'' SIG '' Z1mN64gceL4zLTXfKuhLE3wddSY+h8p0BijYIDlIWCSq
'' SIG '' DOQEWvgW14UGNDPKMCfS+YAVMVruxVIsxlM7yoj1qk+O
'' SIG '' 2+VfgH2SvKmUFunR6ywjtxsd9TVzuVsbcSm/ZSYQeBS4
'' SIG '' v99usw1hfrUfHO7/6PECt8fzghxaYMGSrYPhzirA71ah
'' SIG '' ggIfMIICGwYJKoZIhvcNAQkGMYICDDCCAggCAQEwgYUw
'' SIG '' dzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
'' SIG '' b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
'' SIG '' Y3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWlj
'' SIG '' cm9zb2Z0IFRpbWUtU3RhbXAgUENBAgphApJKAAAAAAAg
'' SIG '' MAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZI
'' SIG '' hvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xMjA4MzAxOTU3
'' SIG '' MDJaMCMGCSqGSIb3DQEJBDEWBBR/PonyDjp2M5dPfJDW
'' SIG '' 4Y0tb+qwVTANBgkqhkiG9w0BAQUFAASCAQAm86jkeooH
'' SIG '' iszpf++TQlXIqMZ9p4hLf+Z1LwRnv3Lh+8nINtn141X0
'' SIG '' Ywu5G1GZAQEEWnpSX5Oo6K+0dskmCdT8xS+OFI9GUXij
'' SIG '' 5+pcHSLem04TfzPkVld+CQtLjz2U1sU3uxR1kdTMPMx9
'' SIG '' mJ7pXBHJk/PaPlsRajB1lbmpnbhUfc7BHhulouugudN0
'' SIG '' iV0g8+CT56mkpFXqOltebGaXNro4RxHN8w/j+lQzod+6
'' SIG '' ErqPdG8r2D5w27vAAXAX6IkFNUB68Efv4K0ng+Whw/xL
'' SIG '' y/XW8hG2H2LmV2Tsoy7bCqj81iMaku/HO3xYC3cCJj6P
'' SIG '' OiJodw5HUGG42LYOgpvhM3Dz
'' SIG '' End signature block
