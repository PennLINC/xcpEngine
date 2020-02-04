
Human Connectome Project Workbench Software

Do not add to, or alter, directories and files in the Workbench Software Distribution.  

The Workbench Software contains four programs.  wb_view is a graphical user-interface for visualization of neuroimaging data files.  wb_command is a command-line program that performs operations on neuroimaging data files.  wb_shortcuts is a bash script which simplifies specific tasks, generally by calling several wb_command operations in sequence.  wb_import is a utility based on caret5 code, which helps in converting various file formats into the ones used by workbench.

Each software distribution, regardless of operating system, contains a subdirectory name beginning with “bin_” and followed by an abbreviation of the operating system name.  This “bin” directory contains the programs wb_view, wb_command, and wb_shortcuts.



MAC OS X

Assuming Workbench has been installed in /Applications/workbench

To run wb_view and wb_command from a terminal window, your PATH environment variable must be updated.  Open a new terminal window and change into your home directory.  If you do not know which “shell” you are running, it may be (not always) found by running the command 'printenv SHELL'.

To set the PATH in Bash shell, enter this command in a terminal window:
 echo 'export PATH=$PATH:/Applications/workbench/bin_macosx64' >> ~/.bashrc

To set the PATH in tcsh/csh shell, enter this command in a terminal window:
 echo 'set PATH = ($PATH   /Applications/workbench/bin_macosx64)' >> ~/.cshrc
 
Alternatively, users may also edit their .bashrc or .cshrc file in a text editor to update the PATH.

Changing the PATH will only be effective in a newly created terminal window.  Users familiar with the “source” command may use it to update PATH in the open terminal window.

Mac  users may also run wb_view using the Finder Window.  Double click the file wb_view in the directory /Applications/workbench.  Mac Users may also drag the wb_view icon to the Dock.

If you are running a newer version of bash than OS X ships with, see "BASH COMPLETIONS" below for an OPTIONAL step that makes it more convenient to use wb_command in bash.

LINUX

Assuming Workbench has been installed in /opt/workbench

To run wb_view and wb_command from a terminal window, your PATH environment variable must be updated.  Open a new terminal window and change into your home directory.  If you do not know which “shell” you are running, it may be (not always) found by running the command 'printenv SHELL'.

To set the PATH in Bash shell, enter this command in a terminal window:
 echo 'export PATH=$PATH:/Applications/workbench/bin_linux64' >> ~/.bashrc

To set the PATH in tcsh/csh shell, enter this command in a terminal window:
 echo 'set PATH = ($PATH   /Applications/workbench/bin_linux64)' >> ~/.cshrc
 
Alternatively, users may also edit their .bashrc or .cshrc file in a text editor to update the PATH.

Changing the PATH will only be effective in a newly created terminal window.  Users familiar with the “source” command may use it to update PATH in the open terminal window.

See "BASH COMPLETIONS" below for an OPTIONAL step that that makes it more convenient to use wb_command in bash.

WINDOWS

Assuming Workbench has been installed in c:/workbench

Windows users may also run wb_view (and wb_command) from the command line by adding the installation’s “c:/workbench/bin_windows64” path to PATH environment variable.  This is usually found under Windows Menu —> Control Panel —> Advanced System Settings —> Environment Variables.  Separate multiple paths with semicolons (;). 

While wb_view may be run from a terminal window, it may also be run from Windows Explorer.    Windows users will need to run the “wb_view.exe” file located in the distributions’s “bin_windows64” directory.  One may also create a Shortcut on the Desktop by right-clicking the mouse in the Desktop and selecting the New —> Shortcut menu item.  Browse to the c:/workbench/bin_windows64, choose wb_view.exe, and complete creation of the shortcut.

If you are running Cygwin bash or something similar, see "BASH COMPLETIONS" below for an OPTIONAL step that that makes it more convenient to use wb_command in bash.

BASH COMPLETIONS

For non-ancient versions of the "bash" shell (the default OS X bash is too old, you would need to install a newer version, and the "bash-completion" package through homebrew, macports, or similar), workbench now provides tab completions.

The easiest way to install them is to copy the file "bashcomplete_wb_command" from the workbench folder into /etc/bash_completion.d/, if you have admin rights.  If you do not have admin rights, make a copy of "bashcomplete_wb_command" in your home directory, renamed to ".bash_completion".  You can ignore the "bashcomplete_wb_shortcuts" file, the wb_command one also defines completions for wb_shortcuts (the other file exists for installing the completions in a different way).  The files are located here, depending on OS:

Ubuntu/Debian Linux: workbench/exe_linux64/bashcomplete_wb_command
Centos/RedHat Linux: workbench/exe_rh_linux64/bashcomplete_wb_command
Windows: workbench/bin_windows64/bashcomplete_wb_command
OS X: workbench/macosx64_apps/bashcomplete_wb_command

Once this is done, OPEN A NEW terminal window, type "wb_command -file-info", press tab, and the line should change to "wb_command -file-information".  If it does not, then it is likely that the OS's "bash-completion" package is not installed.


