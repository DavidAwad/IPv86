# IPv86

## WARNING. This is volatile assembly code and will suck to use. 
### Also May only work on windows... 

Other additions:
Makes sure that it is the GET command
Can resume download (tested with Go!Zilla)
If directory, will redirect to include /
Recognizes %HH as hexadecimal
Tells you your IP address and name

How to use:

Set up a directory for use by the server (for example: C:\WebPage)
Run the program and click on "Pick Dir" and select your directory.
Check the "Dir enabled" box if you want to allow directory viewing
by clients, otherwise "dir/index.htm" will be used instead.

If it is sending the file as the wrong type, use regedit and
set/create a key in HKEY_CLASSES_ROOT of ".ext" (where ext is the
file extension) to "Content Type" with the type (such as
"application/x-zip-compressed")

To access from another computer, type in your IP address or,
over a LAN, the computer name.

(source site: http://lingcog.iit.edu/~scubed/projects.xml )


Read more: http://www.intel-assembler.it/portale/5/cinchy-x86-web-server/a-basic-asm-web-server.asp#ixzz3X20H53Hb
