# jverein-helpers

Helper scripts for JVerein.

## Start-JVerein.ps1

The script enables you to run JVerein from a cloud drive like Nextcloud
and ensures the integrity of the program data.

### Installation

- Create a ZIP file `yourverein-JVerein-2022-12-21-18-37-18.zip` with the following contents:

```txt
JVerein
|- data
|  | # the data directory
|  |- jameica-backup-xxx.zip
|  |- jverein/
|   '- ....
'- jameica-2.10.2
   '- jameica
      | # the program directory
      '- jameica-win64.exe
```

The JVerein folder should be included in the ZIP file.

- Generate the hash of the ZIP in PowerShell:  
  `get-filehash .\yourverein-JVerein-2022-12-21-18-37-18.zip -Algorithm SHA256`
- Adjust the configuration like the `$workdir`
- Adjust the path in the `Start-Process` line to your jameica version (will be automated in the furure)
- Create a `manifest.json` like follows:

```json
{
    "hash": "DDB3AABFA85D17ADC536058B46219FF0F6420328650F18B30D15745083EE8D44",
    "filename": "yourverein-JVerein-2022-12-21-18-37-18.zip"
}
```

Use the hash from the step above.

- Put zip, `manifest.json` and the PowerShell script into the same folder
- Sync the folder with the sync client of your cloud to your PC

### Use the script

- Open PowerShell
- `cd \Path\to\JVerein\`
- `.\Start-JVerein.ps1`

### Workflow

The script will do the following:

- Create `%APPDATA%\YouVerein`
- Check manifest.json
- Check existence and hash of zip file
- Unzip the latest archive to `%APPDATA%\YouVerein\JVerein`
- Start JVerein
- Wait until JVerein is finished
- ZIP JVerein again
- Copy the new ZIP to the cloud drive
- Create a new manifest.json
- Exit

The whole script is quite beta, so please use it carefully and provide us feedback. Thank you! 🚀❤
