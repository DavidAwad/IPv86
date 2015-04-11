.386
.model flat,stdcall
option casemap:none

WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD   ;Create dialog and handle msg
WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD   ;Main window function
Cut PROTO :DWORD,:DWORD,:DWORD,:BYTE        ;Cut off end of string
StrLen PROTO :DWORD                         ;Find length of string
StrCmp PROTO :DWORD,:DWORD                  ;Compare two strings
StrCpy PROTO :DWORD,:DWORD                  ;Copy a string
StrCat PROTO :DWORD,:DWORD                  ;String1+=String2
Ext PROTO                                   ;Find MIME type for extension
Resuming PROTO                              ;Look for resume data
FillList PROTO :DWORD,:DWORD                ;DIR into Listbox and send
RemoveHex PROTO :DWORD,:DWORD               ;Converts %HH to characters
InsertHex PROTO :DWORD,:DWORD               ;Converts characters to %HH
FromHex PROTO :BYTE                         ;Converts hex digit to byte

include \masm32\include\windows.inc
include \masm32\include\user32.inc
includelib \masm32\lib\user32.lib
include \masm32\include\kernel32.inc
includelib \masm32\lib\kernel32.lib
include \masm32\include\shell32.inc
includelib \masm32\lib\shell32.lib
include \masm32\include\wsock32.inc
includelib \masm32\lib\wsock32.lib
include \masm32\include\advapi32.inc
includelib \masm32\lib\advapi32.lib

.data
ClassName db "DLGCLASS",0
DlgName   db "Form1",0
IcoName   db "i",0
DefPath   db "C:",0
DefName   db "index.htm",0
Star      db "*.*",0
DTitle    db "Select base webpage directory:",0
Get       db "GET",0
Content   db "Content Type",0
Msg200    db "HTTP/1.1 200 OK",13,10
          db "Expires: 0",13,10
          db "Last-Modified: 0",13,10
          db "Accept-Range: bytes",13,10
          db "Content-Type: %s",13,10
          db "Content-Length: %lu",13,10,13,10,0
Msg206    db "HTTP/1.1 206 Partial Content",13,10
          db "Expires: 0",13,10
          db "Last-Modified: 0",13,10
          db "Accept-Range: bytes",13,10
          db "Content-Type: %s",13,10
          db "Content-Range: bytes=%lu-%lu/%lu",13,10
          db "Content-Length: %lu",13,10,13,10,0
Msg404    db "HTTP/1.1 404 Not Found",13,10
          db "Expires: 0",13,10
          db "Last-Modified: 0",13,10
          db "Accept-Range: bytes",13,10
          db "Content-Type: text/html",13,10
          db "Content-Length: 124",13,10,13,10
          db "<TITLE>404 error</TITLE><B>Error 404: Page not
found</B>",13,10
          db "The URL does not exist.  Check the link and your spelling.",0
Redir     db "HTTP/1.1 301 Moved Permanently",13,10
          db "Location: %s",13,10,0
Range     db "range: bytes",0
Str0      db "<TITLE>Directory of ",0
Str1      db "</TITLE>",13,10,0
Str2      db "File:<BR><BR>",13,10,13,10,0
Str3      db 13,10,"<BR>Directory:<BR><BR>",13,10,13,10,0
Str4      db "<A HREF=",34,0
Str5      db 34,62,0
Str6      db "</A><BR>",13,10,0
HTML      db "text/html",0
Type0     db "text/plain",0
hFile     dd 0
hSock1    dd 0
hReg      dd 0
pType     dd 0
bi BROWSEINFO <0,0,0,offset DTitle,BIF_RETURNONLYFSDIRS,0,0,0>

.data?
hInstance HINSTANCE ?
CommandLine LPSTR ?
Count dd ?
Exist dd ?
FSize dd ?
FOffset dd ?
RFlag dd ?
hDlg dd ?               ;Handles
hFind dd ?
hMem dd ?
pMem dd ?
BufSize dd ?
NotUsed dd ?
RSBuf db 1024 dup(?)     ;String buffers
Buf1 db 1024 dup(?)
Buf2 db 1024 dup(?)
Buf3 db 1024 dup(?)
Buf4 db 1024 dup(?)
Path db 512 dup(?)
wsadata WSADATA <>      ;WinSock
SA sockaddr_in <>
fd WIN32_FIND_DATA <>

.const
WM_SOCKET equ WM_USER+256

