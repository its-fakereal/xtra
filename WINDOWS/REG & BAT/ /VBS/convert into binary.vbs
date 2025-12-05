' Binary Converter.vbs

' Function to convert a string to binary
Function StringToBinary(str)
    Dim binary, i
    binary = ""
    For i = 1 To Len(str)
        binary = binary & DecToBin(Asc(Mid(str, i, 1))) & " "
    Next
    StringToBinary = Trim(binary)
End Function

' Function to convert a decimal number to 8-bit binary
Function DecToBin(n)
    DecToBin = ""
    Do While n > 0
        DecToBin = CStr(n Mod 2) & DecToBin
        n = n \ 2
    Loop
    ' Pad with zeros to make it 8 bits
    While Len(DecToBin) < 8
        DecToBin = "0" & DecToBin
    Wend
End Function

' Get user input
Dim input, binary
input = InputBox("Enter a string, number, or special character to convert to binary:")

If input = "" Then
    MsgBox "No input provided. Exiting."
    WScript.Quit
End If

' Convert input to binary
binary = StringToBinary(input)

' Copy binary to clipboard using htmlfile object
Dim objHTML
Set objHTML = CreateObject("htmlfile")
objHTML.ParentWindow.ClipboardData.SetData "Text", binary

' Notify user
MsgBox "The binary output has been copied to the clipboard:" & vbCrLf & vbCrLf & binary
