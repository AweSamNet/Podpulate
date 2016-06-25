# Podpulate

Podpulate is a barebones PowerShell module which facilitates building and updating podcast xml files through the use of FTP.  

## Quick Start
### Windows Users
1. On windows system, [download this library zip](https://github.com/AweSamNet/Podpulate/archive/master.zip) file
1. Extract contents to a directory
1. Right-click `Podpulate.bat` in the extracted directory, and click `Edit`
1. Modify the following fields with the proper information

    ``` 
    SET ftpUrl=""
    SET ftpUser=""
    SET ftpPassword=""
    SET startPath=""
    ```
1. Run `Podpulate.bat` and follow the instructions
1. **IMPORTANT:** Obviously the script can't tell how long your podcast is or the description, so be sure to edit the file with the proper changes before you upload it.
1. Upload to your server.  (I had originally thought to do this automatically, but then I thought users might be mad when it overwrites existing files :/ )

**Advanced users:** 

1. Follow step 1-2 above.
1. Skip steps 3-4 above.
1. In PowerShell run the following command 

    ```
    Podpulate.ps1' -ftpUrl "www.yoursite.com" -ftpUser "yourFtpUser" -ftpPassword "password" -startPath "path/from/root/to/podcasts"
    ```
1. Follow steps 5+ above

### Mac/Linux Users
1. Download and install [Pash](https://github.com/Pash-Project/Pash)
2. Follow instructions above for Windows advanced users.
