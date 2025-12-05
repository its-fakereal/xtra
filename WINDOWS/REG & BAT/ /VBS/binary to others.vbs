Option Explicit

' Function to convert binary string to text
Function BinaryToText(binaryStr)
    Dim result, i, charCode

    result = ""
    For i = 1 To Len(binaryStr) Step 8
        ' Get each 8-bit segment
        Dim segment
        segment = Mid(binaryStr, i, 8)

        ' Convert the 8-bit binary segment to decimal
        charCode = 0
        Dim j
        For j = 1 To 8
            If Mid(segment, j, 1) = "1" Then
                charCode = charCode + 2 ^ (8 - j)
            End If
        Next

        result = result & Chr(charCode)
    Next

    BinaryToText = result
End Function

' Main
Dim binaryInput, outputText

' Input binary string
binaryInput = InputBox("Enter a binary number :", "Binary to Text Converter")

' Remove spaces from input
binaryInput = Replace(binaryInput, " ", "")

' Validate input
If Len(binaryInput) Mod 8 <> 0 Then
    MsgBox "Please enter a valid binary number with 8-bit segments."
Else
    outputText = BinaryToText(binaryInput)
    MsgBox "The converted text is: " & outputText
End If