.code
program:
INVOKE GetModuleHandle,0
mov hInstance,eax
INVOKE GetCommandLine
mov CommandLine,eax
INVOKE WinMain,hInstance,0,CommandLine,SW_SHOWDEFAULT
INVOKE ExitProcess,eax
WinMain proc hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
LOCAL wc:WNDCLASSEX
LOCAL msg:MSG
mov wc.cbSize,SIZEOF WNDCLASSEX
mov wc.style,CS_HREDRAW or CS_VREDRAW
mov wc.lpfnWndProc,OFFSET WndProc
mov wc.cbClsExtra,0
mov wc.cbWndExtra,DLGWINDOWEXTRA
push hInst
pop wc.hInstance
mov wc.hbrBackground,COLOR_BTNFACE+1
mov wc.lpszClassName,OFFSET ClassName
mov wc.lpszMenuName,0
INVOKE LoadIcon,hInstance,offset IcoName
mov wc.hIcon,eax
mov wc.hIconSm,eax
INVOKE LoadCursor,0,IDC_ARROW
mov wc.hCursor,eax
INVOKE WSAStartup,101h,offset wsadata     ;Use WinSock v1.1
INVOKE RegisterClassEx,addr wc            ;Make Dialog box.
INVOKE CreateDialogParam,hInstance,offset DlgName,0,0,0
mov hDlg,eax
INVOKE ShowWindow,hDlg,SW_SHOWNORMAL
INVOKE UpdateWindow,hDlg
.WHILE TRUE                             ;Main window loop
    INVOKE GetMessage,addr msg,0,0,0
    .BREAK .IF (!eax)
    INVOKE TranslateMessage,addr msg
    INVOKE DispatchMessage,addr msg
.ENDW
INVOKE WSACleanup                       ;Done with WinSock
mov eax,msg.wParam
ret
WinMain endp
WndProc proc hWnd:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
.IF uMsg==WM_DESTROY
    INVOKE closesocket,hSock1
    INVOKE PostQuitMessage,0
.ELSEIF uMsg==WM_SHOWWINDOW
    INVOKE SendDlgItemMessage,hWnd,1000,WM_SETTEXT,0,offset DefPath
    INVOKE gethostname,offset Buf1,1024     ;Get name
    INVOKE SendDlgItemMessage,hWnd,1004,WM_SETTEXT,0,offset Buf1
    INVOKE gethostbyname,addr Buf1
    mov eax,[eax+12]
    mov eax,[eax]           ;Get IP address
    mov eax,[eax]
    INVOKE inet_ntoa,eax
    INVOKE SendDlgItemMessage,hWnd,1005,WM_SETTEXT,0,eax
    INVOKE socket,PF_INET,SOCK_STREAM,IPPROTO_TCP
    mov hSock1,eax              ;Configure listening socket
    mov SA.sin_family,AF_INET
    mov SA.sin_addr.S_un.S_addr,INADDR_ANY
    INVOKE htons,80
    mov SA.sin_port,ax
    INVOKE WSAAsyncSelect,hSock1,hWnd,WM_SOCKET,FD_ACCEPT
    INVOKE bind,hSock1,offset SA,sizeof SA
    INVOKE listen,hSock1,5      ;Listen for connections
.ELSEIF uMsg==WM_COMMAND
        mov eax,wParam
        .IF ax==1003
            mov Buf4,0      ;Prompt for directory
            INVOKE SHBrowseForFolder,addr bi
            .IF eax==0
                xor eax,eax
                ret
            .ENDIF      ;Turn return value into pathname
            INVOKE SHGetPathFromIDList,eax,offset Buf4
            .IF Buf4==0
                xor eax,eax
                ret
            .ENDIF
            .IF Buf4[3]==0      ;If C:\ change to C:
                mov Buf4[2],0
            .ENDIF
            INVOKE StrLen,offset Buf4
            mov ecx,eax
            mov al,"\"
            mov edi,offset Buf4
@@@5:       repnz scasb
            jnz @@@6
            mov BYTE PTR[edi-1],"/"
            jmp @@@5
@@@6:       INVOKE SendDlgItemMessage,hWnd,1000,WM_SETTEXT,0,offset Buf4
        .ENDIF
.ELSEIF uMsg==WM_SOCKET
    mov eax,lParam
    and eax,0FFFFh
    .IF ax==FD_ACCEPT
        INVOKE accept,hSock1,0,0
        INVOKE WSAAsyncSelect,eax,hWnd,WM_SOCKET,FD_READ or FD_CLOSE
    .ELSEIF ax==FD_READ
        INVOKE recv,wParam,offset RSBuf,1024,0
        mov al,32
        mov ecx,10
        lea edi,RSBuf
        repnz scasb
        dec edi
        push edi
        mov BYTE PTR[edi],0
        INVOKE StrCmp,offset RSBuf,offset Get
        .IF eax==1          ;If command other than GET, ignore.
            INVOKE closesocket,wParam
            xor eax,eax
            ret
        .ENDIF
        pop edi
        mov BYTE PTR[edi],32
        INVOKE Cut,offset RSBuf,offset Buf2,4,32
        INVOKE RemoveHex,offset Buf2,offset Buf1
        INVOKE StrLen,offset Buf1
        mov ecx,eax
        mov edi,offset Buf1     ;Make sure there is no ../
        mov al,"."
@@@7:   repnz scasb
        jnz @@@8
        cmp BYTE PTR[edi],"."
        jnz @@@7
        cmp BYTE PTR[edi+1],"/"
        jnz @@@7
        jmp Bad
@@@8:   mov Exist,0             ;Must determine request type
        dec edi
        .IF BYTE PTR[edi]=="/"  ;Therefore, directory
            INVOKE StrCpy,offset Buf1,offset Buf3
            INVOKE SendDlgItemMessage,hWnd,1000,WM_GETTEXT,512,offset Path
            INVOKE StrCpy,offset Path,offset Buf2
            INVOKE StrCat,offset Buf2,offset Buf1
            INVOKE SendDlgItemMessage,hDlg,1002,BM_GETCHECK,0,0
            .IF eax==0
                INVOKE StrCat,offset Buf2,offset DefName
                jmp Index
            .ENDIF
            INVOKE wsprintfA,offset Buf1,offset Msg200,offset HTML,30000
            INVOKE StrLen,offset Buf1
            INVOKE send,wParam,offset Buf1,eax,0  ;Send header
            INVOKE StrLen,offset Str0
            INVOKE send,wParam,offset Str0,eax,0
            INVOKE StrLen,offset Buf2
            INVOKE send,wParam,offset Buf2,eax,0
            INVOKE StrLen,offset Str1
            INVOKE send,wParam,offset Str1,eax,0
            INVOKE StrCat,offset Buf2,offset Star   ;Get files
            INVOKE FillList,0,wParam
            INVOKE FillList,16,wParam
            INVOKE closesocket,wParam   ;Done sending listing
            inc Exist
        .ELSE                   ;File
            INVOKE SendDlgItemMessage,hWnd,1000,WM_GETTEXT,512,offset Path
            INVOKE StrCpy,offset Path,offset Buf2
            INVOKE StrCat,offset Buf2,offset Buf1
Index:      INVOKE GetFileAttributes,offset Buf2
            cmp eax,-1
            jz Bad      ;File doesn't exist
            and eax,16
            .IF eax!=0  ;File was actually a directory, without a /.
                INVOKE InsertHex,offset Buf1,offset Buf2
                INVOKE StrLen,offset Buf2
                lea ebx,Buf2 ;So, redirect
                add eax,ebx
                mov BYTE PTR[eax],"/"
                mov BYTE PTR[eax+1],0
                INVOKE wsprintf,offset Buf1,offset Redir,offset Buf2
                INVOKE StrLen,offset Buf1
                INVOKE send,wParam,offset Buf1,eax,0
                INVOKE closesocket,wParam
                xor eax,eax
                ret
            .ENDIF
            INVOKE CreateFile,offset Buf2,GENERIC_READ,0,0,OPEN_EXISTING,0,0
            mov hFile,eax
            INVOKE GetFileSize,hFile,0
            mov FSize,eax
            INVOKE Ext
            INVOKE Resuming   ;Check for range and if resume sending
            mov eax,FOffset
            .IF RFlag==0
                INVOKE wsprintfA,offset Buf1,offset Msg200,pType,FSize
            .ELSE
                mov ebx,FSize
                sub FSize,eax
                mov ecx,ebx
                dec ecx
                INVOKE wsprintfA,offset Buf1,offset Msg206,pType,FOffset,ecx,
                        ebx,FSize
            .ENDIF
            INVOKE StrLen,offset Buf1
            INVOKE send,wParam,offset Buf1,eax,0
            INVOKE GlobalAlloc,0,FSize  ;Get memory to store file
            mov hMem,eax                ;for sending.
            INVOKE GlobalLock,hMem
            mov pMem,eax
            INVOKE SetFilePointer,hFile,FOffset,0,FILE_BEGIN
            INVOKE ReadFile,hFile,pMem,FSize,offset NotUsed,0
            INVOKE send,wParam,pMem,FSize,0
            INVOKE GlobalUnlock,hMem
            INVOKE GlobalFree,hMem
            INVOKE closesocket,wParam
            INVOKE CloseHandle,hFile    ;Done with file and socket too.
            inc Exist
        .ENDIF
        .IF Exist==0
Bad:        INVOKE StrLen,offset Msg404 ;Bad request.  Send 404 error.
            INVOKE send,wParam,offset Msg404,eax,0
            INVOKE closesocket,wParam
        .ENDIF
    .ELSEIF ax==FD_CLOSE
        INVOKE closesocket,wParam
    .ENDIF
.ELSE
    INVOKE DefWindowProc,hWnd,uMsg,wParam,lParam
    ret
.ENDIF
xor eax,eax
ret
WndProc endp
Cut PROC SRC:DWORD,DST:DWORD,OS:DWORD,EC:BYTE
mov eax,OS
add SRC,eax
mov al,EC
mov ecx,-1
mov edi,SRC
repnz scasb
not ecx
dec ecx
.IF ecx>1010     ;Buffer overflow: Truncate (414)
    mov ecx,1020
.ENDIF
mov esi,SRC
mov edi,DST
rep movsb
mov BYTE PTR[edi],0
ret
Cut ENDP
StrLen PROC SRC:DWORD
mov ecx,-1
mov edi,SRC
mov al,0
repnz scasb
mov eax,ecx
not eax
dec eax
ret
StrLen ENDP
StrCpy proc SRC:LPSTR,DST:LPSTR
INVOKE StrLen,SRC
add eax,2
mov ecx,eax
mov esi,SRC
mov edi,DST
rep movsb
ret
StrCpy endp
StrCat proc S1:DWORD,S2:DWORD
INVOKE StrLen,S2
add eax,2
push eax
INVOKE StrLen,S1
mov edi,S1
add edi,eax
mov esi,S2
pop ecx
rep movsb
ret
StrCat endp
StrCmp PROC SRC:DWORD,DST:DWORD
INVOKE StrLen,SRC
inc eax
mov ecx,eax
mov esi,SRC
mov edi,DST
repz cmpsb
mov eax,1
jnz Next    ;zf set or not from repz
dec eax
Next:
ret
StrCmp endp
Ext PROC
lea esi,Buf2
mov ebx,esi
@0: lodsb       ;Search string for '.', ending at 0.
    .IF al=="."
        mov ebx,esi
    .ENDIF
    cmp al,0
    jnz @0
dec ebx         ;Open Registry to look for MIME type for extension.
INVOKE RegOpenKeyEx,HKEY_CLASSES_ROOT,ebx,0,KEY_READ,offset hReg
cmp eax,0
jnz @1          ;Get MIME type
mov BufSize,1024
INVOKE RegQueryValueEx,hReg,offset Content,0,0,offset Buf4,offset BufSize
cmp eax,0
jnz @1          ;Done with Registry
INVOKE RegCloseKey,hReg
lea eax,Buf4
mov pType,eax
ret
@1:             ;If not found, return default.
INVOKE RegCloseKey,hReg
lea eax,Type0
mov pType,eax
ret
Ext ENDP
Resuming PROC   ;Set FOffset
mov FOffset,0
mov RFlag,0
lea esi,RSBuf
lea edi,Range
@2: mov ch,[esi]
    .IF ch<91 && ch>64 ;Lower case
        add ch,32
    .ENDIF
    .IF [edi]==ch    ;Look for substring
        inc edi
        cmp BYTE PTR[edi],0
        jz @3
    .ELSE
        lea edi,Range
    .ENDIF
    inc esi
    cmp BYTE PTR[esi],0
    jnz @2
    ret
@3: add esi,2  ;Turn string at [esi] into value in eax.
xor eax,eax    ;Only works for "Range: bytes=x-" format
xor ebx,ebx
mov ecx,10
mov RFlag,1
@4:
mov bl,[esi]
sub bl,48
inc esi
.IF bl<10
    mul ecx
    add eax,ebx
    jmp @4
.ENDIF
mov FOffset,eax
ret
Resuming ENDP
FillList PROC DirF:DWORD,hSck:DWORD
INVOKE SendDlgItemMessage,hDlg,1001,LB_RESETCONTENT,0,0
INVOKE FindFirstFile,offset Buf2,offset fd
.IF eax==-1
    ret
.ENDIF
mov hFind,eax
@@@1: mov eax,fd.dwFileAttributes
    and eax,16      ;Show directories if DirF
    .IF eax==DirF
        xor eax,eax
        .IF fd.cFileName=="."
            .IF fd.cFileName[1]==0 || (fd.cFileName[1]=="." &&
              fd.cFileName[2]==0)
                inc eax
            .ENDIF
        .ENDIF
        .IF eax==0
            INVOKE SendDlgItemMessage,hDlg,1001,LB_ADDSTRING,0,
                    offset fd.cFileName
        .ENDIF
    .ENDIF
    INVOKE FindNextFile,hFind,offset fd
    cmp eax,1
    jz @@@1
INVOKE FindClose,hFind
INVOKE SendDlgItemMessage,hDlg,1001,LB_GETCOUNT,0,0
.IF eax==0
    ret
.ENDIF
mov Count,eax
.IF DirF==16
    lea edx,Str3
.ELSE
    lea edx,Str2
.ENDIF
INVOKE StrLen,edx
INVOKE send,hSck,edx,eax,0
mov pType,0
@@@2:
INVOKE StrLen,offset Str4           ;Send hyperlink to file
INVOKE send,hSck,offset Str4,eax,0
INVOKE SendDlgItemMessage,hDlg,1001,LB_GETTEXT,pType,offset Buf1
.IF DirF==16                ;Add / to directories
    mov edx,offset Buf1
    INVOKE StrLen,edx
    add eax,edx
    mov BYTE PTR[eax],"/"
    inc eax
    mov BYTE PTR[eax],0
.ENDIF
INVOKE InsertHex,offset Buf1,offset Buf3
INVOKE StrLen,offset Buf3
INVOKE send,hSck,offset Buf3,eax,0
INVOKE StrLen,offset Str5
INVOKE send,hSck,offset Str5,eax,0
INVOKE StrLen,offset Buf1
INVOKE send,hSck,offset Buf1,eax,0
INVOKE StrLen,offset Str6
INVOKE send,hSck,offset Str6,eax,0
inc pType
mov eax,Count
cmp pType,eax
jnz @@@2
ret
FillList ENDP
RemoveHex PROC SRC:DWORD,DST:DWORD
mov esi,SRC
dec esi
mov edi,DST
xor eax,eax
@@@3: inc esi
    mov al,[esi]
    .IF al=="\"
        mov al,"/"
    .ENDIF
    .IF al==0
        stosb
        ret
    .ENDIF
    .IF al=="%"
        INVOKE FromHex,[esi+1]
        .IF al==-1
           mov al,"%"
           stosb
           jmp @@@3
        .ENDIF
        mov bl,al
        INVOKE FromHex,[esi+2]
        .IF al==-1
           mov al,"%"
           stosb
           jmp @@@3
        .ENDIF
        shl bl,4
        add al,bl
        add esi,2
    .ENDIF
    stosb
    jmp @@@3
RemoveHex ENDP
InsertHex PROC SRC:DWORD,DST:DWORD
mov esi,SRC
dec esi
mov edi,DST
xor eax,eax
@@@4: inc esi
    mov al,[esi]
    .IF al==0
        stosb
        ret
    .ENDIF
    .IF al<"(" || al>"~"
        mov dl,al
        mov al,"%"
        stosb
        mov al,dl
        shr al,4
        .IF al<10
            add al,48
        .ELSE
            add al,55
        .ENDIF
        stosb
        mov al,dl
        and al,15
        .IF al<10
            add al,48
        .ELSE
            add al,55
        .ENDIF
    .ENDIF
    stosb
    jmp @@@4
InsertHex ENDP
FromHex PROC Char:BYTE
mov al,Char
.IF al>="0" && al<="9"
    sub al,48
    ret
.ENDIF
.IF al>="a" && al<="f"
    sub al,87
    ret
.ENDIF
.IF al>="A" && al<="F"
    sub al,55
    ret
.ENDIF
mov al,-1
ret
FromHex ENDP
end program
